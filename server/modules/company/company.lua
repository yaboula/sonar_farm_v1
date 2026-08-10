-- Minimal authoritative Company core for the Supplies vertical.

Company = Company or {}

local cache = {}
local CACHE_TTL = 30

local PERMISSIONS = {
    owner = { 'supplies.view', 'supplies.request', 'supplies.order', 'supplies.approve', 'supplies.view_ledger', 'warehouse.view', 'warehouse.withdraw', 'warehouse.return',
        'fields.view_portfolio', 'fields.view_assigned', 'fields.view_team', 'fields.view_economics', 'fields.view_materials', 'fields.view_history', 'fields.plan', 'fields.acquire', 'fields.route',
        'work.view_own', 'work.view_team', 'work.create', 'work.review', 'contracts.browse', 'contracts.create', 'contracts.review',
        'cargo.view_own', 'cargo.view_team', 'cargo.deposit', 'buyer_orders.view', 'buyer_orders.manage' },
    manager = { 'supplies.view', 'supplies.request', 'supplies.order', 'supplies.approve', 'supplies.view_ledger', 'warehouse.view', 'warehouse.withdraw', 'warehouse.return',
        'fields.view_portfolio', 'fields.view_assigned', 'fields.view_team', 'fields.view_economics', 'fields.view_materials', 'fields.view_history', 'fields.plan', 'fields.acquire', 'fields.route',
        'work.view_own', 'work.view_team', 'work.create', 'work.review', 'contracts.browse', 'contracts.create', 'contracts.review',
        'cargo.view_own', 'cargo.view_team', 'cargo.deposit', 'buyer_orders.view', 'buyer_orders.manage' },
    procurement = { 'supplies.view', 'supplies.request', 'supplies.order', 'supplies.view_ledger', 'warehouse.view', 'warehouse.withdraw', 'warehouse.return',
        'fields.view_portfolio', 'fields.view_materials', 'fields.route', 'work.view_own', 'cargo.view_own', 'cargo.deposit', 'buyer_orders.view' },
    supervisor = { 'supplies.view', 'supplies.request', 'warehouse.view', 'warehouse.withdraw', 'warehouse.return',
        'fields.view_portfolio', 'fields.view_assigned', 'fields.view_team', 'fields.view_materials', 'fields.view_history', 'fields.plan', 'fields.route',
        'work.view_own', 'work.view_team', 'work.create', 'work.review', 'contracts.browse', 'contracts.create', 'contracts.review',
        'cargo.view_own', 'cargo.view_team', 'cargo.deposit', 'buyer_orders.view' },
    worker = { 'supplies.view', 'supplies.request', 'warehouse.view', 'warehouse.withdraw', 'warehouse.return',
        'fields.view_assigned', 'fields.route', 'work.view_own', 'contracts.browse', 'cargo.view_own', 'cargo.deposit' },
}

local function encode(value) return json.encode(value) end
local function decode(value)
    if type(value) == 'table' then return value end
    local ok, result = pcall(json.decode, value or '[]')
    return ok and type(result) == 'table' and result or {}
end

local function dollars(cents) return math.floor((tonumber(cents) or 0) + 0.5) / 100 end

local function permissionMap(list)
    local result = {}
    for _, permission in ipairs(list or {}) do result[permission] = true end
    return result
end

function Company.Invalidate(identifier)
    if identifier then cache[identifier] = nil else cache = {} end
end

