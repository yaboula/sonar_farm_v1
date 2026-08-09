-- Authoritative supplier, Treasury order and Warehouse service.

Supplies = Supplies or {}

local function cents(value) return math.floor((tonumber(value) or 0) * 100 + 0.5) end
local function dollars(value) return math.floor((tonumber(value) or 0) + 0.5) / 100 end
local function now() return Sonar.Time.Now() end
local function reject(reason, message) return { ok = false, reason = reason, message = message } end

local function decode(value)
    local ok, result = pcall(json.decode, value or '{}')
    return ok and type(result) == 'table' and result or {}
end

local function lineEffect(item)
    local effect = item.tool or item.consumable or {}
    if item.tool and effect.action == 'weed' then return ('Removes %d%% weeds · %d uses'):format(effect.weedRemoval, effect.uses) end
    if item.tool then return ('%d field uses'):format(effect.uses) end
    if effect.action == 'fertilize' then
        return ('+%d nutrients · %d%% retention for %dh'):format(effect.amount, effect.protectionStrength * 100, effect.protectionHours)
    end
    if effect.action == 'treat_pest' then
        return ('-%d pest pressure · %d%% suppression for %dh'):format(effect.reduction, effect.protectionStrength * 100, effect.protectionHours)
    end
    return item.description
end

function Supplies.IsEnabled()
    return Config.Features and Config.Features.Supplies == true
end

function Supplies.Restock()
    local timestamp = now()
    local rows = MySQL.query.await('SELECT * FROM sf_supplier_stock') or {}
    for _, row in ipairs(rows) do
        local elapsed = math.max(0, timestamp - (tonumber(row.last_restock_at) or timestamp))
        local interval = tonumber(row.restock_seconds) or 0
        local periods = interval > 0 and math.floor(elapsed / interval) or 0
        if periods > 0 then
            local quantity = math.min(tonumber(row.capacity) or 0,
                (tonumber(row.quantity) or 0) + periods * (tonumber(row.restock_amount) or 0))
            MySQL.update.await('UPDATE sf_supplier_stock SET quantity=?,last_restock_at=? WHERE item_id=?',
                { quantity, (tonumber(row.last_restock_at) or timestamp) + periods * interval, row.item_id })
        end
    end
end

local function monthlySpent(companyId)
    return tonumber(MySQL.scalar.await([[
        SELECT COALESCE(SUM(amount_cents),0) FROM sf_company_ledger
        WHERE company_id=? AND entry_type='purchase' AND direction='debit'
          AND created_at >= DATE_FORMAT(CURRENT_TIMESTAMP, '%Y-%m-01')]], { companyId })) or 0
end

local function loadLines(draftId)
    return MySQL.query.await('SELECT item_id,quantity,unit_price_cents FROM sf_supply_draft_lines WHERE draft_id=? ORDER BY item_id', { draftId }) or {}
end

local function stockMap(alreadyLocked)
    if alreadyLocked then Supplies.Restock()
    else Lock.With('supplier-order', function() Supplies.Restock() end) end
    local result = {}
    for _, row in ipairs(MySQL.query.await('SELECT item_id,quantity,capacity,restock_amount,restock_seconds,last_restock_at FROM sf_supplier_stock') or {}) do
        result[row.item_id] = row
    end
    return result
end