function Company.Init()
    if not CompanyDatabase.Init() then return false end
    if not Fields.Init() then return false end
    -- Add newly introduced stable permissions without deleting custom policy entries.
    for _, row in ipairs(MySQL.query.await('SELECT company_id,role_key,permissions FROM sf_company_roles') or {}) do
        local defaults, current = PERMISSIONS[row.role_key], decode(row.permissions)
        if defaults then
            local seen, changed = {}, false
            for _, permission in ipairs(current) do seen[permission] = true end
            for _, permission in ipairs(defaults) do
                if not seen[permission] then current[#current + 1], changed = permission, true end
            end
            if changed then MySQL.update.await('UPDATE sf_company_roles SET permissions=? WHERE company_id=? AND role_key=?',
                { encode(current), row.company_id, row.role_key }) end
        end
    end
    local now = Sonar.Time.Now()
    for _, item in ipairs(Sonar.ItemCatalog.market) do
        local stock = Config.Supplies.SupplierStock[item.tier]
        if stock then
            MySQL.insert.await([[
                INSERT INTO sf_supplier_stock
                  (item_id,tier,quantity,capacity,restock_amount,restock_seconds,last_restock_at)
                VALUES (?,?,?,?,?,?,?)
                ON DUPLICATE KEY UPDATE tier=VALUES(tier), capacity=VALUES(capacity),
                  restock_amount=VALUES(restock_amount), restock_seconds=VALUES(restock_seconds)]],
                { item.id, item.tier, stock.capacity, stock.capacity, stock.restockAmount, stock.restockSeconds, now })
        end
    end
    return true
end

function Company.GetMembershipByIdentifier(identifier, fresh)
    if type(identifier) ~= 'string' or identifier == '' then return nil end
    local existing = cache[identifier]
    if not fresh and existing and existing.expiresAt > Sonar.Time.Now() then return existing.value end
    local row = MySQL.single.await([[
        SELECT m.company_id,m.identifier,m.display_name,m.role_key,m.status,
               r.permissions,r.transaction_limit_cents,c.name AS company_name,
               c.treasury_cents,c.monthly_budget_cents
        FROM sf_company_members m
        JOIN sf_company_roles r ON r.company_id=m.company_id AND r.role_key=m.role_key
        JOIN sf_companies c ON c.id=m.company_id
        WHERE m.identifier=? AND m.status='active' LIMIT 1]], { identifier })
    if not row then
        cache[identifier] = { value = nil, expiresAt = Sonar.Time.Now() + CACHE_TTL }
        return nil
    end
    row.permissionList = decode(row.permissions)
    row.permissionMap = permissionMap(row.permissionList)
    row.transactionLimit = tonumber(row.transaction_limit_cents) and tonumber(row.transaction_limit_cents) >= 0
        and dollars(row.transaction_limit_cents) or nil
    row.treasury = dollars(row.treasury_cents)
    row.monthlyBudget = dollars(row.monthly_budget_cents)
    cache[identifier] = { value = row, expiresAt = Sonar.Time.Now() + CACHE_TTL }
    return row
end

function Company.GetMembership(source, fresh)
    return Company.GetMembershipByIdentifier(Bridge.GetIdentifier(source), fresh)
end

function Company.IsActiveMember(source, companyId)
    local member = Company.GetMembership(source)
    return member ~= nil and member.status == 'active' and member.company_id == companyId
end

function Company.HasPermission(source, permission, fresh)
    local member = Company.GetMembership(source, fresh)
    return member ~= nil and member.status == 'active' and member.permissionMap[permission] == true, member
end

function Company.Bootstrap(source, companyName)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return false, 'player_not_ready' end
    local existing = MySQL.single.await('SELECT id,name FROM sf_companies WHERE owner_identifier=? LIMIT 1', { identifier })
    if existing then
        local holding = MySQL.scalar.await('SELECT field_id FROM sf_company_fields WHERE company_id=? LIMIT 1', { existing.id })
        if holding then return true, existing.id end
        local acquired, result = Lock.With('starter-field-bootstrap', function()
            local _, starterQuery = Fields.StarterForBootstrap(existing.id, identifier)
            return starterQuery and MySQL.transaction.await({ starterQuery }) == true
        end)
        return acquired and result == true, acquired and result == true and existing.id or 'no_starter_field'
    end
    local membership = MySQL.single.await('SELECT company_id FROM sf_company_members WHERE identifier=? LIMIT 1', { identifier })
    if membership then return false, 'already_company_member' end

    companyName = tostring(companyName or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #companyName < 3 or #companyName > 80 then return false, 'invalid_company_name' end
    local companyId = Sonar.Utils.Uuid()
    local treasury = math.floor(Config.Supplies.BootstrapTreasury * 100)
    local budget = math.floor(Config.Supplies.MonthlyBudget * 100)
    local ledgerId = Sonar.Utils.Uuid()
    local queries = {
        { query = 'INSERT INTO sf_companies (id,name,owner_identifier,treasury_cents,monthly_budget_cents) VALUES (?,?,?,?,?)', values = { companyId, companyName, identifier, treasury, budget } },
        { query = 'INSERT INTO sf_company_members (company_id,identifier,display_name,role_key,status) VALUES (?,?,?,?,?)', values = { companyId, identifier, Bridge.GetPlayerName(source), 'owner', 'active' } },
        { query = [[INSERT INTO sf_company_ledger
            (id,company_id,idempotency_key,entry_type,direction,amount_cents,balance_after_cents,actor_identifier,linked_kind,linked_id)
            VALUES (?,?,?,?,?,?,?,?,?,?)]], values = { ledgerId, companyId, 'bootstrap:' .. identifier, 'bootstrap', 'credit', treasury, treasury, identifier, 'company', companyId } },
    }
    for role, permissions in pairs(PERMISSIONS) do
        local limit = role == 'procurement' and math.floor(Config.Supplies.ProcurementLimit * 100) or -1
        queries[#queries + 1] = { query = 'INSERT INTO sf_company_roles (company_id,role_key,permissions,transaction_limit_cents) VALUES (?,?,?,?)', values = { companyId, role, encode(permissions), limit } }
    end
    local acquired, result = Lock.With('starter-field-bootstrap', function()
        local starterFieldId, starterQuery = Fields.StarterForBootstrap(companyId, identifier)
        if not starterFieldId then return { ok = false, reason = 'no_starter_field' } end
        queries[#queries + 1] = starterQuery
        local ok, committed = pcall(function() return MySQL.transaction.await(queries) end)
        return { ok = ok and committed == true, reason = ok and committed == true and nil or 'database_error', fieldId = starterFieldId }
    end)
    if not acquired or not result or not result.ok then return false, result and result.reason or 'company_busy' end
    Company.Invalidate(identifier)
    return true, companyId
end

function Company.SetMember(companyId, identifier, displayName, role, status)
    if not PERMISSIONS[role] then return false, 'invalid_role' end
    if role == 'owner' then return false, 'owner_role_reserved' end
    if type(identifier) ~= 'string' or identifier == '' then return false, 'invalid_identifier' end
    local existing = MySQL.single.await('SELECT company_id FROM sf_company_members WHERE identifier=? LIMIT 1', { identifier })
    if existing and existing.company_id ~= companyId then return false, 'already_company_member' end
    MySQL.update.await([[
        INSERT INTO sf_company_members (company_id,identifier,display_name,role_key,status)
        VALUES (?,?,?,?,?) ON DUPLICATE KEY UPDATE display_name=VALUES(display_name),
          role_key=VALUES(role_key),status=VALUES(status)]],
        { companyId, identifier, displayName or identifier, role, status or 'active' })
    Company.Invalidate(identifier)
    return true
end

function Company.RemoveMember(companyId, identifier)
    local acquired, result = Lock.With('member-custody:' .. identifier, function()
        local outstanding = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sf_material_issues
            WHERE company_id=? AND identifier=? AND status IN ('pending','issued')]], { companyId, identifier })) or 0
        local recovering = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sf_supply_outbox
            WHERE company_id=? AND identifier=? AND status IN ('pending','prepared','inventory_done')]], { companyId, identifier })) or 0
        local cargo = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sf_company_cargo
            WHERE company_id=? AND custodian_identifier=? AND status IN ('prepared','carrying','partial_deposit','mismatch')]],
            { companyId, identifier })) or 0
        local work = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sf_work WHERE company_id=?
            AND assignee_identifier=? AND status IN ('assigned','active','awaiting_review','releasing')]],
            { companyId, identifier })) or 0
        if outstanding > 0 or recovering > 0 or cargo > 0 or work > 0 then return false end
        local changed = MySQL.update.await("UPDATE sf_company_members SET status='removed' WHERE company_id=? AND identifier=? AND role_key<>'owner'", { companyId, identifier })
        Company.Invalidate(identifier)
        return tonumber(changed) == 1
    end)
    return acquired and result == true, acquired and 'outstanding_custody' or 'member_busy'
end

function Company.FinalizeItemUse(payload, outboxId)
    local acquired, result = Lock.With('usage:' .. outboxId, function()
        local status = MySQL.scalar.await('SELECT status FROM sf_supply_outbox WHERE id=? LIMIT 1', { outboxId })
        if status == 'completed' then return true end
        if status ~= 'inventory_done' then return false end
        local queries = {{ query = [[UPDATE sf_material_issues
            SET consumed_units=consumed_units+?,uses_spent=uses_spent+1,
              status=IF(consumed_units+returned_units+?>=issued_units,'consumed',status)
            WHERE id=? AND identifier=? AND status='issued']],
            values = { payload.consumed, payload.consumed, payload.issueId, payload.identifier } }}
        if payload.broken then
            queries[#queries + 1] = { query = [[UPDATE sf_warehouse_tool_units
                SET status='consumed',durability=0 WHERE issue_id=? AND status='issued']], values = { payload.issueId } }
        end
        queries[#queries + 1] = { query = "UPDATE sf_supply_outbox SET status='completed',attempts=attempts+1,last_error=NULL WHERE id=? AND status='inventory_done'", values = { outboxId } }
        local ok, committed = pcall(function() return MySQL.transaction.await(queries) end)
        return ok and committed == true
    end)
    return acquired and result == true