function Supplies.ReconcileOutbox(source, member)
    if not member then return end
    local rows = MySQL.query.await([[SELECT * FROM sf_supply_outbox WHERE company_id=? AND identifier=?
        AND status IN ('pending','prepared','inventory_done') ORDER BY created_at LIMIT 20]],
        { member.company_id, member.identifier }) or {}
    for _, row in ipairs(rows) do
        Lock.With('outbox:' .. row.id, function()
            local payload = decode(row.payload)
            if not payload.identifier or payload.identifier ~= member.identifier then return end
            if row.kind == 'withdraw' then
                local held = Bridge.Inventory.GetItemCount(source, payload.itemId, { issueId = payload.issueId })
                local expected = tonumber(payload.quantity) or 1
                local missing = math.max(0, expected - held)
                if missing > 0 then
                    if not Bridge.Inventory.CanCarry(source, payload.itemId, missing) then return end
                    if not Bridge.Inventory.AddItem(source, payload.itemId, missing, payload.metadata) then
                        MySQL.update.await("UPDATE sf_supply_outbox SET attempts=attempts+1,last_error='retry_add_failed' WHERE id=?", { row.id })
                        return
                    end
                end
                MySQL.transaction.await({
                    { query = "UPDATE sf_material_issues SET status='issued' WHERE id=? AND status='pending'", values = { payload.issueId } },
                    { query = "UPDATE sf_warehouse_tool_units SET status='issued' WHERE id=? AND status='reserved'", values = { payload.warehouseUnitId or '' } },
                    { query = "UPDATE sf_supply_outbox SET status='completed',attempts=attempts+1,last_error=NULL WHERE id=?", values = { row.id } },
                })
            elseif row.kind == 'usage' then
                local usageAcquired = Lock.With('member-custody:' .. member.identifier, function()
                    local activeStatus = MySQL.scalar.await('SELECT status FROM sf_supply_outbox WHERE id=? LIMIT 1', { row.id })
                    if activeStatus ~= 'prepared' and activeStatus ~= 'inventory_done' then return end
                    if activeStatus == 'prepared' then
                        local recoveryAge = now() - (tonumber(payload.preparedAt) or 0)
                        if payload.preparedAt and recoveryAge < (Config.Supplies.UsageRecoveryGraceSeconds or 2) then return end
                        local slots = Bridge.Inventory.GetSlotsWithItem(source, payload.itemId, { issueId = payload.issueId }, false)
                        local held, currentDurability = 0, nil
                        for _, slot in pairs(slots or {}) do
                            held = held + (tonumber(slot.count) or 1)
                            local durability = slot.metadata and tonumber(slot.metadata.durability)
                            if durability and (not currentDurability or durability < currentDurability) then
                                currentDurability = durability
                            end
                        end
                        local beforeHeld = tonumber(payload.beforeIssueCount) or tonumber(payload.beforeCount) or 1
                        local inventoryChanged
                        if tonumber(payload.consumed) == 1 or payload.broken == true then
                            inventoryChanged = held < beforeHeld
                        else
                            inventoryChanged = held > 0 and currentDurability ~= nil
                                and currentDurability < (tonumber(payload.beforeDurability) or 100) - 0.0001
                        end
                        if not inventoryChanged then
                            MySQL.update.await([[UPDATE sf_supply_outbox SET status='failed',attempts=attempts+1,
                                last_error='usage_not_applied' WHERE id=? AND status='prepared']], { row.id })
                            return
                        end
                        MySQL.update.await([[UPDATE sf_supply_outbox SET status='inventory_done',attempts=attempts+1,
                            last_error=NULL WHERE id=? AND status='prepared']], { row.id })
                    end
                    if not Company.FinalizeItemUse(payload, row.id) then
                        MySQL.update.await("UPDATE sf_supply_outbox SET attempts=attempts+1,last_error='usage_finalize_failed' WHERE id=?", { row.id })
                    end
                end)
                if not usageAcquired then return end
            elseif row.kind == 'return' then
                local issue = MySQL.single.await('SELECT status FROM sf_material_issues WHERE id=? AND company_id=?',
                    { payload.issueId, member.company_id })
                if not issue or issue.status ~= 'issued' then
                    MySQL.update.await("UPDATE sf_supply_outbox SET status='failed',attempts=attempts+1,last_error='issue_not_returnable' WHERE id=?", { row.id })
                    return
                end
                if row.status == 'prepared' then
                    local slots = Bridge.Inventory.GetSlotsWithItem(source, payload.itemId, { issueId = payload.issueId }, false)
                    local slot
                    for _, candidate in pairs(slots or {}) do slot = slot or candidate end
                    if slot and not Bridge.Inventory.RemoveFromSlot(source, payload.itemId, 1, slot.slot, slot.metadata) then return end
                    MySQL.update.await("UPDATE sf_supply_outbox SET status='inventory_done',attempts=attempts+1 WHERE id=? AND status='prepared'", { row.id })
                end
                local queries = {}
                if payload.warehouseUnitId then
                    queries[#queries + 1] = { query = [[UPDATE sf_warehouse_tool_units
                        SET status='available',durability=?,issue_id=NULL WHERE id=? AND issue_id=?]],
                        values = { payload.durability or 0, payload.warehouseUnitId, payload.issueId } }
                else
                    queries[#queries + 1] = { query = [[INSERT INTO sf_warehouse_lots (company_id,item_id,quantity) VALUES (?,?,1)
                        ON DUPLICATE KEY UPDATE quantity=quantity+1]], values = { member.company_id, payload.itemId } }
                end
                queries[#queries + 1] =
                    { query = [[UPDATE sf_material_issues SET returned_units=returned_units+1,durability=?,
                        status=IF(returned_units+consumed_units+1>=issued_units,'returned',status) WHERE id=?]], values = { payload.durability or -1, payload.issueId } }
                queries[#queries + 1] =
                    { query = "UPDATE sf_supply_outbox SET status='completed',attempts=attempts+1,last_error=NULL WHERE id=? AND status='inventory_done'", values = { row.id } }
                MySQL.transaction.await(queries)
            end
        end)
    end
end

function Supplies.ProcessDue(companyId)
    local params, query = { now() }, [[SELECT id,order_id,company_id FROM sf_supply_deliveries WHERE status='in_transit' AND due_at<=?]]
    if companyId then query = query .. ' AND company_id=?'; params[#params + 1] = companyId end
    for _, delivery in ipairs(MySQL.query.await(query, params) or {}) do
        Lock.With('delivery:' .. delivery.id, function()
            local live = MySQL.single.await('SELECT status FROM sf_supply_deliveries WHERE id=?', { delivery.id })
            if not live or live.status ~= 'in_transit' then return end
            local lines = MySQL.query.await('SELECT item_id,quantity FROM sf_supply_order_lines WHERE order_id=?', { delivery.order_id }) or {}
            local queries = {}
            for _, line in ipairs(lines) do
                local item = Sonar.ItemCatalog.byId[line.item_id]
                if item and item.tool then
                    for _ = 1, tonumber(line.quantity) do
                        queries[#queries + 1] = { query = [[INSERT INTO sf_warehouse_tool_units
                            (id,company_id,item_id,durability,status) VALUES (?,?,?,?, 'available')]],
                            values = { Sonar.Utils.Uuid(), delivery.company_id, line.item_id, 100 } }
                    end
                else
                    queries[#queries + 1] = { query = [[INSERT INTO sf_warehouse_lots (company_id,item_id,quantity)
                        VALUES (?,?,?) ON DUPLICATE KEY UPDATE quantity=quantity+VALUES(quantity)]],
                        values = { delivery.company_id, line.item_id, line.quantity } }
                end
            end
            local deliveredAt = now()
            queries[#queries + 1] = { query = "UPDATE sf_supply_deliveries SET status='delivered',delivered_at=? WHERE id=? AND status='in_transit'", values = { deliveredAt, delivery.id } }
            queries[#queries + 1] = { query = "UPDATE sf_supply_orders SET status='delivered',delivered_at=? WHERE id=? AND status='in_transit'", values = { deliveredAt, delivery.order_id } }
            queries[#queries + 1] = { query = "UPDATE sf_supply_receipts SET status='delivered' WHERE order_id=?", values = { delivery.order_id } }
            local ok, committed = pcall(function() return MySQL.transaction.await(queries) end)
            if not ok or committed ~= true then Logger.Warn('Delivery settlement failed: ' .. delivery.id, 'supplies') end
        end)
    end
end

local function access(source, permission)
    if not Supplies.IsEnabled() then return nil, 'unavailable' end
    local allowed, member = Company.HasPermission(source, permission, true)
    if not allowed then return nil, 'permission_denied' end
    return member
end

function Supplies.CreateDraft(source, rawLines)
    local member, reason = access(source, 'supplies.request')
    if not member then return reject(reason, 'Company purchasing is unavailable.') end
    if type(rawLines) ~= 'table' or #rawLines < 1 or #rawLines > Config.Supplies.MaxDraftLines then
        return reject('invalid_lines', 'The draft must contain 1 to 10 lines.')
    end
    local seen, lines, subtotal, lead = {}, {}, 0, 0
    for _, requested in ipairs(rawLines) do
        local item = Sonar.ItemCatalog.byId[tostring(requested.productId or '')]
        local quantity = math.floor(tonumber(requested.quantity) or 0)
        if not item or not item.market or seen[item.id] or quantity < 1 or quantity > Config.Supplies.MaxLineQuantity then
            return reject('invalid_lines', 'One or more draft lines are invalid.')
        end
        seen[item.id] = true
        local price = cents(item.price)
        lines[#lines + 1] = { item = item, quantity = quantity, unitPrice = price }
        subtotal = subtotal + price * quantity
        lead = math.max(lead, item.leadMinutes)
    end
    local fee = math.floor(subtotal * Config.Supplies.SupplierFeeRate + 0.5)
    local total = subtotal + fee
    local canOrder = member.permissionMap['supplies.order'] == true
    local needsApproval = not canOrder or (member.transactionLimit and total > cents(member.transactionLimit))
    local status = needsApproval and 'approval_required' or 'draft'
    local draftId = Sonar.Utils.Uuid()
    local queries = {{ query = [[INSERT INTO sf_supply_drafts
        (id,company_id,created_by,status,subtotal_cents,fee_cents,total_cents,expires_at)
        VALUES (?,?,?,?,?,?,?,?)]], values = { draftId, member.company_id, member.identifier, status, subtotal, fee, total, now() + Config.Supplies.DraftTtlSeconds } }}
    for _, line in ipairs(lines) do
        queries[#queries + 1] = { query = 'INSERT INTO sf_supply_draft_lines (draft_id,item_id,quantity,unit_price_cents) VALUES (?,?,?,?)', values = { draftId, line.item.id, line.quantity, line.unitPrice } }
    end
    local ok, result = pcall(function() return MySQL.transaction.await(queries) end)
    if not ok or result ~= true then return reject('database_error', 'The draft could not be saved.') end
    return { ok = true, changed = true, entityId = draftId, status = status, leadMinutes = lead,
        message = needsApproval and 'Procurement request created for approval.' or 'Purchase draft ready for Office confirmation.' }
end

function Supplies.Approve(source, draftId, decision)
    local member, reason = access(source, 'supplies.approve')
    if not member then return reject(reason, 'Procurement approval is not permitted.') end
    local status = decision == 'approve' and 'approved' or 'rejected'
    local changed = MySQL.update.await([[UPDATE sf_supply_drafts SET status=?,approved_by=?
        WHERE id=? AND company_id=? AND status='approval_required' AND expires_at>?]],
        { status, member.identifier, draftId, member.company_id, now() })
    if tonumber(changed) ~= 1 then return reject('stale', 'This request is no longer pending.') end
    return { ok = true, changed = true, message = decision == 'approve' and 'Procurement request approved.' or 'Procurement request rejected.' }
end

function Supplies.Confirm(source, draftId)
    local member, reason = access(source, 'supplies.order')
    if not member then return reject(reason, 'Ordering permission is required.') end
    -- Supplier stock is shared by every company, so confirmations serialize on
    -- one resource-wide key rather than only per company.
    local acquired, result = Lock.With('supplier-order', function()
        local existing = MySQL.single.await('SELECT id,receipt_id,status FROM sf_supply_orders WHERE draft_id=? AND company_id=? LIMIT 1',
            { draftId, member.company_id })
        if existing then return { ok = true, changed = false, entityId = existing.id, receiptId = existing.receipt_id, status = existing.status, message = 'This order was already confirmed.' } end
        local draft = MySQL.single.await('SELECT * FROM sf_supply_drafts WHERE id=? AND company_id=?', { draftId, member.company_id })
        if not draft or (draft.status ~= 'draft' and draft.status ~= 'approved') then return reject('stale', 'This draft cannot be confirmed.') end
        if tonumber(draft.expires_at) <= now() then
            MySQL.update.await("UPDATE sf_supply_drafts SET status='failed' WHERE id=?", { draftId })
            return reject('expired', 'The draft expired and must be recreated.')
        end
        local lines = loadLines(draftId)
        local stocks = stockMap(true)
        local subtotal, lead = 0, 0
        for _, line in ipairs(lines) do
            local item = Sonar.ItemCatalog.byId[line.item_id]
            if not item or not item.market or cents(item.price) ~= tonumber(line.unit_price_cents) then return reject('price_changed', 'Supplier pricing changed.') end
            local stock = stocks[item.id]
            if stock and tonumber(stock.quantity) < tonumber(line.quantity) then return reject('stock_changed', item.label .. ' stock changed.') end
            subtotal = subtotal + cents(item.price) * tonumber(line.quantity)
            lead = math.max(lead, item.leadMinutes)
        end
        local fee = math.floor(subtotal * Config.Supplies.SupplierFeeRate + 0.5)
        local total = subtotal + fee
        if total ~= tonumber(draft.total_cents) then return reject('price_changed', 'The draft total changed.') end
        if member.transactionLimit and total > cents(member.transactionLimit) then
            return reject('transaction_limit', 'This order exceeds your role transaction limit; an Owner or Manager must confirm it.')
        end
        local company = MySQL.single.await('SELECT treasury_cents,monthly_budget_cents FROM sf_companies WHERE id=?', { member.company_id })
        if not company or tonumber(company.treasury_cents) < total then return reject('insufficient_funds', 'Company Treasury has insufficient funds.') end
        if monthlySpent(member.company_id) + total > tonumber(company.monthly_budget_cents) then return reject('budget_exceeded', 'The monthly procurement budget is exhausted.') end

        local orderId, receiptId, deliveryId = Sonar.Utils.Uuid(), Sonar.Utils.Uuid(), Sonar.Utils.Uuid()
        local balanceAfter, dueAt = tonumber(company.treasury_cents) - total, now() + lead * 60
        local queries = {
            { query = 'UPDATE sf_companies SET treasury_cents=treasury_cents-? WHERE id=? AND treasury_cents>=?', values = { total, member.company_id, total } },
            { query = [[INSERT INTO sf_supply_orders
                (id,company_id,draft_id,receipt_id,status,subtotal_cents,fee_cents,total_cents,created_by,due_at)
                VALUES (?,?,?,?,?,?,?,?,?,?)]], values = { orderId, member.company_id, draftId, receiptId, 'in_transit', subtotal, fee, total, member.identifier, dueAt } },
            { query = 'INSERT INTO sf_supply_deliveries (id,order_id,company_id,status,due_at) VALUES (?,?,?,?,?)', values = { deliveryId, orderId, member.company_id, 'in_transit', dueAt } },
            { query = 'INSERT INTO sf_supply_receipts (id,order_id,company_id,total_cents,status) VALUES (?,?,?,?,?)', values = { receiptId, orderId, member.company_id, total, 'in_transit' } },
            { query = [[INSERT INTO sf_company_ledger
                (id,company_id,idempotency_key,entry_type,direction,amount_cents,balance_after_cents,actor_identifier,linked_kind,linked_id)
                VALUES (?,?,?,?,?,?,?,?,?,?)]], values = { Sonar.Utils.Uuid(), member.company_id, 'purchase:' .. draftId, 'purchase', 'debit', total, balanceAfter, member.identifier, 'order', orderId } },
            { query = "UPDATE sf_supply_drafts SET status='ordered' WHERE id=?", values = { draftId } },
        }
        for _, line in ipairs(lines) do
            queries[#queries + 1] = { query = 'INSERT INTO sf_supply_order_lines (order_id,item_id,quantity,unit_price_cents) VALUES (?,?,?,?)', values = { orderId, line.item_id, line.quantity, line.unit_price_cents } }
            if stocks[line.item_id] then queries[#queries + 1] = { query = 'UPDATE sf_supplier_stock SET quantity=quantity-? WHERE item_id=? AND quantity>=?', values = { line.quantity, line.item_id, line.quantity } } end
        end
        local ok, committed = pcall(function() return MySQL.transaction.await(queries) end)
        if not ok or committed ~= true then return reject('database_error', 'The order transaction failed safely.') end
        Company.Invalidate(member.identifier)
        return { ok = true, changed = true, entityId = orderId, receiptId = receiptId, status = 'in_transit', dueAt = dueAt, message = 'Order confirmed. Delivery is in transit to the Warehouse.' }
    end)
    return acquired and result or reject('busy', 'Company procurement is busy; retry shortly.')
end

function Supplies.LoadPurchase(source, purchaseId)
    local member, reason = access(source, 'supplies.view')
    if not member then return nil, reason end
    Supplies.ProcessDue(member.company_id)
    local draft = MySQL.single.await('SELECT * FROM sf_supply_drafts WHERE id=? AND company_id=?', { purchaseId, member.company_id })
    local order = MySQL.single.await('SELECT * FROM sf_supply_orders WHERE (id=? OR draft_id=?) AND company_id=? LIMIT 1', { purchaseId, purchaseId, member.company_id })
    if not draft and order then draft = MySQL.single.await('SELECT * FROM sf_supply_drafts WHERE id=?', { order.draft_id }) end
    if not draft then return nil, 'not_found' end
    local lines = loadLines(draft.id)
    local outputLines = {}
    for _, line in ipairs(lines) do
        local item = Sonar.ItemCatalog.byId[line.item_id]
        outputLines[#outputLines + 1] = { productId = line.item_id, quantity = line.quantity, name = item and item.label or line.item_id, unit = 'unit', unitPrice = dollars(line.unit_price_cents) }
    end
    local company = MySQL.single.await('SELECT treasury_cents,monthly_budget_cents FROM sf_companies WHERE id=?', { member.company_id })
    local status = order and order.status or draft.status
    if not order and tonumber(draft.expires_at) <= now() and status ~= 'rejected' then status = 'failed' end
    return {
        id = order and order.id or draft.id, draftId = draft.id, reference = ('PO-%s'):format((order and order.id or draft.id):sub(1, 8):upper()),
        payer = 'company', lines = outputLines, subtotal = dollars(draft.subtotal_cents), fees = dollars(draft.fee_cents), total = dollars(draft.total_cents),
        balance = dollars(company.treasury_cents), projectedBalance = dollars(company.treasury_cents - draft.total_cents),
        budgetRemaining = dollars(company.monthly_budget_cents - monthlySpent(member.company_id)), transactionLimit = member.transactionLimit,
        ownership = 'Company', inventoryCapacity = 'Delivered to Company Warehouse', fulfillment = 'Delayed Warehouse delivery',
        status = status, receiptId = order and order.receipt_id or nil, dueAt = order and order.due_at or nil,
        canConfirm = member.permissionMap['supplies.order'] == true and (status == 'draft' or status == 'approved')
            and (not member.transactionLimit or tonumber(draft.total_cents) <= cents(member.transactionLimit)),
        canApprove = member.permissionMap['supplies.approve'] == true and status == 'approval_required',
    }
end

function Supplies.LoadHub(source)
    local member, reason = access(source, 'supplies.view')
    if not member then return nil, reason end
    Supplies.ReconcileOutbox(source, member)
    Supplies.ProcessDue(member.company_id)
    local stocks = stockMap()
    local lots = {}
    for _, row in ipairs(MySQL.query.await('SELECT item_id,quantity FROM sf_warehouse_lots WHERE company_id=?', { member.company_id }) or {}) do lots[row.item_id] = tonumber(row.quantity) or 0 end
    for _, row in ipairs(MySQL.query.await([[SELECT item_id,COUNT(*) AS quantity FROM sf_warehouse_tool_units
        WHERE company_id=? AND status='available' GROUP BY item_id]], { member.company_id }) or {}) do
        lots[row.item_id] = (lots[row.item_id] or 0) + (tonumber(row.quantity) or 0)
    end
    local products = {}
    for _, item in ipairs(Sonar.ItemCatalog.market) do
        local stock = stocks[item.id]
        products[#products + 1] = {
            id = item.id, name = item.label, category = item.category, cropRelation = item.cropRelation,
            detail = item.description, effect = lineEffect(item), tier = item.tier, image = 'assets/items/' .. item.id .. '.png',
            unit = 'unit', unitPrice = item.price, stock = stock and tonumber(stock.quantity) or 'base',
            restock = stock and ('Restocks %d every %dm'):format(stock.restock_amount, stock.restock_seconds / 60) or 'Base supplier stock',
            personalOwned = 0, companyOwned = lots[item.id] or 0, leadMinutes = item.leadMinutes,
            applications = item.tool and item.tool.uses or 1,
        }
    end
    local spent = monthlySpent(member.company_id)
    local company = MySQL.single.await('SELECT treasury_cents,monthly_budget_cents FROM sf_companies WHERE id=?', { member.company_id })
    local requests = {}
    for _, row in ipairs(MySQL.query.await([[SELECT id,created_by,total_cents,status FROM sf_supply_drafts
        WHERE company_id=? AND status IN ('approval_required','approved','rejected') ORDER BY created_at DESC LIMIT 20]], { member.company_id }) or {}) do
        requests[#requests + 1] = { id = row.id, requestedBy = row.created_by, summary = 'Company supply order', amount = dollars(row.total_cents), status = row.status == 'approval_required' and 'pending' or row.status }
    end
    local issues = {}
    for _, row in ipairs(MySQL.query.await([[SELECT * FROM sf_material_issues WHERE company_id=? ORDER BY created_at DESC LIMIT 50]], { member.company_id }) or {}) do
        local item = Sonar.ItemCatalog.byId[row.item_id]
        issues[#issues + 1] = { id = row.id, asset = item and item.label or row.item_id, worker = row.identifier, assignment = 'Warehouse custody',
            issued = row.issued_units, used = item and item.tool and (row.uses_spent or 0) or (row.consumed_units or 0), remaining = math.max(0, row.issued_units - row.consumed_units - row.returned_units),
            unit = item and item.tool and 'tool' or 'unit', status = row.status == 'issued' and 'issued' or row.status,
            availableActions = row.status == 'issued' and row.identifier == member.identifier
                and member.permissionMap['warehouse.return'] and { 'return' } or {} }
    end
    return {
        products = products, allowedPayers = { 'company' }, personalBalance = 0, companyBalance = dollars(company.treasury_cents),
        procurement = { monthlyBudget = dollars(company.monthly_budget_cents), remaining = dollars(company.monthly_budget_cents - spent),
            transactionLimit = member.transactionLimit or dollars(company.monthly_budget_cents), allowedCategories = { 'Seedlings','Seeds','Hand Tools','Watering','Fertilizer','Pest Treatment' },
            recentPurchases = {}, requests = requests, violations = {} },
        issuedMaterials = issues,
    }
end

function Supplies.LoadWarehouse(source)
    local member, reason = access(source, 'warehouse.view')
    if not member then return nil, reason end
    Supplies.ReconcileOutbox(source, member)
    Supplies.ProcessDue(member.company_id)
    local items, used = {}, 0
    for _, row in ipairs(MySQL.query.await('SELECT item_id,quantity FROM sf_warehouse_lots WHERE company_id=? AND quantity>0 ORDER BY item_id', { member.company_id }) or {}) do
        local item = Sonar.ItemCatalog.byId[row.item_id]
        used = used + tonumber(row.quantity)
        items[#items + 1] = { id = row.item_id, name = item and item.label or row.item_id, category = item and item.tool and 'tool' or 'material', unit = 'unit', total = row.quantity,
            available = row.quantity, reserved = 0, quality = {{ label = item and item.tier or 'standard', quantity = row.quantity }}, incoming = 0,
            status = tonumber(row.quantity) <= 2 and 'low' or 'stocked', location = 'Company Warehouse' }
    end
    for _, row in ipairs(MySQL.query.await([[SELECT item_id,COUNT(*) AS quantity,MIN(durability) AS min_durability
        FROM sf_warehouse_tool_units WHERE company_id=? AND status='available' GROUP BY item_id ORDER BY item_id]], { member.company_id }) or {}) do
        local item = Sonar.ItemCatalog.byId[row.item_id]
        local quantity = tonumber(row.quantity) or 0
        used = used + quantity
        items[#items + 1] = { id = row.item_id, name = item and item.label or row.item_id, category = 'tool', unit = 'unit', total = quantity,
            available = quantity, reserved = 0, quality = {{ label = ('%s · next %d%%'):format(item and item.tier or 'standard', math.floor(tonumber(row.min_durability) or 0)), quantity = quantity }}, incoming = 0,
            status = quantity <= 2 and 'low' or 'stocked', location = 'Company Warehouse' }
    end
    local incoming = {}
    for _, row in ipairs(MySQL.query.await([[SELECT o.id,o.receipt_id,o.due_at,l.item_id,l.quantity FROM sf_supply_orders o
        JOIN sf_supply_order_lines l ON l.order_id=o.id WHERE o.company_id=? AND o.status='in_transit' ORDER BY o.due_at]], { member.company_id }) or {}) do
        local item = Sonar.ItemCatalog.byId[row.item_id]
        incoming[#incoming + 1] = { id = row.id .. ':' .. row.item_id, product = item and item.label or row.item_id, reference = row.receipt_id,
            custodian = 'Supplier delivery', quantity = row.quantity, unit = 'unit', status = 'in_transit', dueAt = row.due_at }
    end
    return { items = items, reservations = {}, incomingCargo = incoming, capacity = { used = used, total = 1000 }, atWarehouse = true,
        canManage = member.permissionMap['warehouse.withdraw'] == true, canSellWholesale = false }
end

local function ledgerRows(member, limit)
    limit = math.max(1, math.min(100, math.floor(tonumber(limit) or 100)))
    local rows = MySQL.query.await(('SELECT * FROM sf_company_ledger WHERE company_id=? ORDER BY created_at DESC LIMIT %d'):format(limit),
        { member.company_id }) or {}
    local entries = {}
    for _, row in ipairs(rows) do
        entries[#entries + 1] = {
            id = row.id, idempotencyKey = row.idempotency_key,
            type = row.entry_type == 'purchase' and 'purchase' or 'owner_contribution',
            amount = dollars(row.amount_cents), direction = row.direction,
            actorId = row.actor_identifier, actor = row.actor_identifier,
            at = tostring(row.created_at), source = row.direction == 'credit' and 'Owner' or 'Company Treasury',
            destination = row.direction == 'credit' and 'Company Treasury' or 'Supplier',
            linkedKind = row.linked_kind, linkedId = row.linked_id, status = 'completed',
            balanceAfter = dollars(row.balance_after_cents),
        }
    end
    return entries
end

function Supplies.LoadCompanyHome(source)
    local member, reason = access(source, 'warehouse.view')
    if not member then return nil, reason end
    Supplies.ProcessDue(member.company_id)
    local company = MySQL.single.await('SELECT * FROM sf_companies WHERE id=?', { member.company_id })
    local total = tonumber(MySQL.scalar.await('SELECT COALESCE(SUM(quantity),0) FROM sf_warehouse_lots WHERE company_id=?', { member.company_id })) or 0
    total = total + (tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM sf_warehouse_tool_units WHERE company_id=? AND status='available'", { member.company_id })) or 0)
    local pending = tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM sf_supply_drafts WHERE company_id=? AND status='approval_required'", { member.company_id })) or 0
    local spent = monthlySpent(member.company_id)
    local remaining = dollars(company.monthly_budget_cents - spent)
    local modules = {
        { id = 'warehouse', area = 'operations', title = 'Warehouse', detail = 'Supply lots, incoming deliveries and issued custody', value = tostring(total) .. ' items', path = '/company/warehouse', priority = 'normal' },
    }
    if member.permissionMap['supplies.view_ledger'] then
        modules[#modules + 1] = { id = 'treasury', area = 'finance', title = 'Treasury', detail = 'Available Company funds and procurement budget', value = ('$%s'):format(dollars(company.treasury_cents)), path = '/company/treasury', priority = 'normal' }
        modules[#modules + 1] = { id = 'ledger', area = 'finance', title = 'Transaction Ledger', detail = 'Immutable procurement movements', value = tostring(#ledgerRows(member, 100)) .. ' entries', path = '/company/ledger', priority = 'normal' }
    end
    return {
        company = { id = company.id, name = company.name, originalName = company.name, brandName = 'Sonar Farm', status = 'operating',
            ownerId = company.owner_identifier, ownerName = company.owner_identifier, description = 'Authoritative farming company',
            officeLocation = 'Grapeseed Farm Office', foundedAt = tostring(company.created_at), capabilitiesRevision = 1 },
        headline = pending > 0 and (tostring(pending) .. ' procurement request(s) require approval') or 'Company supplies and custody are synchronized',
        modules = modules, procurementLink = { remaining = remaining, pending = pending, path = '/supplies?area=procurement' },
    }
end

function Supplies.LoadTreasury(source)
    local member, reason = access(source, 'supplies.view_ledger')
    if not member then return nil, reason end
    local company = MySQL.single.await('SELECT treasury_cents FROM sf_companies WHERE id=?', { member.company_id })
    local incoming = tonumber(MySQL.scalar.await("SELECT COALESCE(SUM(total_cents),0) FROM sf_supply_orders WHERE company_id=? AND status='in_transit'", { member.company_id })) or 0
    local valuation = tonumber(MySQL.scalar.await([[SELECT COALESCE(SUM(l.quantity * 100),0) FROM sf_warehouse_lots l WHERE l.company_id=?]], { member.company_id })) or 0
    valuation = valuation + (tonumber(MySQL.scalar.await("SELECT COUNT(*) * 100 FROM sf_warehouse_tool_units WHERE company_id=? AND status='available'", { member.company_id })) or 0)
    return { available = dollars(company.treasury_cents), escrowReserved = 0, assignmentPayReserved = 0, leaseObligations = 0,
        pendingBuyerIncome = 0, warehouseValuation = dollars(valuation), recentEntries = ledgerRows(member, 5), availableActions = { 'ledger' },
        supplierCommitments = dollars(incoming) }
end

function Supplies.LoadLedger(source)
    local member, reason = access(source, 'supplies.view_ledger')
    if not member then return nil, reason end
    return ledgerRows(member, 100)
end

function Supplies.Withdraw(source, itemId, quantity, operationId)
    local member, reason = access(source, 'warehouse.withdraw')
    if not member then return reject(reason, 'Warehouse withdrawal is not permitted.') end
    local item = Sonar.ItemCatalog.byId[itemId]
    quantity = math.floor(tonumber(quantity) or 0)
    operationId = tostring(operationId or '')
    if not item or quantity < 1 or quantity > Config.Supplies.MaxLineQuantity or (item.tool and quantity ~= 1)
        or #operationId < 8 or #operationId > 100 or not operationId:match('^[%w_:%-]+$') then
        return reject('invalid_item', 'Invalid Warehouse request.')
    end
    local memberAcquired, memberResult = Lock.With('member-custody:' .. member.identifier, function()
        local stillAllowed, liveMember = Company.HasPermission(source, 'warehouse.withdraw', true)
        if not stillAllowed or not liveMember or liveMember.company_id ~= member.company_id then
            return reject('permission_denied', 'Company membership changed before the withdrawal.')
        end
        member = liveMember
        local acquired, result = Lock.With('warehouse:' .. member.company_id .. ':' .. itemId, function()
        local existing = MySQL.single.await([[SELECT id,status FROM sf_material_issues
            WHERE company_id=? AND idempotency_key=? LIMIT 1]], { member.company_id, operationId })
        if existing then
            return { ok = existing.status ~= 'failed', changed = false, entityId = existing.id,
                message = existing.status == 'failed' and 'The previous withdrawal attempt failed safely.' or 'This withdrawal was already processed.' }
        end
        local toolUnit
        if item.tool then
            toolUnit = MySQL.single.await([[SELECT id,durability FROM sf_warehouse_tool_units
                WHERE company_id=? AND item_id=? AND status='available' ORDER BY durability,id LIMIT 1]], { member.company_id, itemId })
        end
        local available = item.tool and (toolUnit and 1 or 0)
            or (tonumber(MySQL.scalar.await('SELECT quantity FROM sf_warehouse_lots WHERE company_id=? AND item_id=?', { member.company_id, itemId })) or 0)
        if available < quantity then return reject('stock_changed', 'Warehouse stock changed.') end
        if not Bridge.Inventory.CanCarry(source, itemId, quantity) then return reject('inventory_full', 'Your inventory cannot carry this withdrawal.') end
        local issueId, outboxId = Sonar.Utils.Uuid(), Sonar.Utils.Uuid()
        local metadata = { ownership = 'company', companyId = member.company_id, issueId = issueId, itemId = itemId }
        if item.tool then metadata.durability = tonumber(toolUnit.durability) end
        local payload = json.encode({ issueId = issueId, identifier = member.identifier, itemId = itemId, quantity = quantity,
            warehouseUnitId = toolUnit and toolUnit.id or nil, metadata = metadata })
        local queries = {}
        if item.tool then
            queries[#queries + 1] = { query = [[UPDATE sf_warehouse_tool_units SET status='reserved',issue_id=?
                WHERE id=? AND status='available']], values = { issueId, toolUnit.id } }
        else
            queries[#queries + 1] = { query = 'UPDATE sf_warehouse_lots SET quantity=quantity-? WHERE company_id=? AND item_id=? AND quantity>=?', values = { quantity, member.company_id, itemId, quantity } }
        end
        queries[#queries + 1] =
            { query = [[INSERT INTO sf_material_issues
                (id,company_id,identifier,item_id,issued_units,durability,warehouse_unit_id,idempotency_key,status)
                VALUES (?,?,?,?,?,?,NULLIF(?,''),?,?)]], values = { issueId, member.company_id, member.identifier, itemId, quantity,
                    item.tool and tonumber(toolUnit.durability) or -1, toolUnit and toolUnit.id or '', operationId, 'pending' } }
        queries[#queries + 1] =
            { query = [[INSERT INTO sf_supply_outbox
                (id,company_id,identifier,kind,idempotency_key,status,payload) VALUES (?,?,?,?,?,?,?)]],
                values = { outboxId, member.company_id, member.identifier, 'withdraw', operationId, 'pending', payload } }
        local ok, committed = pcall(function() return MySQL.transaction.await(queries) end)
        if not ok or committed ~= true then return reject('database_error', 'Warehouse reservation failed safely.') end
        if Bridge.Inventory.AddItem(source, itemId, quantity, metadata) then
            MySQL.transaction.await({
                { query = "UPDATE sf_material_issues SET status='issued' WHERE id=?", values = { issueId } },
                { query = "UPDATE sf_warehouse_tool_units SET status='issued' WHERE id=? AND status='reserved'", values = { toolUnit and toolUnit.id or '' } },
                { query = "UPDATE sf_supply_outbox SET status='completed',attempts=attempts+1 WHERE id=?", values = { outboxId } },
            })
            return { ok = true, changed = true, entityId = issueId, message = 'Material withdrawn under Company custody.' }
        end
        local compensation = {}
        if item.tool then
            compensation[#compensation + 1] = { query = [[UPDATE sf_warehouse_tool_units
                SET status='available',issue_id=NULL WHERE id=? AND issue_id=?]], values = { toolUnit.id, issueId } }
        else
            compensation[#compensation + 1] = { query = 'UPDATE sf_warehouse_lots SET quantity=quantity+? WHERE company_id=? AND item_id=?', values = { quantity, member.company_id, itemId } }
        end
        compensation[#compensation + 1] =
            { query = "UPDATE sf_material_issues SET status='failed' WHERE id=?", values = { issueId } }
        compensation[#compensation + 1] =
            { query = "UPDATE sf_supply_outbox SET status='failed',attempts=attempts+1,last_error='inventory_add_failed' WHERE id=?", values = { outboxId } }
        MySQL.transaction.await(compensation)
        return reject('inventory_full', 'Inventory changed before the material could be issued.')
        end)
        return acquired and result or reject('busy', 'Warehouse stock is busy; retry shortly.')
    end)
    return memberAcquired and memberResult or reject('busy', 'Member custody is busy; retry shortly.')
end

function Supplies.Return(source, issueId, operationId)
    local member, reason = access(source, 'warehouse.return')
    if not member then return reject(reason, 'Warehouse return is not permitted.') end
    operationId = tostring(operationId or '')
    if #operationId < 8 or #operationId > 100 or not operationId:match('^[%w_:%-]+$') then
        return reject('invalid_operation', 'Invalid Warehouse return request.')
    end
    local memberAcquired, memberResult = Lock.With('member-custody:' .. member.identifier, function()
        local stillAllowed, liveMember = Company.HasPermission(source, 'warehouse.return', true)
        if not stillAllowed or not liveMember or liveMember.company_id ~= member.company_id then
            return reject('permission_denied', 'Company membership changed before the return.')
        end
        member = liveMember
        if Company.HasPendingItemUse(member.company_id, member.identifier, tostring(issueId)) then
            return reject('busy', 'This material has an unfinished use; retry shortly.')
        end
        local acquired, result = Lock.With('return:' .. member.company_id .. ':' .. tostring(issueId), function()
        local prior = MySQL.single.await([[SELECT id,status FROM sf_supply_outbox
            WHERE company_id=? AND kind='return' AND idempotency_key=? LIMIT 1]], { member.company_id, operationId })
        if prior then
            if prior.status ~= 'completed' and prior.status ~= 'failed' then
                Supplies.ReconcileOutbox(source, member)
                prior = MySQL.single.await('SELECT id,status FROM sf_supply_outbox WHERE id=?', { prior.id }) or prior
            end
            return { ok = prior.status ~= 'failed', changed = false,
                message = prior.status == 'completed' and 'This return was already processed.' or 'The previous return is still reconciling.' }
        end
        local issue = MySQL.single.await([[SELECT * FROM sf_material_issues WHERE id=? AND company_id=? AND identifier=? AND status='issued']],
            { issueId, member.company_id, member.identifier })
        if not issue then return reject('stale', 'This custody record cannot be returned.') end
        local slots = Bridge.Inventory.GetSlotsWithItem(source, issue.item_id, { issueId = issueId }, false)
        local slot
        for _, candidate in pairs(slots or {}) do if not slot or (candidate.slot or 0) < (slot.slot or 0) then slot = candidate end end
        if not slot then return reject('missing_item', 'The issued material is not in your inventory.') end
        local durability = slot.metadata and tonumber(slot.metadata.durability) or nil
        local outboxId = Sonar.Utils.Uuid()
        MySQL.insert.await([[INSERT INTO sf_supply_outbox
            (id,company_id,identifier,kind,idempotency_key,status,payload) VALUES (?,?,?,?,?,?,?)]],
            { outboxId, member.company_id, member.identifier, 'return', operationId, 'prepared',
                json.encode({ issueId = issueId, identifier = member.identifier, itemId = issue.item_id,
                    warehouseUnitId = issue.warehouse_unit_id, durability = durability }) })
        if not Bridge.Inventory.RemoveFromSlot(source, issue.item_id, 1, slot.slot, slot.metadata) then
            MySQL.update.await("UPDATE sf_supply_outbox SET status='failed',last_error='inventory_remove_failed' WHERE id=?", { outboxId })
            return reject('missing_item', 'The issued material changed before return.')
        end
        local queries = {}
        if issue.warehouse_unit_id then
            queries[#queries + 1] = { query = [[UPDATE sf_warehouse_tool_units
                SET status='available',durability=?,issue_id=NULL WHERE id=? AND issue_id=?]],
                values = { durability or 0, issue.warehouse_unit_id, issueId } }
        else
            queries[#queries + 1] = { query = [[INSERT INTO sf_warehouse_lots (company_id,item_id,quantity) VALUES (?,?,1)
                ON DUPLICATE KEY UPDATE quantity=quantity+1]], values = { member.company_id, issue.item_id } }
        end
        queries[#queries + 1] = { query = [[UPDATE sf_material_issues SET returned_units=returned_units+1,durability=?,
            status=IF(returned_units+consumed_units+1>=issued_units,'returned',status) WHERE id=?]], values = { durability or -1, issueId } }
        queries[#queries + 1] = { query = "UPDATE sf_supply_outbox SET status='completed',attempts=attempts+1 WHERE id=?", values = { outboxId } }
        local ok, committed = pcall(function() return MySQL.transaction.await(queries) end)
        if not ok or committed ~= true then
            MySQL.update.await("UPDATE sf_supply_outbox SET status='inventory_done',attempts=attempts+1,last_error='db_finalize_failed' WHERE id=?", { outboxId })
            return reject('reconciliation_pending', 'Return accepted; Warehouse reconciliation is pending.')
        end
        return { ok = true, changed = true, message = 'Material returned with its remaining durability.' }
        end)
        return acquired and result or reject('busy', 'This custody record is busy; retry shortly.')
    end)
    return memberAcquired and memberResult or reject('busy', 'Member custody is busy; retry shortly.')
end