end

local function usageRows(companyId, identifier)
    return MySQL.query.await([[SELECT id,payload FROM sf_supply_outbox
        WHERE company_id=? AND identifier=? AND kind='usage' AND status IN ('prepared','inventory_done')
        ORDER BY created_at LIMIT 20]], { companyId, identifier }) or {}
end

function Company.HasPendingItemUse(companyId, identifier, issueId)
    local count = MySQL.scalar.await([[SELECT COUNT(*) FROM sf_supply_outbox
        WHERE company_id=? AND identifier=? AND kind='usage' AND status IN ('prepared','inventory_done')
          AND JSON_UNQUOTE(JSON_EXTRACT(payload,'$.issueId'))=?]], { companyId, identifier, issueId })
    return (tonumber(count) or 0) > 0
end

function Company.ReconcileItemUse(source, companyId, issueId)
    local identifier = Bridge.GetIdentifier(source)
    for _, row in ipairs(usageRows(companyId, identifier)) do
        local ok, payload = pcall(json.decode, row.payload or '{}')
        if ok and type(payload) == 'table' and payload.issueId == issueId then
            Company.FinalizeItemUse(payload, row.id)
        end
    end
end

function Company.CanUseIssuedItem(source, metadata)
    local companyId, issueId = tostring(metadata.companyId or ''), tostring(metadata.issueId or '')
    local member = Company.GetMembership(source, true)
    local temporary = not member and Fields and Fields.CanUseCompanyMaterial
        and Fields.CanUseCompanyMaterial(source, companyId, metadata.itemId)
    if (not member or member.company_id ~= companyId) and not temporary or issueId == '' then return false end
    if Supplies and Supplies.ReconcileOutbox then
        Supplies.ReconcileOutbox(source, member or temporary and {
            company_id = companyId, identifier = Bridge.GetIdentifier(source), temporary_scope = true,
        } or nil)
    else
        Company.ReconcileItemUse(source, companyId, issueId)
    end
    local identifier = Bridge.GetIdentifier(source)
    local status = MySQL.scalar.await([[SELECT status FROM sf_material_issues
        WHERE id=? AND company_id=? AND identifier=? LIMIT 1]], { issueId, companyId, identifier })
    return status == 'issued' and not Company.HasPendingItemUse(companyId, identifier, issueId)
end

function Company.PrepareItemUse(source, metadata, action, resolved, broken)
    local issueId = metadata and tostring(metadata.issueId or '')
    if issueId == '' then return true, nil, nil end
    local identifier = Bridge.GetIdentifier(source)
    local acquired, result = Lock.With('member-custody:' .. identifier, function()
        local member = Company.GetMembership(source, true)
        local companyId = tostring(metadata.companyId or '')
        local temporary = not member and Fields and Fields.CanUseCompanyMaterial
            and Fields.CanUseCompanyMaterial(source, companyId, metadata.itemId)
        if (not member or member.status ~= 'active' or member.company_id ~= companyId) and not temporary then
            return { ok = false }
        end
        local issueStatus = MySQL.scalar.await([[SELECT status FROM sf_material_issues
            WHERE id=? AND company_id=? AND identifier=? LIMIT 1]], { issueId, companyId, identifier })
        if issueStatus ~= 'issued' then return { ok = false } end
        if Company.HasPendingItemUse(companyId, identifier, issueId) then return { ok = false } end

        local item = Sonar.ItemCatalog.byId[tostring(metadata.itemId or '')]
        local payload = { issueId = issueId, identifier = identifier,
            companyId = companyId, itemId = tostring(metadata.itemId), action = action,
            slot = resolved.slot, beforeCount = resolved.count, beforeDurability = resolved.durability,
            preparedAt = Sonar.Time.Now(),
            beforeIssueCount = Bridge.Inventory.GetItemCount(source, tostring(metadata.itemId), { issueId = issueId }),
            consumed = item and (item.consumable or broken == true) and 1 or 0, broken = broken == true }
        local outboxId, operationId = Sonar.Utils.Uuid(), Sonar.Utils.Uuid()
        local ok, err = pcall(function()
            MySQL.insert.await([[INSERT INTO sf_supply_outbox
                (id,company_id,identifier,kind,idempotency_key,status,payload) VALUES (?,?,?,?,?,?,?)]],
                { outboxId, companyId, identifier, 'usage', operationId, 'prepared', json.encode(payload) })
        end)
        if not ok then
            Logger.Warn(('Custody usage reservation failed for issue %s: %s'):format(issueId, tostring(err)), 'company')
        end
        return { ok = ok, id = ok and outboxId or nil, payload = ok and payload or nil }
    end)
    if not acquired or not result then return false, nil, nil end
    return result.ok, result.id, result.payload
end

function Company.CancelItemUse(outboxId)
    if outboxId then MySQL.update.await("UPDATE sf_supply_outbox SET status='failed',last_error='inventory_mutation_failed' WHERE id=? AND status='prepared'", { outboxId }) end
end

function Company.RecordItemUse(source, metadata, action, broken, outboxId, preparedPayload)
    if not outboxId then return true end
    local marked = MySQL.update.await("UPDATE sf_supply_outbox SET status='inventory_done' WHERE id=? AND identifier=? AND status='prepared'",
        { outboxId, Bridge.GetIdentifier(source) })
    if tonumber(marked) ~= 1 then return false end
    local payload = preparedPayload
    local ok = type(payload) == 'table'
    if not ok then
        local row = MySQL.single.await('SELECT payload FROM sf_supply_outbox WHERE id=? LIMIT 1', { outboxId })
        ok, payload = pcall(json.decode, row and row.payload or '{}')
    end
    return ok and type(payload) == 'table' and Company.FinalizeItemUse(payload, outboxId)
end

function Company.SourceForIdentifier(identifier)
    local player = Bridge.GetPlayerByIdentifier(identifier)
    return player and player.PlayerData and player.PlayerData.source or nil
end

local function allowedCommand(source)
    return source == 0 or IsPlayerAceAllowed(source, Config.Supplies.Ace)
end

RegisterCommand('farmcompany', function(source, args)
    if not allowedCommand(source) then return Bridge.Notify(source, 'Company administration is not permitted.', 'error') end
    local command = tostring(args[1] or ''):lower()
    if command == 'bootstrap' then
        if source == 0 then return print('[sonar_farm] bootstrap must be run by the future Owner in game.') end
        local ok, value = Company.Bootstrap(source, table.concat(args, ' ', 2))
        return Bridge.Notify(source, ok and ('Company ready: ' .. value) or ('Company bootstrap failed: ' .. value), ok and 'success' or 'error')
    end
    local actor = source > 0 and Company.GetMembership(source, true) or nil
    local companyId = actor and actor.company_id or tostring(args[2] or '')
    if command == 'member' and companyId ~= '' then
        local identifier = tostring(args[actor and 2 or 3] or '')
        local role = tostring(args[actor and 3 or 4] or ''):lower()
        local ok, reason = Company.SetMember(companyId, identifier, identifier, role, 'active')
        if source > 0 then Bridge.Notify(source, ok and 'Company membership updated.' or ('Membership failed: ' .. reason), ok and 'success' or 'error') end
        return
    end
    if command == 'remove' and companyId ~= '' then
        local identifier = tostring(args[actor and 2 or 3] or '')
        local ok = Company.RemoveMember(companyId, identifier)
        if source > 0 then
            return Bridge.Notify(source, ok and 'Company member removed.' or 'Member could not be removed.', ok and 'success' or 'error')
        end
        return print(ok and '[sonar_farm] Company member removed.' or '[sonar_farm] Member could not be removed.')
    end
    if source > 0 then Bridge.Notify(source, 'Usage: /farmcompany bootstrap <name> | member <identifier> <role> | remove <identifier>', 'inform') end
end, false)
