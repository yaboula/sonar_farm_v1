-- Authoritative Fields, Land, Work and produce runtime.

Fields = Fields or {}

local active = {}
local byLegacyZone = {}
local byCell = {}
local subscribers = {}

local function decode(value, fallback)
    if type(value) == 'table' then return value end
    local ok, result = pcall(json.decode, value or '')
    return ok and type(result) == 'table' and result or (fallback or {})
end

local function encode(value) return json.encode(value or {}) end
local function cents(value) return math.floor((tonumber(value) or 0) * 100 + 0.5) end
local function dollars(value) return math.floor((tonumber(value) or 0) + 0.5) / 100 end
local function iso(value) return os.date('!%Y-%m-%dT%H:%M:%SZ', tonumber(value) or Sonar.Time.Now()) end
local function contains(list, wanted)
    for _, value in ipairs(list or {}) do if value == wanted then return true end end
    return false
end

local function fieldCell(x, y)
    return ('%d:%d'):format(math.floor(x / Sonar.Constants.SPATIAL_CELL_SIZE),
        math.floor(y / Sonar.Constants.SPATIAL_CELL_SIZE))
end

local function nextReference(prefix)
    return ('%s-%s'):format(prefix, Sonar.Utils.Uuid():sub(1, 8):upper())
end

local function insertRevisionQueries(field, revisionId, revisionNumber, status, createdBy)
    local queries = {{ query = [[INSERT INTO sf_field_revisions
        (id,field_id,revision_number,checksum,status,orientation,bounds_width,bounds_height,created_by,activated_at)
        VALUES (?,?,?,?,?,?,?,?,?,IF(?='active',CURRENT_TIMESTAMP,NULL))]],
        values = { revisionId, field.id, revisionNumber, field.checksum, status, field.orientation,
            field.bounds.width, field.bounds.height, createdBy, status } }}
    for _, row in ipairs(field.rows) do
        queries[#queries + 1] = { query = [[INSERT INTO sf_field_rows
            (revision_id,field_id,id,label,row_order) VALUES (?,?,?,?,?)]],
            values = { revisionId, field.id, row.id, row.label, row.order } }
    end
    for _, slot in ipairs(field.slots) do
        queries[#queries + 1] = { query = [[INSERT INTO sf_field_slots
            (revision_id,field_id,row_id,id,slot_order,legacy_index,pos_x,pos_y,pos_z,heading,normalized_x,normalized_y,cell_key)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)]], values = { revisionId, field.id, slot.rowId, slot.id,
            slot.order, slot.legacyIndex, slot.x, slot.y, slot.z, slot.heading,
            slot.position.x, slot.position.y, fieldCell(slot.x, slot.y) } }
    end
    return queries
end

function Fields.IsEnabled() return Config.Features.Fields == true end
function Fields.IsAuthorityEnabled()
    return Config.Features.Fields == true and Config.Features.CompanyFieldAuthority == true
        and Config.Features.Work == true and Config.Features.CompanyCargo == true
end

function Fields.ActorContext(source)
    local member = Company.GetMembership(source, true)
    if member then return member end
    local identifier = Bridge.GetIdentifier(source)
    if Config.Features.PublicContracts and identifier then
        local work = MySQL.single.await([[SELECT w.company_id,c.name company_name FROM sf_work w
            JOIN sf_companies c ON c.id=w.company_id WHERE w.kind='contract' AND w.assignee_identifier=?
            AND w.status IN ('active','awaiting_review') AND w.deadline_at>? ORDER BY w.deadline_at LIMIT 1]],
            { identifier, Sonar.Time.Now() })
        if work then return { company_id = work.company_id, company_name = work.company_name,
            identifier = identifier, role_key = 'contractor', status = 'active', temporary_scope = true, permissionMap = {
                ['fields.view_assigned'] = true, ['fields.route'] = true, ['work.view_own'] = true,
                ['contracts.browse'] = true, ['cargo.view_own'] = true, ['cargo.deposit'] = true,
                ['warehouse.view'] = true, ['warehouse.withdraw'] = true, ['warehouse.return'] = true,
            }, permissionList = {} } end
    end
    if Config.Features.CompanyCargo and identifier then
        local cargo = MySQL.single.await([[SELECT cargo.company_id,c.name company_name FROM sf_company_cargo cargo
            JOIN sf_companies c ON c.id=cargo.company_id WHERE cargo.custodian_identifier=?
            AND cargo.status IN ('prepared','carrying','partial_deposit','mismatch') ORDER BY cargo.created_at LIMIT 1]],
            { identifier })
        if cargo then return { company_id = cargo.company_id, company_name = cargo.company_name,
            identifier = identifier, role_key = 'contractor', status = 'cargo_custodian', permissionMap = {
                ['cargo.view_own'] = true, ['cargo.deposit'] = true,
            }, permissionList = {} } end
    end
    if Config.Features.PublicContracts then return { identifier = identifier, role_key = 'visitor', status = 'public',
        permissionMap = { ['contracts.browse'] = true }, permissionList = {} } end
    return nil
end

function Fields.CanUseCompanyMaterial(source, companyId, itemId)
    if not Config.Features.Work and not Config.Features.PublicContracts then return false, 0 end
    local identifier = Bridge.GetIdentifier(source)
    local item = itemId and Sonar.ItemCatalog.byId[tostring(itemId)] or nil
    local effect = item and (item.tool or item.consumable) or nil
    local action = effect and effect.action or nil
    if not identifier or not action then return false, 0 end
    local requirements = MySQL.query.await([[SELECT r.item_tier,r.target_count,r.current_count FROM sf_work w
        JOIN sf_work_requirements r ON r.work_id=w.id
        WHERE w.company_id=? AND w.assignee_identifier=? AND w.status='active' AND w.deadline_at>?
          AND r.action=? AND r.current_count<r.target_count]],
        { companyId, identifier, Sonar.Time.Now(), action }) or {}
    local actualRank = Sonar.ItemCatalog.tiers[item.tier] or 0
    local allowance = 0
    for _, requirement in ipairs(requirements) do
        local requiredTier = tostring(requirement.item_tier or '')
        if requiredTier == '' or actualRank >= (Sonar.ItemCatalog.tiers[requiredTier] or math.huge) then
            allowance = allowance + math.max(0, tonumber(requirement.target_count) - tonumber(requirement.current_count))
        end
    end
    return allowance > 0, allowance
end

function Fields.ImportSeeds()
    local seeds, errors = Sonar.Fields.CompileSeeds()
    if #errors > 0 then
        for _, message in ipairs(errors) do Logger.Warn(message, 'fields') end
        return false
    end
    for _, field in ipairs(seeds) do
        local existing = MySQL.single.await([[SELECT f.id,f.active_revision_id,
            COALESCE(MAX(r.revision_number),0) revision_number,
            MAX(CASE WHEN r.checksum=? THEN 1 ELSE 0 END) checksum_exists
            FROM sf_fields f LEFT JOIN sf_field_revisions r ON r.field_id=f.id
            WHERE f.id=? GROUP BY f.id,f.active_revision_id]], { field.checksum, field.id })
        if not existing then
            local revisionId = Sonar.Utils.Uuid()
            local queries = {{ query = [[INSERT INTO sf_fields
                (id,legacy_zone,name,location,catalog_visible,starter_eligible,starter_priority,purchase_price_cents,
                 active_revision_id,access_x,access_y,access_z,allowed_crops,blip)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)]], values = { field.id, field.legacyZone or '', field.name,
                field.location or field.name, field.catalogVisible and 1 or 0, field.starterEligible and 1 or 0,
                field.starterPriority, cents(field.purchasePrice), revisionId, field.access.x, field.access.y,
                field.access.z, encode(field.allowedCrops), encode(field.blip) } }}
            local revisionQueries = insertRevisionQueries(field, revisionId, 1, 'active', 'seed')
            for _, query in ipairs(revisionQueries) do queries[#queries + 1] = query end
            local ok = MySQL.transaction.await(queries)
            if not ok then return false end
        else
            MySQL.update.await([[UPDATE sf_fields SET legacy_zone=NULLIF(?,''),name=?,location=?,catalog_visible=?,
                starter_eligible=?,starter_priority=?,purchase_price_cents=?,access_x=?,access_y=?,access_z=?,
                allowed_crops=?,blip=? WHERE id=?]], { field.legacyZone or '', field.name, field.location or field.name,
                field.catalogVisible and 1 or 0, field.starterEligible and 1 or 0, field.starterPriority,
                cents(field.purchasePrice), field.access.x, field.access.y, field.access.z,
                encode(field.allowedCrops), encode(field.blip), field.id })
            if tonumber(existing.checksum_exists) == 0 then
                local queries = insertRevisionQueries(field, Sonar.Utils.Uuid(),
                    (tonumber(existing.revision_number) or 0) + 1, 'draft', 'seed')
                if not MySQL.transaction.await(queries) then return false end
                Logger.Info(('Imported changed topology for %s as a draft revision.'):format(field.id), 'fields')
            end
        end
    end
    return true
end

function Fields.Reload()
    active, byLegacyZone, byCell = {}, {}, {}
    local fields = MySQL.query.await([[SELECT f.*,r.revision_number,r.checksum,r.orientation,r.bounds_width,r.bounds_height
        FROM sf_fields f JOIN sf_field_revisions r ON r.id=f.active_revision_id WHERE r.status='active']]) or {}
    for _, row in ipairs(fields) do
        local field = { id = row.id, legacyZone = row.legacy_zone, name = row.name, location = row.location,
            catalogVisible = tonumber(row.catalog_visible) == 1, starterEligible = tonumber(row.starter_eligible) == 1,
            starterPriority = tonumber(row.starter_priority), purchasePrice = dollars(row.purchase_price_cents),
            revisionId = row.active_revision_id, topologyRevision = tostring(row.revision_number) .. ':' .. tostring(row.checksum),
            orientation = tonumber(row.orientation), bounds = { width = tonumber(row.bounds_width), height = tonumber(row.bounds_height) },
            access = { x = tonumber(row.access_x), y = tonumber(row.access_y), z = tonumber(row.access_z) },
            allowedCrops = decode(row.allowed_crops), blip = decode(row.blip), sequence = tonumber(row.state_sequence) or 0,
            rows = {}, slots = {}, rowMap = {}, slotMap = {}, legacySlots = {} }
        for _, dbRow in ipairs(MySQL.query.await([[SELECT id,label,row_order FROM sf_field_rows
            WHERE revision_id=? ORDER BY row_order]], { field.revisionId }) or {}) do
            local value = { id = dbRow.id, label = dbRow.label, order = tonumber(dbRow.row_order), slotIds = {} }
            field.rows[#field.rows + 1], field.rowMap[value.id] = value, value
        end
        for _, dbSlot in ipairs(MySQL.query.await([[SELECT * FROM sf_field_slots
            WHERE revision_id=? ORDER BY legacy_index]], { field.revisionId }) or {}) do
            local value = { id = dbSlot.id, rowId = dbSlot.row_id, order = tonumber(dbSlot.slot_order),
                legacyIndex = tonumber(dbSlot.legacy_index), index = tonumber(dbSlot.legacy_index),
                zone = field.legacyZone or field.id, fieldId = field.id, revisionId = field.revisionId,
                x = tonumber(dbSlot.pos_x), y = tonumber(dbSlot.pos_y), z = tonumber(dbSlot.pos_z),
                heading = tonumber(dbSlot.heading), cell = dbSlot.cell_key,
                position = { x = tonumber(dbSlot.normalized_x), y = tonumber(dbSlot.normalized_y) } }
            field.slots[#field.slots + 1], field.slotMap[value.id], field.legacySlots[value.legacyIndex] = value, value, value
            local parent = field.rowMap[value.rowId]
            if parent then parent.slotIds[#parent.slotIds + 1] = value.id end
            byCell[value.cell] = byCell[value.cell] or {}
            byCell[value.cell][field.id] = field
        end
        active[field.id] = field
        if field.legacyZone then byLegacyZone[field.legacyZone] = field end
    end
    return true
end

function Fields.Init()
    if not FieldsDatabase.Init() then return false end
    if not Fields.ImportSeeds() then return false end
    for _, company in ipairs(MySQL.query.await([[SELECT c.id,c.owner_identifier FROM sf_companies c
        LEFT JOIN sf_company_fields cf ON cf.company_id=c.id WHERE cf.company_id IS NULL
        ORDER BY c.created_at]]) or {}) do
        local fieldId, query = Fields.StarterForBootstrap(company.id, company.owner_identifier)
        if not fieldId or not MySQL.transaction.await({ query }) then
            Logger.Warn(('Company %s has no Field and no Starter Field is available.'):format(company.id), 'fields')
        else
            Logger.Info(('Assigned Starter Field %s to existing Company %s.'):format(fieldId, company.id), 'fields')
        end
    end
    return Fields.Reload()
end

function Fields.Get(fieldId) return active[fieldId] end
function Fields.ByLegacyZone(zone) return byLegacyZone[zone] end
function Fields.ResolveLegacySlot(zone, index)
    local field = byLegacyZone[zone]
    return field and field.legacySlots[tonumber(index)] or nil
end

function Fields.TopologiesForCells(cellKeys)
    local seen, output = {}, {}
    for _, cell in ipairs(cellKeys or {}) do
        for fieldId, field in pairs(byCell[cell] or {}) do
            if not seen[fieldId] then
                seen[fieldId] = true
                local slots = {}
                for _, slot in ipairs(field.slots) do slots[#slots + 1] = {
                    id = slot.id, rowId = slot.rowId, index = slot.legacyIndex, zone = slot.zone,
                    fieldId = field.id, revisionId = field.revisionId, x = slot.x, y = slot.y, z = slot.z,
                    heading = slot.heading,
                } end
                output[#output + 1] = { id = field.id, revisionId = field.revisionId,
                    topologyRevision = field.topologyRevision, slots = slots, blip = field.blip,
                    name = field.name, access = field.access }
            end
        end
    end
    return output
end

function Fields.StarterForBootstrap(companyId, identifier)
    local field = MySQL.single.await([[SELECT f.id FROM sf_fields f
        LEFT JOIN sf_company_fields cf ON cf.field_id=f.id
        WHERE f.starter_eligible=1 AND f.active_revision_id IS NOT NULL AND cf.field_id IS NULL
          AND NOT EXISTS (SELECT 1 FROM farming_crops crop WHERE crop.zone=f.legacy_zone)
        ORDER BY f.starter_priority,f.id LIMIT 1]])
    if not field then return nil end
    return field.id, { query = [[INSERT INTO sf_company_fields
        (field_id,company_id,acquisition_kind,price_cents,acquired_by) VALUES (?,?,'starter',0,?)]],
        values = { field.id, companyId, identifier } }
end

local function membership(source, permission)
    local allowed, member = Company.HasPermission(source, permission, true)
    return allowed and member or nil
end

local function owns(companyId, fieldId)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM sf_company_fields WHERE company_id=? AND field_id=?',
        { companyId, fieldId })) == 1
end

function Fields.PreparePurchase(source, fieldId)
    if not Config.Features.Fields then return { ok = false, reason = 'unavailable' } end
    local member = membership(source, 'fields.acquire')
    local field = active[tostring(fieldId or '')]
    if not member or not field or not field.catalogVisible or field.purchasePrice <= 0 then
        return { ok = false, reason = member and 'field_unavailable' or 'permission_denied' }
    end
    if MySQL.scalar.await('SELECT field_id FROM sf_company_fields WHERE field_id=? LIMIT 1', { field.id }) then
        return { ok = false, reason = 'field_owned' }
    end
    local expiresAt = Sonar.Time.Now() + Config.Fields.PurchaseDraftTtlSeconds
    local changed = MySQL.update.await([[INSERT INTO sf_field_purchase_drafts
        (field_id,company_id,prepared_by,status,expires_at) VALUES (?,?,?,'prepared',?)
        ON DUPLICATE KEY UPDATE prepared_by=VALUES(prepared_by),status='prepared',expires_at=VALUES(expires_at)]],
        { field.id, member.company_id, member.identifier, expiresAt })
    local draft = MySQL.single.await([[SELECT company_id,expires_at FROM sf_field_purchase_drafts
        WHERE field_id=? AND status='prepared' LIMIT 1]], { field.id })
    if not changed or not draft or draft.company_id ~= member.company_id then
        return { ok = false, reason = 'field_purchase_reserved' }
    end
    return { ok = true, changed = true, entityId = field.id,
        message = 'Purchase prepared. The Owner must confirm at the Office Terminal.', invalidated = { 'land' } }
end

function Fields.Purchase(source, fieldId, operationId)
    if not Config.Features.Fields then return { ok = false, reason = 'unavailable' } end
    local member = membership(source, 'fields.acquire')
    if not member or member.role_key ~= 'owner' then return { ok = false, reason = 'permission_denied', message = 'Only the Owner can confirm a Field purchase.' } end
    local field = active[tostring(fieldId or '')]
    if not field or not field.catalogVisible or field.purchasePrice <= 0 then return { ok = false, reason = 'field_unavailable' } end
    operationId = tostring(operationId or '')
    if operationId == '' or #operationId > 100 then return { ok = false, reason = 'invalid_operation' } end
    -- A single financial lock also serializes supplier orders and funded Work,
    -- keeping Treasury and Ledger balance_after values consistent across modules.
    local acquired, result = Lock.With('company-finance', function()
        local replay = MySQL.single.await([[SELECT linked_id FROM sf_company_ledger
            WHERE company_id=? AND idempotency_key=? AND entry_type='field_purchase' LIMIT 1]],
            { member.company_id, 'field-purchase:' .. operationId })
        if replay then
            return replay.linked_id == field.id
                and { ok = true, changed = false, entityId = field.id, message = 'Field purchase already completed.' }
                or { ok = false, reason = 'operation_conflict' }
        end
        if MySQL.scalar.await('SELECT field_id FROM sf_company_fields WHERE field_id=? LIMIT 1', { field.id }) then
            return { ok = false, reason = 'field_owned' }
        end
        local draft = MySQL.single.await([[SELECT prepared_by,expires_at FROM sf_field_purchase_drafts
            WHERE field_id=? AND company_id=? AND status='prepared' AND expires_at>? LIMIT 1]],
            { field.id, member.company_id, Sonar.Time.Now() })
        if not draft then
            return { ok = false, reason = 'purchase_not_prepared', message = 'Prepare this acquisition before Owner confirmation.' }
        end
        for _, record in pairs(State.All()) do
            local data = record.data or {}
            if data.fieldId == field.id or (not data.fieldId and record.zone == field.legacyZone) then
                return { ok = false, reason = 'field_occupied', message = 'Legacy crops must be cleared before acquisition.' }
            end
        end
        local price, ledgerId = cents(field.purchasePrice), Sonar.Utils.Uuid()
        local company = MySQL.single.await('SELECT treasury_cents FROM sf_companies WHERE id=? LIMIT 1', { member.company_id })
        if not company or tonumber(company.treasury_cents) < price then return { ok = false, reason = 'treasury_insufficient' } end
        local balance = tonumber(company.treasury_cents) - price
        local queries = {
            { query = 'UPDATE sf_companies SET treasury_cents=treasury_cents-? WHERE id=? AND treasury_cents>=?', values = { price, member.company_id, price } },
            { query = [[INSERT INTO sf_company_fields
                (field_id,company_id,acquisition_kind,price_cents,acquired_by,ledger_id) VALUES (?,?,'purchase',?,?,?)]],
                values = { field.id, member.company_id, price, member.identifier, ledgerId } },
            { query = [[INSERT INTO sf_company_ledger
                (id,company_id,idempotency_key,entry_type,direction,amount_cents,balance_after_cents,actor_identifier,linked_kind,linked_id)
                VALUES (?,?,?,?,?,?,?,?,?,?)]], values = { ledgerId, member.company_id, 'field-purchase:' .. operationId,
                'field_purchase', 'debit', price, balance, member.identifier, 'field', field.id } },
            { query = "UPDATE sf_field_purchase_drafts SET status='completed' WHERE field_id=? AND company_id=? AND status='prepared'",
                values = { field.id, member.company_id } },
        }
        local ok, committed = pcall(function() return MySQL.transaction.await(queries) end)
        if not ok or committed ~= true then return { ok = false, reason = 'database_error' } end
        Company.Invalidate(member.identifier)
        return { ok = true, changed = true, entityId = field.id, message = field.name .. ' is now a permanent Company asset.', invalidated = { 'fields', 'land', 'treasury', 'ledger' } }
    end)
    return acquired and result or { ok = false, reason = 'already_in_progress' }
end

function Fields.CanActivateRevision(fieldId)
    local field = active[fieldId]
    if not field then
        local exists = MySQL.scalar.await('SELECT id FROM sf_fields WHERE id=? LIMIT 1', { fieldId })
        if not exists then return false, 'unknown_field' end
        field = { id = fieldId }
    end
    for _, record in pairs(State.All()) do
        local data = record.data or {}
        if data.fieldId == fieldId or (field.legacyZone and not data.fieldId and record.zone == field.legacyZone) then return false, 'field_has_crops' end
    end
    local planCount = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sf_crop_plans
        WHERE field_id=? AND status IN ('draft','reserved','in_execution')]], { fieldId })) or 0
    local workCount = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sf_work
        WHERE field_id=? AND status IN ('assigned','published','reserved','active','awaiting_review','approved','releasing')]], { fieldId })) or 0
    local cargoCount = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sf_company_cargo
        WHERE field_id=? AND status IN ('prepared','carrying','partial_deposit')]], { fieldId })) or 0
    if planCount > 0 then return false, 'field_has_plans' end
    if workCount > 0 then return false, 'field_has_work' end
    if cargoCount > 0 then return false, 'field_has_cargo' end
    return true
end

function Fields.ActivateRevision(source, fieldId, revisionId)
    if source ~= 0 and not IsPlayerAceAllowed(source, Config.Fields.Ace) then return false, 'permission_denied' end
    local acquired, result = Lock.With('field-revision:' .. tostring(fieldId), function()
        local free, reason = Fields.CanActivateRevision(fieldId)
        if not free then return { ok = false, reason = reason } end
        local revision = MySQL.single.await("SELECT id FROM sf_field_revisions WHERE id=? AND field_id=? AND status='draft' LIMIT 1", { revisionId, fieldId })
        if not revision then return { ok = false, reason = 'revision_unavailable' } end
        local queries = {
            { query = "UPDATE sf_field_revisions SET status='archived' WHERE field_id=? AND status='active'", values = { fieldId } },
            { query = "UPDATE sf_field_revisions SET status='active',activated_at=CURRENT_TIMESTAMP WHERE id=? AND status='draft'", values = { revisionId } },
            { query = 'UPDATE sf_fields SET active_revision_id=?,state_sequence=state_sequence+1 WHERE id=?', values = { revisionId, fieldId } },
        }
        if not MySQL.transaction.await(queries) then return { ok = false, reason = 'database_error' } end
        Fields.Reload()
        Fields.BroadcastInvalidate(fieldId, 'topology_changed')
        return { ok = true }
    end)
    if not acquired then return false, 'already_in_progress' end
    return result.ok, result.reason
end

function Fields.SaveDraft(source, definition)
    if source ~= 0 and (not Config.Debug or not IsPlayerAceAllowed(source, Config.Fields.Ace)) then return nil, 'permission_denied' end
    local field, errors = Sonar.Fields.Compile(definition)
    if not field then return nil, table.concat(errors, '; ') end
    local minimum = Config.Fields.MinimumSlotSpacing
    for _, candidate in ipairs(field.slots) do
        for activeId, existing in pairs(active) do
            if activeId ~= field.id then
                for _, slot in ipairs(existing.slots) do
                    if Sonar.Utils.Distance(candidate, slot) < minimum then return nil, 'topology_overlaps_' .. activeId end
                end
            end
        end
    end
    local existing = MySQL.single.await([[SELECT f.id,COALESCE(MAX(r.revision_number),0) revision_number,
        MAX(CASE WHEN r.checksum=? THEN 1 ELSE 0 END) checksum_exists FROM sf_fields f
        LEFT JOIN sf_field_revisions r ON r.field_id=f.id WHERE f.id=? GROUP BY f.id]], { field.checksum, field.id })
    if existing and tonumber(existing.checksum_exists) == 1 then return field.id, 'unchanged' end
    local revisionId, queries = Sonar.Utils.Uuid(), {}
    if not existing then queries[#queries + 1] = { query = [[INSERT INTO sf_fields
        (id,legacy_zone,name,location,catalog_visible,starter_eligible,starter_priority,purchase_price_cents,
         active_revision_id,access_x,access_y,access_z,allowed_crops,blip) VALUES (?,?,?,?,?,?,?,?,NULL,?,?,?,?,?)]],
        values = { field.id, field.legacyZone or '', field.name, field.location or field.name,
            field.catalogVisible and 1 or 0, field.starterEligible and 1 or 0, field.starterPriority,
            cents(field.purchasePrice), field.access.x, field.access.y, field.access.z,
            encode(field.allowedCrops), encode(field.blip) } }
    end
    local revisionQueries = insertRevisionQueries(field, revisionId,
        existing and tonumber(existing.revision_number) + 1 or 1, 'draft', Bridge.GetIdentifier(source) or 'console')
    for _, query in ipairs(revisionQueries) do queries[#queries + 1] = query end
    local ok, committed = pcall(function() return MySQL.transaction.await(queries) end)
    return ok and committed == true and revisionId or nil, ok and committed == true and 'draft_saved' or 'database_error'
end

lib.callback.register(Sonar.Constants.CALLBACKS.FIELD_DRAFT_SAVE, function(source, definition)
    local revisionId, reason = Fields.SaveDraft(source, definition)
    return { ok = revisionId ~= nil, revisionId = revisionId, reason = reason }
end)

local function recordsForField(field)
    local output = {}
    for _, record in pairs(State.All()) do
        local data = record.data or {}
        if data.fieldId == field.id or (not data.fieldId and record.zone == field.legacyZone) then output[#output + 1] = record end
    end
    return output
end

local function planRows(planId)
    local output = {}
    for _, row in ipairs(MySQL.query.await('SELECT row_id FROM sf_crop_plan_rows WHERE plan_id=? ORDER BY row_id', { planId }) or {}) do
        output[#output + 1] = row.row_id
    end
    return output
end

-- nil means portfolio-wide access; a table means exact Work-scoped Rows.
local function actorFieldScopes(source, actor)
    if actor.permissionMap and actor.permissionMap['fields.view_portfolio'] then return nil end
    local scopes, identifier = {}, actor.identifier or Bridge.GetIdentifier(source)
    for _, work in ipairs(MySQL.query.await([[SELECT field_id,plan_id FROM sf_work
        WHERE assignee_identifier=? AND company_id=? AND status IN ('assigned','active') AND deadline_at>?]],
        { identifier, actor.company_id, Sonar.Time.Now() }) or {}) do
        scopes[work.field_id] = scopes[work.field_id] or {}
        for _, rowId in ipairs(planRows(work.plan_id)) do scopes[work.field_id][rowId] = true end
    end
    return scopes
end

local function loadPlans(fieldId)
    local output = {}
    for _, row in ipairs(MySQL.query.await([[SELECT * FROM sf_crop_plans WHERE field_id=?
        AND status<>'cancelled' ORDER BY created_at DESC]], { fieldId }) or {}) do
        local rows = planRows(row.id)
        local field, eligible, excluded = active[fieldId], 0, {}
        local occupied = {}
        if field then
            for _, record in ipairs(recordsForField(field)) do
                local slotId = record.data and record.data.slotId
                if slotId then occupied[slotId] = true end
            end
            for _, rowId in ipairs(rows) do
                for _, slotId in ipairs(field.rowMap[rowId] and field.rowMap[rowId].slotIds or {}) do
                    if occupied[slotId] then excluded[#excluded + 1] = { slotId = slotId, reason = 'Occupied' }
                    else eligible = eligible + 1 end
                end
            end
        end
        output[#output + 1] = { id = row.id, reference = row.reference, fieldId = row.field_id, rowIds = rows,
            crop = row.crop_type, cropLabel = Config.Crops[row.crop_type] and Config.Crops[row.crop_type].label or row.crop_type,
            status = row.status, statusLabel = row.status:gsub('_', ' '), eligibleSlots = eligible, excludedSlots = excluded,
            materialEstimate = { ('Seeds ×%d'):format(eligible), ('Initial water ×%d'):format(eligible) },
            linkedAssignmentId = row.linked_work_id, createdAt = iso(os.time()), updatedAt = iso(os.time()) }
    end
    return output
end

local function cropStage(record, condition)
    local def = Config.Crops[record.crop_type]
    if condition.state == Sonar.Constants.CROP_STATE.DEAD then return 'Dead' end
    if condition.progress >= 1 then return 'Mature' end
    for _, stage in ipairs(def and def.stages or {}) do
        local threshold = tonumber(stage.at or stage.threshold or stage.progress)
        if threshold and condition.progress >= threshold then return stage.label or stage.name or 'Growing' end
    end
    return 'Growing'
end

local function plantState(record, now)
    local condition = Physiology.Evaluate(record, now)
    local data, readyAt = record.data or {}, nil
    if condition.progress < 1 and condition.progress > 0 then
        readyAt = now + math.max(0, record.growth_time * (1 - condition.progress))
    elseif condition.progress >= 1 then readyAt = data.maturedAt or now end
    return { id = record.id, crop = record.crop_type,
        cropLabel = Config.Crops[record.crop_type] and Config.Crops[record.crop_type].label or record.crop_type,
        stage = cropStage(record, condition), progress = Sonar.Utils.Round(condition.progress * 100, 1),
        water = Sonar.Utils.Round(condition.water or 0, 1), health = Sonar.Utils.Round(condition.health or 0, 1),
        spoilage = Sonar.Utils.Round(condition.spoilage or 0, 1), plantedAt = iso(record.planted_at),
        maturesAt = readyAt and iso(readyAt) or '', lastCareAt = iso(data.lastCare or record.planted_at),
        readiness = condition.progress >= 1 and ((condition.spoilage or 0) > 50 and 'at_risk' or 'ready') or 'growing',
        condition = condition }
end

local function fieldOwnership(fieldId, companyId)
    return MySQL.single.await([[SELECT acquisition_kind,price_cents,acquired_at FROM sf_company_fields
        WHERE field_id=? AND company_id=? LIMIT 1]], { fieldId, companyId })
end

local function fieldOverview(field, member, holding, now, permittedRows)
    local crops, attention, critical, ready, cropCounts = recordsForField(field), 0, 0, 0, {}
    local water, health, growth = 0, 0, 0
    for _, record in ipairs(crops) do
        local rowId = record.data and record.data.rowId
        if not permittedRows or permittedRows[rowId] then
            local plant = plantState(record, now)
            water, health, growth = water + plant.water, health + plant.health, growth + plant.progress
            cropCounts[plant.cropLabel] = (cropCounts[plant.cropLabel] or 0) + 1
            if plant.health <= 35 or plant.water <= 20 then critical = critical + 1
            elseif plant.health < 70 or plant.water < 60 then attention = attention + 1 end
            if plant.readiness ~= 'growing' then ready = ready + 1 end
        end
    end
    if permittedRows then
        local filtered = {}
        for _, record in ipairs(crops) do if permittedRows[record.data and record.data.rowId] then filtered[#filtered + 1] = record end end
        crops = filtered
    end
    local summaries = {}
    for label, count in pairs(cropCounts) do summaries[#summaries + 1] = label .. ' ×' .. count end
    table.sort(summaries)
    local plans = loadPlans(field.id)
    local planned = 0
    for _, plan in ipairs(plans) do
        if not permittedRows then planned = planned + plan.eligibleSlots
        else for _, rowId in ipairs(plan.rowIds) do if permittedRows[rowId] then
            planned = planned + #(field.rowMap[rowId] and field.rowMap[rowId].slotIds or {})
        end end end
    end
    local capacity = #field.slots
    if permittedRows then
        capacity = 0
        for rowId in pairs(permittedRows) do capacity = capacity + #(field.rowMap[rowId] and field.rowMap[rowId].slotIds or {}) end
    end
    local status = critical > 0 and 'attention' or ready > 0 and 'ready' or #crops > 0 and 'active' or planned > 0 and 'attention' or 'empty'
    return { id = field.id, name = field.name, location = field.location, status = status,
        statusLabel = status:gsub('_', ' '), ownership = holding.acquisition_kind == 'starter' and 'Permanent starter Field' or 'Company-owned',
        occupied = #crops, planned = planned, capacity = capacity,
        cropSummary = #summaries > 0 and table.concat(summaries, ' · ') or 'No active crops',
        attentionCount = attention, criticalCount = critical,
        activeAssignments = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sf_work WHERE field_id=?
            AND status IN ('assigned','published','reserved','active','awaiting_review')]], { field.id })) or 0,
        nextMilestone = ready > 0 and (ready .. ' ready to harvest') or #crops > 0 and 'Crop cycle in progress' or 'Ready for planning',
        yieldForecast = #crops > 0 and ('%d active plants'):format(#crops) or nil,
        averages = #crops > 0 and { water = water / #crops, health = health / #crops, growth = growth / #crops } or nil }
end

function Fields.LoadOverview(source)
    if not Config.Features.Fields then return nil, 'unavailable' end
    local member = Fields.ActorContext(source)
    if not member or not (member.permissionMap['fields.view_portfolio'] or member.permissionMap['fields.view_assigned']) then
        return nil, 'permission_denied'
    end
    local scopes = actorFieldScopes(source, member)
    local output, now = {}, Sonar.Time.Now()
    for _, row in ipairs(MySQL.query.await([[SELECT f.id,cf.acquisition_kind FROM sf_company_fields cf
        JOIN sf_fields f ON f.id=cf.field_id WHERE cf.company_id=? ORDER BY cf.acquired_at]], { member.company_id }) or {}) do
        local field = active[row.id]
        local permittedRows = scopes and scopes[row.id] or nil
        if field and (not scopes or permittedRows) then
            output[#output + 1] = fieldOverview(field, member, row, now, permittedRows)
            if permittedRows then
                local ids = {}; for rowId in pairs(permittedRows) do ids[#ids + 1] = rowId end
                table.sort(ids); output[#output].permittedRowIds = ids
            end
        end
    end
    table.sort(output, function(a, b) return a.criticalCount > b.criticalCount or
        (a.criticalCount == b.criticalCount and a.name < b.name) end)
    return { fields = output, landing = 'attention', headline = #output == 1 and 'One permanent Field under Company authority' or
        ('%d permanent Fields under Company authority'):format(#output) }
end

function Fields.LoadDetail(source, fieldId)
    if not Config.Features.Fields then return nil, 'unavailable' end
    local member = Fields.ActorContext(source)
    local field = active[fieldId]
    if not member or not (member.permissionMap['fields.view_portfolio'] or member.permissionMap['fields.view_assigned'])
        or not field or not owns(member.company_id, fieldId) then return nil, 'permission_denied' end
    local scopes = actorFieldScopes(source, member)
    local permittedRows = scopes and scopes[fieldId] or nil
    if scopes and not permittedRows then return nil, 'permission_denied' end
    local now, holding = Sonar.Time.Now(), fieldOwnership(fieldId, member.company_id)
    local result = fieldOverview(field, member, holding, now, permittedRows)
    local plans, planByRow = loadPlans(fieldId), {}
    for _, plan in ipairs(plans) do if plan.status == 'reserved' or plan.status == 'in_execution' then
        for _, rowId in ipairs(plan.rowIds) do planByRow[rowId] = plan end
    end end
    local cropBySlot, diagnostics = {}, {}
    for _, record in ipairs(recordsForField(field)) do
        local slotId = record.data and record.data.slotId or (field.legacySlots[record.slot] and field.legacySlots[record.slot].id)
        if slotId then
            local plant = plantState(record, now)
            cropBySlot[slotId] = plant
            if plant.water < 35 then diagnostics[#diagnostics + 1] = { id = 'water:' .. record.id, kind = 'water_low',
                severity = plant.water < 15 and 'critical' or 'warning', scope = 'slot', scopeId = slotId,
                title = 'Water deficit', cause = ('Water is %.0f%%'):format(plant.water), evidence = 'Authoritative crop physiology',
                window = 'Current state', impact = 'Growth and health loss', recommendedAction = 'Issue Water work' } end
            if plant.health < 50 then diagnostics[#diagnostics + 1] = { id = 'health:' .. record.id, kind = 'health_loss',
                severity = plant.health < 25 and 'critical' or 'warning', scope = 'slot', scopeId = slotId,
                title = 'Health loss', cause = ('Health is %.0f%%'):format(plant.health), evidence = 'Authoritative crop physiology',
                window = 'Current state', impact = 'Yield at risk', recommendedAction = 'Inspect condition and issue care work' } end
        end
    end
    local workByRow, linkedWorkById = {}, {}
    for _, link in ipairs(MySQL.query.await([[SELECT w.id,w.kind,w.title,w.status,w.assignee_identifier,pr.row_id
        FROM sf_work w JOIN sf_crop_plan_rows pr ON pr.plan_id=w.plan_id
        WHERE w.field_id=? AND w.status NOT IN ('cancelled','completed','failed','expired')
        ORDER BY w.created_at DESC]], { fieldId }) or {}) do
        local rowLinks = workByRow[link.row_id] or { assignments = {}, contracts = {} }
        workByRow[link.row_id] = rowLinks
        if link.kind == 'contract' then rowLinks.contracts[#rowLinks.contracts + 1] = link.id
        else rowLinks.assignments[#rowLinks.assignments + 1] = link.id end
        local existing = linkedWorkById[link.id]
        if not existing then
            existing = { id = link.id, kind = link.kind == 'contract' and 'contract' or 'assignment',
                title = link.title, status = link.status, assigneeId = link.assignee_identifier, rowIds = {} }
            linkedWorkById[link.id] = existing
        end
        existing.rowIds[#existing.rowIds + 1] = link.row_id
    end
    local slots, rows = {}, {}
    for _, slot in ipairs(field.slots) do
        local plant, plan = cropBySlot[slot.id], planByRow[slot.rowId]
        slots[#slots + 1] = { id = slot.id, legacyIndex = slot.legacyIndex, rowId = slot.rowId,
            label = ('Slot %d'):format(slot.order), position = slot.position,
            status = plant and 'occupied' or plan and 'planned' or 'empty', plant = plant,
            plannedCrop = plan and plan.crop or nil, diagnosticIds = {}, visible = true }
    end
    for _, row in ipairs(field.rows) do
        local occupied, planned, readyCount, criticalCount, sumWater, sumHealth, sumGrowth = 0, 0, 0, 0, 0, 0, 0
        local cropLabel = 'Empty'
        local rowWork = workByRow[row.id] or { assignments = {}, contracts = {} }
        for _, slotId in ipairs(row.slotIds) do
            local plant = cropBySlot[slotId]
            if plant then
                occupied, cropLabel = occupied + 1, plant.cropLabel
                sumWater, sumHealth, sumGrowth = sumWater + plant.water, sumHealth + plant.health, sumGrowth + plant.progress
                if plant.readiness ~= 'growing' then readyCount = readyCount + 1 end
                if plant.water < 15 or plant.health < 25 then criticalCount = criticalCount + 1 end
            elseif planByRow[row.id] then planned = planned + 1 end
        end
        local rowStatus = criticalCount > 0 and 'attention' or readyCount > 0 and 'ready' or occupied > 0 and 'growing' or planned > 0 and 'planned' or 'empty'
        rows[#rows + 1] = { id = row.id, label = row.label, order = row.order, slotIds = row.slotIds,
            plannedCrop = planByRow[row.id] and planByRow[row.id].crop or nil, cropLabel = cropLabel,
            occupied = occupied, planned = planned, available = #row.slotIds - occupied - planned,
            averageWater = occupied > 0 and sumWater / occupied or nil, averageHealth = occupied > 0 and sumHealth / occupied or nil,
            averageGrowth = occupied > 0 and sumGrowth / occupied or nil, readyCount = readyCount,
            criticalCount = criticalCount, status = rowStatus, assignmentIds = rowWork.assignments,
            contractIds = rowWork.contracts, visibleDetail = true }
    end
    local events = {}
    for _, row in ipairs(MySQL.query.await([[SELECT *,UNIX_TIMESTAMP(created_at) created_epoch FROM sf_field_events WHERE field_id=?
        ORDER BY sequence DESC LIMIT ?]], { fieldId, Config.Fields.MaxEventsPerDetail }) or {}) do
        local payload = decode(row.payload)
        events[#events + 1] = { id = row.id, type = row.event_type, at = iso(row.created_epoch), actor = row.actor_identifier,
            title = payload.title or row.event_type:gsub('_', ' '), detail = payload.detail or '', rowId = row.row_id, slotId = row.slot_id }
    end
    local linkedWork = {}
    for _, item in pairs(linkedWorkById) do
        if not permittedRows or item.assigneeId == member.identifier then
            table.sort(item.rowIds)
            item.scope = table.concat(item.rowIds, ', ')
            linkedWork[#linkedWork + 1] = item
        end
    end
    table.sort(linkedWork, function(a, b) return a.id < b.id end)
    result.topology = { fieldId = field.id, topologyRevision = field.topologyRevision,
        orientation = field.orientation, rows = rows, slots = slots, bounds = field.bounds }
    result.diagnostics, result.events, result.cropPlans, result.linkedWork = diagnostics, events, plans, linkedWork
    result.materialNeeds = {}
    result.serverTime, result.stateRevision, result.sequence = iso(now), field.topologyRevision, field.sequence
    result.availableActions = {}
    if Config.Features.Work and member.permissionMap['fields.plan'] then result.availableActions[#result.availableActions + 1] = 'create_plan' end
    if Config.Features.Work and member.permissionMap['work.create'] then result.availableActions[#result.availableActions + 1] = 'create_assignment' end
    if Config.Features.PublicContracts and member.permissionMap['contracts.create'] then result.availableActions[#result.availableActions + 1] = 'create_contract' end
    result.availableActions[#result.availableActions + 1] = 'set_route'
    if permittedRows then
        local ids = {}; for rowId in pairs(permittedRows) do ids[#ids + 1] = rowId end
        table.sort(ids); result.permittedRowIds = ids
        local visibleSlots = {}
        for _, slot in ipairs(result.topology.slots) do if permittedRows[slot.rowId] then visibleSlots[#visibleSlots + 1] = slot end end
        local visibleRows = {}
        for _, row in ipairs(result.topology.rows) do if permittedRows[row.id] then visibleRows[#visibleRows + 1] = row end end
        result.topology.slots, result.topology.rows = visibleSlots, visibleRows
        local visiblePlans = {}
        for _, plan in ipairs(result.cropPlans) do
            local visibleRowIds = {}
            for _, rowId in ipairs(plan.rowIds) do if permittedRows[rowId] then visibleRowIds[#visibleRowIds + 1] = rowId end end
            if #visibleRowIds > 0 then
                local safePlan = {}
                for key, value in pairs(plan) do if key ~= 'rowIds' then safePlan[key] = value end end
                safePlan.rowIds = visibleRowIds
                visiblePlans[#visiblePlans + 1] = safePlan
            end
        end
        result.cropPlans = visiblePlans
        local visibleEvents = {}
        for _, event in ipairs(result.events) do
            local slot = field.slotMap[event.slotId]
            if permittedRows[event.rowId] or slot and permittedRows[slot.rowId] then visibleEvents[#visibleEvents + 1] = event end
        end
        result.events = visibleEvents
        local visibleDiagnostics = {}
        for _, item in ipairs(result.diagnostics) do
            local slot = field.slotMap[item.scopeId]
            if item.scope == 'field' or permittedRows[item.scopeId] or slot and permittedRows[slot.rowId] then
                visibleDiagnostics[#visibleDiagnostics + 1] = item
            end
        end
        result.diagnostics = visibleDiagnostics
    end
    return result
end

function Fields.LoadLand(source)
    if not Config.Features.Fields then return nil, 'unavailable' end
    local member = membership(source, 'fields.view_portfolio')
    if not member then return nil, 'permission_denied' end
    local output = {}
    for _, field in pairs(active) do
        if field.catalogVisible then
            local owner = MySQL.single.await([[SELECT cf.company_id,c.name,cf.acquisition_kind,cf.acquired_at
                FROM sf_company_fields cf JOIN sf_companies c ON c.id=cf.company_id WHERE cf.field_id=? LIMIT 1]], { field.id })
            local draft = not owner and MySQL.single.await([[SELECT company_id,prepared_by,expires_at FROM sf_field_purchase_drafts
                WHERE field_id=? AND company_id=? AND status='prepared' AND expires_at>? LIMIT 1]],
                { field.id, member.company_id, Sonar.Time.Now() }) or nil
            local ownDraft = draft ~= nil
            output[#output + 1] = { id = field.id, fieldId = field.id, fieldName = field.name, location = field.location,
                status = owner and (owner.company_id == member.company_id and owner.acquisition_kind or 'owned') or 'available',
                purchasePrice = field.purchasePrice, capacity = #field.slots,
                allowedCrops = field.allowedCrops, ownedByCompany = owner and owner.company_id == member.company_id or false,
                ownerName = owner and owner.name or nil, recurringPrice = 0, billing = 'Permanent ownership',
                purchasePrepared = ownDraft or false, purchasePreparedBy = ownDraft and draft.prepared_by or nil,
                activeCrops = 'Open Field for live production', linkedWork = {},
                availableActions = owner and { 'open_field' }
                    or ownDraft and member.role_key == 'owner' and { 'purchase' }
                    or ownDraft and { 'prepare_purchase' }
                    or { 'prepare_purchase' } }
        end
    end
    table.sort(output, function(a, b) return a.fieldName < b.fieldName end)
    return output
end

function Fields.LoadLandDetail(source, fieldId)
    local rows, reason = Fields.LoadLand(source)
    if not rows then return nil, reason end
    for _, row in ipairs(rows) do if row.id == fieldId then return row end end
    return nil, 'field_unavailable'
end

local function bumpSequence(fieldId)
    MySQL.update.await('UPDATE sf_fields SET state_sequence=LAST_INSERT_ID(state_sequence+1) WHERE id=?', { fieldId })
    local sequence = tonumber(MySQL.scalar.await('SELECT state_sequence FROM sf_fields WHERE id=?', { fieldId })) or 0
    if active[fieldId] then active[fieldId].sequence = sequence end
    return sequence
end

function Fields.RecordEvent(fieldId, actor, eventType, rowId, slotId, payload)
    local acquired, sequence = Lock.With('field-event:' .. tostring(fieldId), function()
        local nextSequence, id = bumpSequence(fieldId), Sonar.Utils.Uuid()
        local inserted = MySQL.insert.await([[INSERT INTO sf_field_events
            (id,field_id,sequence,event_type,actor_identifier,row_id,slot_id,payload) VALUES (?,?,?,?,?,?,?,?)]],
            { id, fieldId, nextSequence, eventType, actor or 'system', rowId or '', slotId or '', encode(payload) })
        return inserted and nextSequence or nil
    end)
    if acquired and sequence then Fields.BroadcastInvalidate(fieldId, eventType) end
    return acquired and sequence or nil
end

local function validatePlanInput(member, input)
    local field = active[tostring(input and input.fieldId or '')]
    if not field or not owns(member.company_id, field.id) then return nil, 'field_unavailable' end
    local crop = tostring(input.crop or '')
    if not Config.Crops[crop] or (#field.allowedCrops > 0 and not contains(field.allowedCrops, crop)) then return nil, 'crop_not_allowed' end
    local rowIds, seen = {}, {}
    for _, rowId in ipairs(input.rowIds or {}) do
        if type(rowId) ~= 'string' or not field.rowMap[rowId] or seen[rowId] then return nil, 'invalid_rows' end
        seen[rowId], rowIds[#rowIds + 1] = true, rowId
    end
    if #rowIds < 1 or #rowIds > 20 then return nil, 'invalid_rows' end
    table.sort(rowIds)
    return { field = field, crop = crop, rowIds = rowIds }
end

function Fields.CreatePlan(source, input)
    if not Config.Features.Work then return { ok = false, reason = 'unavailable' } end
    local member = membership(source, 'fields.plan')
    if not member then return { ok = false, reason = 'permission_denied' } end
    local validated, reason = validatePlanInput(member, input or {})
    if not validated then return { ok = false, reason = reason } end
    local id, reference = Sonar.Utils.Uuid(), nextReference('PLAN')
    local queries = {{ query = [[INSERT INTO sf_crop_plans
        (id,reference,company_id,field_id,revision_id,crop_type,status,created_by)
        VALUES (?,?,?,?,?,?,'reserved',?)]], values = { id, reference, member.company_id,
        validated.field.id, validated.field.revisionId, validated.crop, member.identifier } }}
    for _, rowId in ipairs(validated.rowIds) do queries[#queries + 1] = { query = [[INSERT INTO sf_crop_plan_rows
        (plan_id,field_id,revision_id,row_id,active_reservation) VALUES (?,?,?,?,1)]],
        values = { id, validated.field.id, validated.field.revisionId, rowId } } end
    local ok, committed = pcall(function() return MySQL.transaction.await(queries) end)
    if not ok or committed ~= true then return { ok = false, reason = 'row_reserved', message = 'One of these Rows is already reserved.' } end
    Fields.RecordEvent(validated.field.id, member.identifier, 'plan_changed', nil, nil,
        { title = reference .. ' reserved', detail = validated.crop .. ' · ' .. table.concat(validated.rowIds, ', ') })
    return { ok = true, changed = true, entityId = id, message = reference .. ' reserved. Link Work before execution.', invalidated = { validated.field.id, 'work' } }
end

function Fields.UpdatePlan(source, planId, input)
    if not Config.Features.Work then return { ok = false, reason = 'unavailable' } end
    local member = membership(source, 'fields.plan')
    local plan = member and MySQL.single.await([[SELECT * FROM sf_crop_plans WHERE id=? AND company_id=?
        AND status='reserved' AND linked_work_id IS NULL LIMIT 1]], { planId, member.company_id })
    if not plan then return { ok = false, reason = 'plan_locked' } end
    local validated, reason = validatePlanInput(member, input or {})
    if not validated or validated.field.id ~= plan.field_id then return { ok = false, reason = reason or 'field_mismatch' } end
    local queries = {
        { query = 'UPDATE sf_crop_plan_rows SET active_reservation=NULL WHERE plan_id=?', values = { planId } },
        { query = 'DELETE FROM sf_crop_plan_rows WHERE plan_id=?', values = { planId } },
        { query = 'UPDATE sf_crop_plans SET crop_type=? WHERE id=?', values = { validated.crop, planId } },
    }
    for _, rowId in ipairs(validated.rowIds) do queries[#queries + 1] = { query = [[INSERT INTO sf_crop_plan_rows
        (plan_id,field_id,revision_id,row_id,active_reservation) VALUES (?,?,?,?,1)]],
        values = { planId, plan.field_id, plan.revision_id, rowId } } end
    local ok, committed = pcall(function() return MySQL.transaction.await(queries) end)
    if not ok or committed ~= true then return { ok = false, reason = 'row_reserved' } end
    Fields.RecordEvent(plan.field_id, member.identifier, 'plan_changed', nil, nil, { title = plan.reference .. ' updated', detail = validated.crop })
    return { ok = true, changed = true, entityId = planId, invalidated = { plan.field_id } }
end

function Fields.CancelPlan(source, planId)
    if not Config.Features.Work then return { ok = false, reason = 'unavailable' } end
    local member = membership(source, 'fields.plan')
    local plan = member and MySQL.single.await([[SELECT * FROM sf_crop_plans WHERE id=? AND company_id=?
        AND status='reserved' AND linked_work_id IS NULL LIMIT 1]], { planId, member.company_id })
    if not plan then return { ok = false, reason = 'plan_locked' } end
    local ok = MySQL.transaction.await({
        { query = "UPDATE sf_crop_plans SET status='cancelled' WHERE id=? AND status='reserved'", values = { planId } },
        { query = 'UPDATE sf_crop_plan_rows SET active_reservation=NULL WHERE plan_id=?', values = { planId } },
    })
    if not ok then return { ok = false, reason = 'database_error' } end
    Fields.RecordEvent(plan.field_id, member.identifier, 'plan_changed', nil, nil, { title = plan.reference .. ' cancelled' })
    return { ok = true, changed = true, invalidated = { plan.field_id, 'work' } }
end

local VALID_ACTIONS = { plant = true, water = true, fertilize = true, weed = true, treat_pest = true, harvest = true }

local function validateRequirements(field, cropType, requirements, permittedRows)
    local output = {}
    if type(requirements) ~= 'table' or #requirements < 1 or #requirements > 12 then return nil end
    for index, value in ipairs(requirements) do
        local action = tostring(value.action or '')
        local target = math.floor(tonumber(value.target) or 0)
        if not VALID_ACTIONS[action] or target < 1 or target > 400 then return nil end
        local requirementCrop = tostring(value.crop or cropType)
        if requirementCrop ~= cropType then return nil end
        local itemTier = value.itemTier and tostring(value.itemTier) or nil
        if itemTier and not Sonar.ItemCatalog.tiers[itemTier] then return nil end
        local thresholdKey = value.thresholdKey and tostring(value.thresholdKey) or nil
        if thresholdKey and not contains({ 'water', 'nutrients', 'weeds', 'pests', 'quality', 'production' }, thresholdKey) then return nil end
        local thresholdValue = thresholdKey and tonumber(value.thresholdValue) or nil
        if thresholdKey and (not thresholdValue or thresholdValue < 0 or thresholdValue > 100) then return nil end
        local rows, seen = {}, {}
        for _, rowId in ipairs(value.rowIds or {}) do
            if not field.rowMap[rowId] or seen[rowId] or permittedRows and not permittedRows[rowId] then return nil end
            seen[rowId], rows[#rows + 1] = true, rowId
        end
        if #rows < 1 then return nil end
        output[#output + 1] = { id = Sonar.Utils.Uuid(), action = action, rowIds = rows,
            cropType = requirementCrop, itemTier = itemTier,
            target = target, thresholdKey = thresholdKey, thresholdValue = thresholdValue, order = index }
    end
    return output
end

function Fields.CreateWork(source, kind, input)
    if kind == 'assignment' and not Config.Features.Work
        or kind == 'contract' and not Config.Features.PublicContracts then
        return { ok = false, reason = 'unavailable' }
    end
    local permission = kind == 'contract' and 'contracts.create' or 'work.create'
    local member = membership(source, permission)
    if not member then return { ok = false, reason = 'permission_denied' } end
    local acquired, result = Lock.With('company-finance', function()
    input = input or {}
    local plan = MySQL.single.await([[SELECT * FROM sf_crop_plans WHERE id=? AND company_id=?
        AND status='reserved' AND linked_work_id IS NULL LIMIT 1]], { tostring(input.sourcePlanId or ''), member.company_id })
    if not plan then return { ok = false, reason = 'plan_required', message = 'A reserved Crop Plan is required.' } end
    local field = active[plan.field_id]
    if not field or field.revisionId ~= plan.revision_id then return { ok = false, reason = 'topology_changed' } end
    local permittedRows = {}; for _, rowId in ipairs(planRows(plan.id)) do permittedRows[rowId] = true end
    local requirements = validateRequirements(field, plan.crop_type,
        input.structuredRequirements or input.requirements, permittedRows)
    if not requirements then return { ok = false, reason = 'invalid_requirements' } end
    local title, objective = tostring(input.title or ''), tostring(input.objective or '')
    if #title < 3 or #title > 120 or #objective < 3 or #objective > 255 then return { ok = false, reason = 'invalid_description' } end
    local payout = cents(kind == 'contract' and input.reward or input.payout)
    local deadline = math.floor(tonumber(input.deadlineAt) or 0)
    if payout <= 0 or deadline <= Sonar.Time.Now() then return { ok = false, reason = 'invalid_terms' } end
    local assignee = kind == 'assignment' and tostring(input.assigneeId or '') or nil
    if kind == 'assignment' then
        local activeMember = MySQL.scalar.await([[SELECT identifier FROM sf_company_members WHERE company_id=?
            AND identifier=? AND status='active' LIMIT 1]], { member.company_id, assignee })
        if not activeMember then return { ok = false, reason = 'invalid_assignee' } end
    end
    local id, reference, ledgerId = Sonar.Utils.Uuid(), nextReference(kind == 'contract' and 'CTR' or 'ASG'), Sonar.Utils.Uuid()
    local status = kind == 'contract' and 'draft' or 'assigned'
    local company = MySQL.single.await('SELECT treasury_cents FROM sf_companies WHERE id=? LIMIT 1', { member.company_id })
    if not company or tonumber(company.treasury_cents) < payout then return { ok = false, reason = 'treasury_insufficient' } end
    local queries = {
        { query = 'UPDATE sf_companies SET treasury_cents=treasury_cents-? WHERE id=? AND treasury_cents>=?', values = { payout, member.company_id, payout } },
        { query = [[INSERT INTO sf_work
            (id,reference,kind,company_id,field_id,revision_id,plan_id,title,objective,status,assignee_identifier,
             created_by,payout_cents,escrow_status,deadline_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,'reserved',?)]],
            values = { id, reference, kind, member.company_id, field.id, field.revisionId, plan.id, title, objective,
                status, assignee or '', member.identifier, payout, deadline } },
        { query = 'UPDATE sf_crop_plans SET linked_work_id=?,status=? WHERE id=? AND linked_work_id IS NULL',
            values = { id, kind == 'contract' and 'reserved' or 'in_execution', plan.id } },
        { query = [[INSERT INTO sf_company_ledger
            (id,company_id,idempotency_key,entry_type,direction,amount_cents,balance_after_cents,actor_identifier,linked_kind,linked_id)
            VALUES (?,?,?,?,?,?,?,?,?,?)]], values = { ledgerId, member.company_id, 'work-reserve:' .. id,
                kind .. '_escrow', 'reserve', payout, tonumber(company.treasury_cents) - payout,
                member.identifier, kind, id } },
    }
    for _, requirement in ipairs(requirements) do queries[#queries + 1] = { query = [[INSERT INTO sf_work_requirements
        (id,work_id,action,row_ids,crop_type,item_tier,target_count,threshold_key,threshold_value,requirement_order)
        VALUES (?,?,?,?,?,?,?,?,?,?)]], values = { requirement.id, id, requirement.action, encode(requirement.rowIds),
        requirement.cropType or '', requirement.itemTier or '', requirement.target,
        requirement.thresholdKey or '', requirement.thresholdValue or 0, requirement.order } } end
    local ok, committed = pcall(function() return MySQL.transaction.await(queries) end)
    if not ok or committed ~= true then return { ok = false, reason = 'database_error' } end
    Fields.RecordEvent(field.id, member.identifier, 'work_linked', nil, nil, { title = reference .. ' created', detail = title })
    return { ok = true, changed = true, entityId = id, message = reference .. ' created with funded pay.', invalidated = { 'work', field.id, 'treasury', 'ledger' } }
    end)
    return acquired and result or { ok = false, reason = 'already_in_progress', message = 'Company finance is busy; retry shortly.' }
end

local function workRequirements(workId)
    local output = {}
    for _, row in ipairs(MySQL.query.await([[SELECT * FROM sf_work_requirements WHERE work_id=?
        ORDER BY requirement_order]], { workId }) or {}) do
        output[#output + 1] = { id = row.id, action = row.action, rowIds = decode(row.row_ids), crop = row.crop_type,
            itemTier = row.item_tier, current = tonumber(row.current_count), target = tonumber(row.target_count),
            thresholdKey = row.threshold_key, thresholdValue = tonumber(row.threshold_value), status = row.status,
            label = row.action:gsub('_', ' '), detail = ('%s %d/%d'):format(row.action:gsub('_', ' '), tonumber(row.current_count), tonumber(row.target_count)),
            unit = 'verified actions' }
    end
    return output
end

local function workAccess(source, workId)
    local identifier = Bridge.GetIdentifier(source)
    local member = Company.GetMembership(source, true)
    local work = MySQL.single.await('SELECT * FROM sf_work WHERE id=? LIMIT 1', { workId })
    if not work then return nil end
    local own = work.assignee_identifier == identifier
    local manage = member and member.company_id == work.company_id and
        (member.permissionMap['work.view_team'] or member.permissionMap['work.review'] or member.permissionMap['contracts.review'])
    local public = work.kind == 'contract' and work.status == 'published'
    return (own or manage or public) and work or nil, member, own
end

function Fields.LoadWorkQueue(source)
    if not Config.Features.Work and not Config.Features.PublicContracts then return nil, 'unavailable' end
    local identifier, member = Bridge.GetIdentifier(source), Company.GetMembership(source, true)
    local clauses, values = {}, {}
    if member then
        clauses[#clauses + 1], values[#values + 1] = 'company_id=?', member.company_id
        clauses[#clauses + 1], values[#values + 1] = "(kind='contract' AND status='published')", nil
    else clauses[#clauses + 1] = "kind='contract' AND status='published'" end
    local sql = [[SELECT * FROM sf_work WHERE ]] .. table.concat(clauses, ' OR ') .. ' ORDER BY deadline_at LIMIT 100'
    local dense = {}; for _, value in ipairs(values) do if value then dense[#dense + 1] = value end end
    local items, areas = {}, {}
    local areaMap = {}
    local function area(value) if not areaMap[value] then areaMap[value], areas[#areas + 1] = true, value end end
    for _, row in ipairs(MySQL.query.await(sql, dense) or {}) do
        local visible = row.kind == 'contract' and row.status == 'published' or member and
            (row.company_id == member.company_id and (row.assignee_identifier == identifier or member.permissionMap['work.view_team']))
        if visible then
            local reqs, current, target = workRequirements(row.id), 0, 0
            for _, req in ipairs(reqs) do current, target = current + req.current, target + req.target end
            local itemType = row.kind == 'contract' and 'contract' or 'assignment'
            items[#items + 1] = { id = row.id, type = itemType, title = row.title,
                meta = row.reference .. ' · ' .. (active[row.field_id] and active[row.field_id].name or row.field_id),
                status = row.status:gsub('_', ' '), deadline = iso(row.deadline_at),
                progress = target > 0 and math.floor(current / target * 100) or 0, assigneeId = row.assignee_identifier }
            if row.kind == 'contract' then area(row.assignee_identifier == identifier and 'activeContract' or 'publicContracts') else area('assignments') end
        end
    end
    if Config.Features.BuyerOrders and member and member.permissionMap['buyer_orders.view'] then
        area('buyerOrders')
        for _, order in ipairs(MySQL.query.await([[SELECT * FROM sf_buyer_orders
            WHERE deadline_at>? AND (status='open' OR company_id=?) ORDER BY deadline_at LIMIT 100]],
            { Sonar.Time.Now(), member.company_id }) or {}) do
            local reserved = tonumber(MySQL.scalar.await([[SELECT COALESCE(SUM(quantity),0) FROM sf_produce_reservations
                WHERE order_id=? AND status='active']], { order.id })) or 0
            items[#items + 1] = { id = order.id, type = 'buyerOrder', title = order.buyer .. ' · ' .. order.item_id,
                meta = ('%d units · minimum quality %.0f'):format(tonumber(order.quantity), tonumber(order.minimum_quality)),
                status = order.status:gsub('_', ' '), deadline = iso(order.deadline_at),
                progress = math.floor(math.min(1, reserved / math.max(1, tonumber(order.quantity))) * 100) }
        end
    end
    return { areas = areas, items = items,
        canCreateAssignment = member and member.permissionMap['work.create'] == true or false,
        canCreateContract = member and member.permissionMap['contracts.create'] == true or false }
end

function Fields.LoadWorkCreate(source, kind)
    if kind == 'assignment' and not Config.Features.Work
        or kind == 'contract' and not Config.Features.PublicContracts then return nil, 'unavailable' end
    local permission = kind == 'contract' and 'contracts.create' or 'work.create'
    local member = membership(source, permission)
    if not member then return nil, 'permission_denied' end
    local fields, members, plans = {}, {}, {}
    for _, holding in ipairs(MySQL.query.await([[SELECT f.id,f.name FROM sf_company_fields cf
        JOIN sf_fields f ON f.id=cf.field_id WHERE cf.company_id=? ORDER BY f.name]], { member.company_id }) or {}) do
        local field = active[holding.id]
        if field then fields[#fields + 1] = { id = field.id, name = field.name, description = #field.rows .. ' Rows · ' .. #field.slots .. ' Slots' } end
    end
    for _, row in ipairs(MySQL.query.await([[SELECT identifier,display_name,role_key FROM sf_company_members
        WHERE company_id=? AND status='active' ORDER BY display_name]], { member.company_id }) or {}) do
        members[#members + 1] = { id = row.identifier, name = row.display_name, role = row.role_key }
    end
    for _, row in ipairs(MySQL.query.await([[SELECT id,reference,field_id,crop_type FROM sf_crop_plans
        WHERE company_id=? AND status='reserved' AND linked_work_id IS NULL ORDER BY created_at]], { member.company_id }) or {}) do
        plans[#plans + 1] = { id = row.id, reference = row.reference, fieldId = row.field_id,
            crop = row.crop_type, rowIds = planRows(row.id) }
    end
    return { nextReference = kind == 'contract' and 'CTR-PENDING' or 'ASG-PENDING', fields = fields,
        members = members, plans = plans, serverNow = Sonar.Time.Now() }
end

function Fields.LoadWorkDetail(source, workId)
    local work, member, own = workAccess(source, workId)
    if not work then return nil, 'permission_denied' end
    if work.kind == 'assignment' and not Config.Features.Work
        or work.kind == 'contract' and not Config.Features.PublicContracts then return nil, 'unavailable' end
    local field, requirements = active[work.field_id], workRequirements(work.id)
    local rows = work.plan_id and planRows(work.plan_id) or {}
    local actions = {}
    local requirementsComplete = true
    for _, requirement in ipairs(requirements) do
        if requirement.current < requirement.target then requirementsComplete = false; break end
    end
    local canManageAssignment = work.kind == 'assignment' and member and member.company_id == work.company_id
        and member.permissionMap['work.create'] == true
    if work.kind == 'contract' and work.status == 'draft' and member and member.permissionMap['contracts.create'] then actions[#actions + 1] = 'publish' end
    if work.kind == 'contract' and work.status == 'published'
        and (not work.assignee_identifier or work.assignee_identifier == '') then actions[#actions + 1] = 'accept' end
    if work.kind == 'assignment' and own and work.status == 'assigned' then actions[#actions + 1] = 'accept' end
    if own and work.status == 'active' then
        if requirementsComplete then actions[#actions + 1] = 'submit'
        elseif work.kind == 'assignment' then actions[#actions + 1] = 'resume'
        else actions[#actions + 1] = 'set_route_field' end
    end
    if own and work.kind == 'contract' and work.status == 'active' then actions[#actions + 1] = 'abandon' end
    if member and member.permissionMap['work.review'] and work.status == 'awaiting_review' then
        actions[#actions + 1], actions[#actions + 1] = 'approve', 'request_correction'
    end
    if work.kind == 'contract' and member and member.permissionMap['contracts.review'] and work.status == 'awaiting_review' then actions[#actions + 1] = 'complete' end
    if member and ((work.kind == 'assignment' and member.permissionMap['work.create'])
        or (work.kind == 'contract' and member.permissionMap['contracts.create']))
        and contains({ 'draft', 'published', 'assigned', 'active' }, work.status) then actions[#actions + 1] = 'cancel' end
    if canManageAssignment and contains({ 'assigned', 'active' }, work.status) then actions[#actions + 1] = 'reassign' end
    local presentedStatus = work.kind == 'assignment' and (work.status == 'active' and 'in_progress'
        or work.status == 'releasing' and 'awaiting_review' or work.status) or work.status
    local base = { id = work.id, reference = work.reference, title = work.title, status = presentedStatus,
        statusLabel = presentedStatus:gsub('_', ' '), objective = work.objective,
        crop = work.plan_id and (MySQL.scalar.await('SELECT crop_type FROM sf_crop_plans WHERE id=?', { work.plan_id }) or '') or '',
        field = { id = work.field_id, name = field and field.name or work.field_id, scope = table.concat(rows, ', '), routeLabel = 'Set Field route' },
        deadline = iso(work.deadline_at), deadlineIso = iso(work.deadline_at), requirements = requirements,
        payout = { amount = dollars(work.payout_cents), currency = 'USD', status = work.escrow_status,
            conditions = { 'Verified requirements', 'Supervisor or Manager approval' } },
        progress = {}, availableActions = actions, sourcePlanId = work.plan_id,
        scopeRef = { fieldId = work.field_id, rowIds = rows } }
    if work.kind == 'assignment' then
        local eligibleAssignees, assigneeName, assigneeRole = {}, work.assignee_identifier, 'Worker'
        for _, candidate in ipairs(MySQL.query.await([[SELECT identifier,display_name,role_key FROM sf_company_members
            WHERE company_id=? AND status='active' ORDER BY display_name]], { work.company_id }) or {}) do
            eligibleAssignees[#eligibleAssignees + 1] = {
                id = candidate.identifier, name = candidate.display_name, role = candidate.role_key,
            }
            if candidate.identifier == work.assignee_identifier then
                assigneeName, assigneeRole = candidate.display_name, candidate.role_key
            end
        end
        base.workType = 'Structured Field Work'; base.assignee = { id = work.assignee_identifier, name = assigneeName, role = assigneeRole }
        base.supervisor = { id = work.created_by, name = work.created_by }; base.issuedMaterials = {}; base.cancellationSummary = 'Reserved pay returns to Treasury before completion.'
        base.eligibleAssignees = canManageAssignment and eligibleAssignees or {}
        return base
    end
    base.field = field and field.name or work.field_id; base.scope = table.concat(rows, ', ')
    base.reward = dollars(work.payout_cents); base.escrowStatus = work.escrow_status
    base.contractor = work.assignee_identifier; base.materialsPolicy = 'Personal or issued Company materials'
    base.fieldAccess = work.status == 'active' and 'Exact reserved Rows' or 'Granted after acceptance'
    base.cargoOwnership = 'Company'; base.deliveryDestination = 'Company Warehouse'; base.producedCargo = 'None deposited'
    base.steps = {}; for _, req in ipairs(requirements) do base.steps[#base.steps + 1] = { id = req.id, label = req.label, detail = req.detail, completed = req.current >= req.target } end
    base.requirements, base.failureRules = {}, { 'Deadline expiry', 'Unverified result' }
    base.availableActions = actions; return base
end

function Fields.ReassignAssignment(source, workId, assigneeId)
    if not Config.Features.Work then return { ok = false, reason = 'unavailable' } end
    local member = membership(source, 'work.create')
    assigneeId = tostring(assigneeId or '')
    if not member or assigneeId == '' then return { ok = false, reason = 'permission_denied' } end
    local acquired, result = Lock.With('work-reassign:' .. tostring(workId), function()
        local eligible = MySQL.single.await([[SELECT identifier,display_name FROM sf_company_members
            WHERE company_id=? AND identifier=? AND status='active' LIMIT 1]], { member.company_id, assigneeId })
        if not eligible then return { ok = false, reason = 'assignee_unavailable' } end
        local changed = MySQL.update.await([[UPDATE sf_work SET assignee_identifier=?,status='assigned'
            WHERE id=? AND company_id=? AND kind='assignment' AND status IN ('assigned','active')
              AND assignee_identifier<>?]], { assigneeId, workId, member.company_id, assigneeId })
        if tonumber(changed) ~= 1 then return { ok = false, reason = 'stale_state' } end
        local work = MySQL.single.await('SELECT field_id,reference FROM sf_work WHERE id=? LIMIT 1', { workId })
        if work then
            Fields.RecordEvent(work.field_id, member.identifier, 'work_reassigned', nil, nil,
                { title = work.reference .. ' reassigned', assigneeId = assigneeId })
        end
        return { ok = true, changed = true, message = ('Assignment reassigned to %s.'):format(eligible.display_name) }
    end)
    return acquired and result or { ok = false, reason = 'already_in_progress' }
end

function Fields.AcceptContract(source, workId)
    if not Config.Features.PublicContracts then return { ok = false, reason = 'unavailable' } end
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return { ok = false, reason = 'player_not_ready' } end
    local changed = MySQL.update.await([[UPDATE sf_work SET assignee_identifier=?,status='active'
        WHERE id=? AND kind='contract' AND status='published'
          AND (assignee_identifier IS NULL OR assignee_identifier='') AND deadline_at>?]],
        { identifier, workId, Sonar.Time.Now() })
    if tonumber(changed) ~= 1 then return { ok = false, reason = 'contract_unavailable' } end
    local work = MySQL.single.await('SELECT field_id,plan_id,reference FROM sf_work WHERE id=?', { workId })
    MySQL.update.await("UPDATE sf_crop_plans SET status='in_execution' WHERE id=?", { work.plan_id })
    Fields.RecordEvent(work.field_id, identifier, 'access_changed', nil, nil, { title = work.reference .. ' accepted' })
    return { ok = true, changed = true, entityId = workId, message = 'Contract accepted. Access is limited to its reserved Rows.' }
end

function Fields.PublishContract(source, workId)
    if not Config.Features.PublicContracts then return { ok = false, reason = 'unavailable' } end
    local member = membership(source, 'contracts.create')
    if not member then return { ok = false, reason = 'permission_denied' } end
    local changed = MySQL.update.await([[UPDATE sf_work SET status='published' WHERE id=? AND company_id=?
        AND kind='contract' AND status='draft']], { workId, member.company_id })
    return tonumber(changed) == 1 and { ok = true, changed = true, message = 'Contract published.' } or { ok = false, reason = 'stale_state' }
end

function Fields.StartAssignment(source, workId)
    if not Config.Features.Work then return { ok = false, reason = 'unavailable' } end
    local identifier = Bridge.GetIdentifier(source)
    local changed = MySQL.update.await([[UPDATE sf_work SET status='active' WHERE id=? AND kind='assignment'
        AND status='assigned' AND assignee_identifier=? AND deadline_at>?]],
        { workId, identifier, Sonar.Time.Now() })
    return tonumber(changed) == 1 and { ok = true, changed = true, message = 'Assignment accepted.' }
        or { ok = false, reason = 'assignment_unavailable' }
end

function Fields.ResumeWork(source, workId)
    local work, _, own = workAccess(source, workId)
    if not work or not own or work.status ~= 'active' then return { ok = false, reason = 'permission_denied' } end
    if work.kind == 'assignment' and not Config.Features.Work
        or work.kind == 'contract' and not Config.Features.PublicContracts then return { ok = false, reason = 'unavailable' } end
    local field = active[work.field_id]
    if not field then return { ok = false, reason = 'field_unavailable' } end
    return { ok = true, changed = false, closeSurface = true, message = 'Authorized Work route set.',
        route = field.access, handoff = { kind = 'route', scope = { fieldId = field.id, rowIds = planRows(work.plan_id) } } }
end

function Fields.CancelWork(source, workId, reason, abandon)
    local kind = MySQL.scalar.await('SELECT kind FROM sf_work WHERE id=? LIMIT 1', { workId })
    if kind == 'assignment' and not Config.Features.Work
        or kind == 'contract' and not Config.Features.PublicContracts then return { ok = false, reason = 'unavailable' } end
    local identifier = Bridge.GetIdentifier(source)
    local acquired, result = Lock.With('company-finance', function()
        local work = MySQL.single.await('SELECT * FROM sf_work WHERE id=? LIMIT 1', { workId })
        if not work or not contains({ 'draft', 'published', 'assigned', 'active' }, work.status) then
            return { ok = false, reason = 'work_unavailable' }
        end
        local progress = tonumber(MySQL.scalar.await([[SELECT COALESCE(SUM(current_count),0)
            FROM sf_work_requirements WHERE work_id=?]], { workId })) or 0
        if progress > 0 then return { ok = false, reason = 'work_has_progress' } end
        if abandon and work.kind == 'contract' and work.assignee_identifier == identifier and work.status == 'active' then
            MySQL.update.await([[UPDATE sf_work SET assignee_identifier=NULL,status='published',review_note=?
                WHERE id=? AND status='active' AND assignee_identifier=?]],
                { tostring(reason or ''):sub(1, 255), workId, identifier })
            return { ok = true, changed = true, message = 'Contract released back to the public board.' }
        end
        local member = Company.GetMembership(source, true)
        local permission = work.kind == 'contract' and 'contracts.create' or 'work.create'
        if not member or member.company_id ~= work.company_id or not member.permissionMap[permission] then
            return { ok = false, reason = 'permission_denied' }
        end
        local company = MySQL.single.await('SELECT treasury_cents FROM sf_companies WHERE id=? LIMIT 1', { work.company_id })
        if not company then return { ok = false, reason = 'company_unavailable' } end
        local payout, ledgerId = tonumber(work.payout_cents), Sonar.Utils.Uuid()
        local queries = {
            { query = 'UPDATE sf_companies SET treasury_cents=treasury_cents+? WHERE id=?', values = { payout, work.company_id } },
            { query = [[UPDATE sf_work SET status='cancelled',escrow_status='refunded',reviewed_by=?,review_note=?
                WHERE id=? AND status IN ('draft','published','assigned','active')]],
                values = { member.identifier, tostring(reason or ''):sub(1, 255), workId } },
            { query = "UPDATE sf_crop_plans SET linked_work_id=NULL,status='reserved' WHERE id=? AND linked_work_id=?",
                values = { work.plan_id, workId } },
            { query = [[INSERT INTO sf_company_ledger
                (id,company_id,idempotency_key,entry_type,direction,amount_cents,balance_after_cents,actor_identifier,linked_kind,linked_id)
                VALUES (?,?,?,?,?,?,?,?,?,?)]], values = { ledgerId, work.company_id, 'work-refund:' .. workId,
                work.kind .. '_escrow_refund', 'refund', payout, tonumber(company.treasury_cents) + payout,
                member.identifier, work.kind, workId } },
        }
        if not MySQL.transaction.await(queries) then return { ok = false, reason = 'database_error' } end
        return { ok = true, changed = true, message = 'Work cancelled and reserved pay returned to Treasury.' }
    end)
    return acquired and result or { ok = false, reason = 'already_in_progress' }
end

function Fields.SubmitWork(source, workId)
    local kind = MySQL.scalar.await('SELECT kind FROM sf_work WHERE id=? LIMIT 1', { workId })
    if kind == 'assignment' and not Config.Features.Work
        or kind == 'contract' and not Config.Features.PublicContracts then return { ok = false, reason = 'unavailable' } end
    local work, _, own = workAccess(source, workId)
    if not work or not own or work.status ~= 'active' then return { ok = false, reason = 'permission_denied' } end
    local incomplete = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sf_work_requirements
        WHERE work_id=? AND current_count<target_count]], { workId })) or 0
    if incomplete > 0 then return { ok = false, reason = 'requirements_incomplete' } end
    MySQL.update.await("UPDATE sf_work SET status='awaiting_review',submitted_at=? WHERE id=?", { Sonar.Time.Now(), workId })
    return { ok = true, changed = true, message = 'Work submitted for review.' }
end

function Fields.ReviewWork(source, workId, approve, note)
    local kind = MySQL.scalar.await('SELECT kind FROM sf_work WHERE id=? LIMIT 1', { workId })
    if kind == 'assignment' and not Config.Features.Work
        or kind == 'contract' and not Config.Features.PublicContracts then return { ok = false, reason = 'unavailable' } end
    local member = membership(source, 'work.review') or membership(source, 'contracts.review')
    local work = member and MySQL.single.await([[SELECT * FROM sf_work WHERE id=? AND company_id=?
        AND status='awaiting_review' LIMIT 1]], { workId, member.company_id })
    if not work then return { ok = false, reason = 'permission_denied' } end
    if not approve then
        MySQL.update.await("UPDATE sf_work SET status='active',reviewed_by=?,review_note=? WHERE id=?",
            { member.identifier, tostring(note or ''):sub(1, 255), workId })
        return { ok = true, changed = true, message = 'Correction requested.' }
    end
    local openMaterials = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sf_material_issues
        WHERE company_id=? AND identifier=? AND status IN ('pending','issued','return_pending')]],
        { work.company_id, work.assignee_identifier })) or 0
    if openMaterials > 0 then
        return { ok = false, reason = 'material_custody_outstanding',
            message = 'Return or fully consume issued Company materials before approval.' }
    end
    local openCargo = tonumber(MySQL.scalar.await([[SELECT COUNT(*) FROM sf_company_cargo
        WHERE company_id=? AND work_id=? AND status IN ('prepared','carrying','partial_deposit','mismatch')]],
        { work.company_id, work.id })) or 0
    if openCargo > 0 then
        return { ok = false, reason = 'cargo_outstanding',
            message = 'Deposit all Company Cargo before approval.' }
    end
    local outboxId = Sonar.Utils.Uuid()
    local payload = { workId = workId, identifier = work.assignee_identifier, amountCents = tonumber(work.payout_cents),
        companyId = work.company_id, reviewer = member.identifier, kind = work.kind }
    local ok = MySQL.transaction.await({
        { query = "UPDATE sf_work SET status='releasing',reviewed_by=?,review_note=? WHERE id=? AND status='awaiting_review'",
            values = { member.identifier, tostring(note or ''):sub(1, 255), workId } },
        { query = [[INSERT INTO sf_field_outbox
            (id,company_id,identifier,kind,idempotency_key,status,payload) VALUES (?,?,?,'payout',?,'pending',?)]],
            values = { outboxId, work.company_id, work.assignee_identifier, 'work-payout:' .. workId, encode(payload) } },
    })
    if not ok then return { ok = false, reason = 'database_error' } end
    Fields.ProcessOutboxFor(outboxId)
    return { ok = true, changed = true, message = 'Work approved. Bank payout is processing.' }
end

local function workForAction(source, companyId, fieldId, rowId, action, cropType)
    local identifier, member = Bridge.GetIdentifier(source), Company.GetMembership(source, true)
    local rows = MySQL.query.await([[SELECT w.*,r.id requirement_id,r.row_ids,r.crop_type requirement_crop,
        r.item_tier,r.threshold_key,r.threshold_value,r.current_count,r.target_count
        FROM sf_work w JOIN sf_work_requirements r ON r.work_id=w.id
        WHERE w.company_id=? AND w.field_id=? AND w.assignee_identifier=? AND w.status='active'
          AND w.deadline_at>? AND r.action=? AND r.current_count<r.target_count ORDER BY w.deadline_at]],
        { companyId, fieldId, identifier, Sonar.Time.Now(), action }) or {}
    for _, work in ipairs(rows) do
        if contains(decode(work.row_ids), rowId) and (work.requirement_crop == '' or work.requirement_crop == cropType) then
            return work, member
        end
    end
    return nil, member
end

function Fields.ResolvePlantAccess(source, cropType, zone, slotIndex)
    if not Fields.IsAuthorityEnabled() then return { ok = true, legacy = true } end
    local slot = Fields.ResolveLegacySlot(zone, slotIndex)
    if not slot then return { ok = false, reason = 'unknown_slot' } end
    local actor = Fields.ActorContext(source)
    local companyId = actor and actor.company_id
    if not companyId or not owns(companyId, slot.fieldId) then return { ok = false, reason = 'field_access_denied' } end
    local work = workForAction(source, companyId, slot.fieldId, slot.rowId, 'plant', cropType)
    if not work then return { ok = false, reason = 'work_required' } end
    return { ok = true, member = actor, field = active[slot.fieldId], slot = slot, work = work,
        planId = work.plan_id, companyId = companyId }
end

function Fields.ResolveCropAccess(source, record, action)
    if not Fields.IsAuthorityEnabled() then return { ok = true, legacy = true } end
    local data = record.data or {}
    -- Transitional crops keep their original authority until harvested/cleared.
    if not data.companyId or not data.fieldId or not data.rowId then return { ok = true, legacy = true } end
    local work = workForAction(source, data.companyId, data.fieldId, data.rowId, action, record.crop_type)
    if not work then return { ok = false, reason = 'work_required' } end
    return { ok = true, work = work, companyId = data.companyId, fieldId = data.fieldId, rowId = data.rowId, slotId = data.slotId }
end

function Fields.RecordOperation(source, record, action, access, payload)
    if not access or access.legacy then return true end
    payload = payload or {}
    local verified = payload.requirementVerifiedOverride ~= false
    local requiredTier = tostring(access.work.item_tier or '')
    if requiredTier ~= '' then
        local item = Sonar.ItemCatalog.byId[tostring(payload.itemId or '')]
        local actualRank = item and Sonar.ItemCatalog.tiers[item.tier] or 0
        local requiredRank = Sonar.ItemCatalog.tiers[requiredTier] or math.huge
        if actualRank < requiredRank then verified = false end
    end
    local thresholdKey = tostring(access.work.threshold_key or '')
    if thresholdKey ~= '' then
        local value, threshold = tonumber(payload[thresholdKey]), tonumber(access.work.threshold_value)
        if not value or not threshold then verified = false end
        local upperBound = thresholdKey == 'weeds' or thresholdKey == 'pests'
        if value and threshold and (upperBound and value > threshold or not upperBound and value < threshold) then
            verified = false
        end
    end
    payload.requirementVerified = verified
    local operationId = Sonar.Utils.Uuid()
    local actor = Bridge.GetIdentifier(source)
    local queries = {
        { query = [[INSERT INTO sf_farming_operations
            (operation_id,company_id,field_id,work_id,actor_identifier,action,crop_id,row_id,slot_id,payload)
            VALUES (?,?,?,?,?,?,?,?,?,?)]], values = { operationId, access.companyId, access.fieldId or access.field.id,
            access.work.id, actor, action, record and record.id or '', access.rowId or access.slot.rowId,
            access.slotId or access.slot.id, encode(payload) } },
    }
    if verified then queries[#queries + 1] = { query = [[UPDATE sf_work_requirements SET current_count=LEAST(target_count,current_count+1),
        status=IF(current_count+1>=target_count,'verified',status) WHERE id=? AND current_count<target_count]],
        values = { access.work.requirement_id } } end
    if not MySQL.transaction.await(queries) then return false end
    Fields.RecordEvent(access.fieldId or access.field.id, actor, action == 'plant' and 'planted' or action .. 'ed',
        access.rowId or access.slot.rowId, access.slotId or access.slot.id,
        { title = action:gsub('_', ' ') .. (verified and ' verified' or ' recorded'),
            detail = verified and access.work.reference or (access.work.reference .. ' · requirement conditions not met') })
    return true, verified and nil or 'requirement_not_verified'
end

function Fields.ProcessOutboxFor(outboxId)
    local row = MySQL.single.await([[SELECT * FROM sf_field_outbox WHERE id=?
        AND ((kind='payout' AND status='pending')
          OR (kind IN ('cargo_harvest','cargo_deposit') AND status='prepared')) LIMIT 1]], { outboxId })
    if not row then return false end
    local payload = decode(row.payload)
    if row.kind == 'payout' then
        local claimed = MySQL.update.await("UPDATE sf_field_outbox SET status='paying',attempts=attempts+1 WHERE id=? AND status='pending'", { outboxId })
        if tonumber(claimed) ~= 1 then return false end
        local paid = Bridge.CreditMoney(payload.identifier, 'bank', dollars(payload.amountCents),
            'Sonar Farm ' .. tostring(payload.kind) .. ' payout', row.idempotency_key)
        if paid == true then
            local work = MySQL.single.await('SELECT * FROM sf_work WHERE id=? LIMIT 1', { payload.workId })
            local balance = tonumber(MySQL.scalar.await('SELECT treasury_cents FROM sf_companies WHERE id=?', { payload.companyId })) or 0
            local committed = MySQL.transaction.await({
                { query = "UPDATE sf_work SET status='completed',escrow_status='released',completed_at=? WHERE id=? AND status='releasing'",
                    values = { Sonar.Time.Now(), payload.workId } },
                { query = "UPDATE sf_crop_plans SET status='completed' WHERE id=?", values = { work and work.plan_id or '' } },
                { query = 'UPDATE sf_crop_plan_rows SET active_reservation=NULL WHERE plan_id=?', values = { work and work.plan_id or '' } },
                { query = "UPDATE sf_field_outbox SET status='completed',last_error=NULL WHERE id=? AND status='paying'", values = { outboxId } },
                { query = [[INSERT INTO sf_company_ledger
                    (id,company_id,idempotency_key,entry_type,direction,amount_cents,balance_after_cents,actor_identifier,linked_kind,linked_id)
                    VALUES (?,?,?,?,?,?,?,?,?,?)]], values = { Sonar.Utils.Uuid(), payload.companyId,
                    'work-release:' .. payload.workId, 'work_payout', 'release', payload.amountCents, balance,
                    payload.reviewer, payload.kind, payload.workId } },
            })
            if committed == true then return true end
            -- The external credit succeeded but our journal did not. Never call
            -- the bank provider again; an operator must reconcile this payment.
            MySQL.update.await([[UPDATE sf_field_outbox SET status='reconciliation_required',
                last_error='bank_paid_database_unconfirmed' WHERE id=? AND status='paying']], { outboxId })
            return false
        end
        -- Never retry an ambiguous framework-side money operation automatically.
        MySQL.update.await("UPDATE sf_field_outbox SET status='reconciliation_required',last_error='bank_credit_unconfirmed' WHERE id=? AND status='paying'", { outboxId })
        return false
    end
    if row.kind == 'cargo_harvest' then
        local player = Bridge.GetPlayerByIdentifier(payload.identifier)
        local playerSource = player and player.PlayerData and player.PlayerData.source
        if not playerSource then return false end
        local held = Bridge.Inventory.GetItemCount(playerSource, payload.itemId, { cargoId = payload.cargoId })
        local record = State.Get(payload.cropId)
        if held >= tonumber(payload.quantity or 0) then
            -- AddItem committed before a restart: complete the DB side and remove
            -- the still-loaded crop exactly once instead of issuing produce twice.
            if record then State.Remove(record.id); Sync.OnCropRemoved(record.id, record.cell) end
            return MySQL.transaction.await({
                { query = "UPDATE sf_company_cargo SET status='carrying' WHERE id=? AND status='prepared'", values = { payload.cargoId } },
                { query = "UPDATE sf_field_outbox SET status='completed',last_error=NULL WHERE id=? AND status='prepared'", values = { outboxId } },
            }) == true
        end
        if record then
            -- Inventory was never mutated; leave the mature crop available for a
            -- fresh harvest and retire only this abandoned reservation.
            return MySQL.transaction.await({
                { query = "UPDATE sf_company_cargo SET status='failed' WHERE id=? AND status='prepared'", values = { payload.cargoId } },
                { query = "UPDATE sf_field_outbox SET status='failed',last_error='harvest_not_delivered' WHERE id=? AND status='prepared'", values = { outboxId } },
            }) == true
        end
        MySQL.update.await([[UPDATE sf_field_outbox SET status='reconciliation_required',
            last_error='crop_and_cargo_missing' WHERE id=? AND status='prepared']], { outboxId })
        MySQL.update.await("UPDATE sf_company_cargo SET status='mismatch' WHERE id=? AND status='prepared'", { payload.cargoId })
        return false
    end
    if row.kind == 'cargo_deposit' then
        local player = Bridge.GetPlayerByIdentifier(payload.identifier)
        local playerSource = player and player.PlayerData and player.PlayerData.source
        if not playerSource then return false end
        local held = Bridge.Inventory.GetItemCount(playerSource, payload.itemId, { cargoId = payload.cargoId })
        local beforeCount, quantity = tonumber(payload.beforeCount or 0), tonumber(payload.quantity or 0)
        if held >= beforeCount then
            MySQL.update.await([[UPDATE sf_field_outbox SET status='failed',
                last_error='deposit_inventory_unchanged' WHERE id=? AND status='prepared']], { outboxId })
            return false
        end
        if held ~= beforeCount - quantity then
            MySQL.update.await([[UPDATE sf_field_outbox SET status='reconciliation_required',
                last_error='deposit_partial_inventory_mutation' WHERE id=? AND status='prepared']], { outboxId })
            return false
        end
        local committed = MySQL.transaction.await({
            { query = [[INSERT INTO sf_warehouse_produce_lots
                (id,company_id,item_id,quality_tier,quality,production,defect,quantity,source_cargo_id)
                VALUES (?,?,?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE quantity=quantity+VALUES(quantity)]],
                values = { payload.lotId, payload.companyId, payload.itemId, payload.qualityTier,
                    payload.quality, payload.production, payload.defect or '', payload.quantity, payload.cargoId } },
            { query = [[UPDATE sf_company_cargo SET deposited_quantity=deposited_quantity+?,
                status=IF(deposited_quantity+?>=quantity,'completed','partial_deposit')
                WHERE id=? AND deposited_quantity+?<=quantity]],
                values = { payload.quantity, payload.quantity, payload.cargoId, payload.quantity } },
            { query = "UPDATE sf_field_outbox SET status='completed',last_error=NULL WHERE id=? AND status='prepared'",
                values = { outboxId } },
        })
        if committed == true then return true end
        MySQL.update.await([[UPDATE sf_field_outbox SET status='reconciliation_required',
            last_error='deposit_database_unconfirmed' WHERE id=? AND status='prepared']], { outboxId })
        return false
    end
    return false
end

function Fields.ProcessOutbox()
    for _, row in ipairs(MySQL.query.await([[SELECT id FROM sf_field_outbox
        WHERE status='pending' OR (kind IN ('cargo_harvest','cargo_deposit') AND status='prepared')
        ORDER BY created_at LIMIT 20]]) or {}) do
        Fields.ProcessOutboxFor(row.id)
    end
end

function Fields.PrepareHarvestCargo(source, record, units, metadata, access)
    if not Config.Features.CompanyCargo or not access or access.legacy then return nil, nil end
    local existing = MySQL.single.await([[SELECT c.id cargo_id,c.status,o.id outbox_id FROM sf_company_cargo c
        LEFT JOIN sf_field_outbox o ON o.company_id=c.company_id AND o.kind='cargo_harvest'
          AND o.idempotency_key=CONCAT('cargo-harvest:',c.crop_id)
        WHERE c.crop_id=? LIMIT 1]], { record.id })
    if existing and existing.status ~= 'failed' then return nil, 'harvest_in_progress' end
    if existing and not existing.outbox_id then return nil, 'reconciliation_required' end
    local cargoId = existing and existing.cargo_id or Sonar.Utils.Uuid()
    local outboxId = existing and existing.outbox_id or Sonar.Utils.Uuid()
    local payload = { cargoId = cargoId, cropId = record.id, itemId = Config.Crops[record.crop_type].productItem,
        quantity = units, metadata = metadata, identifier = Bridge.GetIdentifier(source), companyId = access.companyId,
        fieldId = access.fieldId, workId = access.work.id }
    local cargoMetadata = {}
    for key, value in pairs(metadata or {}) do cargoMetadata[key] = value end
    cargoMetadata.ownership, cargoMetadata.companyId, cargoMetadata.cargoId = 'company', access.companyId, cargoId
    cargoMetadata.fieldId = access.fieldId
    cargoMetadata.workKind, cargoMetadata.workId = access.work.kind, access.work.id
    payload.cargoMetadata = cargoMetadata
    local queries
    if existing then
        queries = {
            { query = [[UPDATE sf_company_cargo SET custodian_identifier=?,item_id=?,quantity=?,deposited_quantity=0,
                quality=?,production=?,quality_tier=?,defect=?,status='prepared' WHERE id=? AND status='failed']],
                values = { payload.identifier, payload.itemId, units, metadata.quality or 0,
                    metadata.productionScore or 0, metadata.tier or 'standard', metadata.defect or '', cargoId } },
            { query = [[UPDATE sf_field_outbox SET identifier=?,status='prepared',payload=?,attempts=0,last_error=NULL
                WHERE id=? AND status='failed']], values = { payload.identifier, encode(payload), outboxId } },
        }
    else
        queries = {
        { query = [[INSERT INTO sf_company_cargo
            (id,reference,company_id,field_id,work_id,crop_id,custodian_identifier,item_id,quantity,quality,production,quality_tier,defect,status)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,'prepared')]], values = { cargoId, nextReference('CGO'), access.companyId,
            access.fieldId, access.work.id, record.id, payload.identifier, payload.itemId, units,
            metadata.quality or 0, metadata.productionScore or 0, metadata.tier or 'standard', metadata.defect or '' } },
        { query = [[INSERT INTO sf_field_outbox
            (id,company_id,identifier,kind,idempotency_key,status,payload) VALUES (?,?,?,'cargo_harvest',?,'prepared',?)]],
            values = { outboxId, access.companyId, payload.identifier, 'cargo-harvest:' .. record.id, encode(payload) } },
        }
    end
    local ok = MySQL.transaction.await(queries)
    return ok and { cargoId = cargoId, outboxId = outboxId, metadata = cargoMetadata } or nil, ok and nil or 'database_error'
end

function Fields.CancelHarvestCargo(prepared)
    if not prepared then return end
    MySQL.transaction.await({
        { query = "UPDATE sf_company_cargo SET status='failed' WHERE id=? AND status='prepared'", values = { prepared.cargoId } },
        { query = "UPDATE sf_field_outbox SET status='failed',last_error='inventory_full' WHERE id=? AND status='prepared'", values = { prepared.outboxId } },
    })
end

function Fields.FinalizeHarvestCargo(prepared)
    if not prepared then return true end
    return MySQL.transaction.await({
        { query = "UPDATE sf_company_cargo SET status='carrying' WHERE id=? AND status='prepared'", values = { prepared.cargoId } },
        { query = "UPDATE sf_field_outbox SET status='completed' WHERE id=? AND status='prepared'", values = { prepared.outboxId } },
    }) == true
end

function Fields.LoadCargo(source)
    if not Config.Features.CompanyCargo then return nil, 'unavailable' end
    local member = Company.GetMembership(source, true)
    local identifier = Bridge.GetIdentifier(source)
    local companyId = member and member.company_id or MySQL.scalar.await([[SELECT company_id FROM sf_company_cargo
        WHERE custodian_identifier=? AND status IN ('carrying','partial_deposit') LIMIT 1]], { identifier })
    if not companyId then return { records = {}, scopeLabel = 'No active Company cargo', warehousePresence = false } end
    local canTeam = member and member.permissionMap['cargo.view_team']
    local rows = MySQL.query.await([[SELECT c.*,f.name field_name FROM sf_company_cargo c
        JOIN sf_fields f ON f.id=c.field_id WHERE c.company_id=? AND c.status IN ('prepared','carrying','partial_deposit','mismatch')
          AND (?=1 OR c.custodian_identifier=?) ORDER BY c.created_at DESC]], { companyId, canTeam and 1 or 0, identifier }) or {}
    local output = {}
    for _, row in ipairs(rows) do output[#output + 1] = { id = row.id, reference = row.reference,
        product = row.item_id, quantity = tonumber(row.quantity) - tonumber(row.deposited_quantity), unit = 'units',
        quality = ('%s · %.0f'):format(row.quality_tier, tonumber(row.quality)), source = row.field_name,
        custodianId = row.custodian_identifier, custodian = row.custodian_identifier, ownership = 'Company',
        linkedKind = 'assignment', linkedId = row.work_id, destination = 'Company Warehouse', status = row.status,
        restriction = 'Use or return only through an authorized Company flow', availableActions = { 'set_route', 'open_work' } } end
    return { records = output, scopeLabel = canTeam and 'Company custody' or 'Your custody', warehousePresence = false }
end

function Fields.DepositCargo(source, cargoId, quantity, operationId)
    if not Config.Features.CompanyCargo then return { ok = false, reason = 'unavailable' } end
    local member = Fields.ActorContext(source)
    if not member or not member.permissionMap['cargo.deposit'] then return { ok = false, reason = 'permission_denied' } end
    quantity = math.floor(tonumber(quantity) or 0)
    if quantity < 1 then return { ok = false, reason = 'invalid_quantity' } end
    operationId = tostring(operationId or '')
    if operationId == '' or #operationId > 100 then return { ok = false, reason = 'invalid_operation' } end
    local identifier = Bridge.GetIdentifier(source)
    local acquired, result = Lock.With('cargo-deposit:' .. tostring(cargoId), function()
        local replay = MySQL.single.await([[SELECT id,status FROM sf_field_outbox
            WHERE company_id=? AND kind='cargo_deposit' AND idempotency_key=? LIMIT 1]],
            { member.company_id, operationId })
        if replay then
            if replay.status == 'completed' then return { ok = true, changed = false, message = 'Cargo deposit already completed.' } end
            if replay.status == 'prepared' then Fields.ProcessOutboxFor(replay.id) end
            local status = MySQL.scalar.await('SELECT status FROM sf_field_outbox WHERE id=?', { replay.id })
            return status == 'completed' and { ok = true, changed = false, message = 'Cargo deposit recovered.' }
                or { ok = false, reason = status == 'reconciliation_required' and status or 'deposit_pending' }
        end
        local cargo = MySQL.single.await([[SELECT * FROM sf_company_cargo WHERE id=? AND company_id=?
            AND custodian_identifier=? AND status IN ('carrying','partial_deposit') LIMIT 1]],
            { cargoId, member.company_id, identifier })
        if not cargo then return { ok = false, reason = 'cargo_unavailable' } end
        local remaining = tonumber(cargo.quantity) - tonumber(cargo.deposited_quantity)
        quantity = math.min(quantity, remaining)
        local metadata = { ownership = 'company', companyId = member.company_id, cargoId = cargo.id }
        local beforeCount = Bridge.Inventory.GetItemCount(source, cargo.item_id, { cargoId = cargo.id })
        if beforeCount < quantity then return { ok = false, reason = 'cargo_mismatch' } end
        local outboxId, payload = Sonar.Utils.Uuid(), { lotId = Sonar.Utils.Uuid(), cargoId = cargo.id,
            companyId = member.company_id, identifier = identifier, itemId = cargo.item_id, quantity = quantity,
            beforeCount = beforeCount, qualityTier = cargo.quality_tier, quality = tonumber(cargo.quality),
            production = tonumber(cargo.production), defect = cargo.defect or '' }
        local reservedOk, reserved = pcall(function() return MySQL.insert.await([[INSERT INTO sf_field_outbox
            (id,company_id,identifier,kind,idempotency_key,status,payload)
            VALUES (?,?,?,'cargo_deposit',?,'prepared',?)]],
            { outboxId, member.company_id, identifier, operationId, encode(payload) }) end)
        if not reservedOk or not reserved then return { ok = false, reason = reservedOk and 'database_error' or 'operation_conflict' } end

        local slots = Bridge.Inventory.GetSlotsWithItem(source, cargo.item_id, metadata, false)
        local removed, left = {}, quantity
        for _, slot in ipairs(slots) do
            if left <= 0 then break end
            local take = math.min(left, tonumber(slot.count) or 0)
            if take > 0 and Bridge.Inventory.RemoveFromSlot(source, cargo.item_id, take, slot.slot, slot.metadata) then
                removed[#removed + 1], left = { slot = slot, count = take }, left - take
            end
        end
        if left > 0 then
            local restored = true
            for _, value in ipairs(removed) do
                restored = Bridge.Inventory.AddItem(source, cargo.item_id, value.count, value.slot.metadata) and restored
            end
            MySQL.update.await([[UPDATE sf_field_outbox SET status=?,last_error=? WHERE id=? AND status='prepared']],
                { restored and 'failed' or 'reconciliation_required', restored and 'cargo_mismatch' or 'cargo_restore_failed', outboxId })
            return { ok = false, reason = restored and 'cargo_mismatch' or 'reconciliation_required' }
        end
        if not Fields.ProcessOutboxFor(outboxId) then return { ok = false, reason = 'deposit_pending' } end
        return { ok = true, changed = true, message = ('Deposited %d Company produce units.'):format(quantity),
            invalidated = { 'companyCargo', 'companyWarehouse' } }
    end)
    return acquired and result or { ok = false, reason = 'already_in_progress' }
end

function Fields.GenerateBuyerOrders(now)
    if not Config.Features.BuyerOrders then return end
    now = now or Sonar.Time.Now()
    for _, template in ipairs(Config.Fields.BuyerOrderTemplates or {}) do
        local window = math.floor(now / math.max(60, tonumber(template.intervalSeconds) or 3600))
        local key = ('%s:%d'):format(template.id, window)
        pcall(function() MySQL.insert.await([[INSERT INTO sf_buyer_orders
            (id,generation_key,template_id,buyer,item_id,quantity,minimum_quality,payout_cents,destination,status,deadline_at)
            VALUES (?,?,?,?,?,?,?,?,?,'open',?)]], { Sonar.Utils.Uuid(), key, template.id, template.buyer,
            template.product, template.quantity, template.minimumQuality, cents(template.payout),
            encode(template.destination), now + template.deadlineSeconds }) end)
    end
end

function Fields.ExpireBuyerOrders(now)
    if not Config.Features.BuyerOrders then return end
    now = now or Sonar.Time.Now()
    for _, order in ipairs(MySQL.query.await([[SELECT id FROM sf_buyer_orders
        WHERE deadline_at<=? AND status IN ('open','accepted','planned','reserved','ready') LIMIT 50]], { now }) or {}) do
        Lock.With('company-finance', function()
            local reservations = MySQL.query.await([[SELECT lot_id,quantity FROM sf_produce_reservations
                WHERE order_id=? AND status='active']], { order.id }) or {}
            local queries = {}
            for _, reservation in ipairs(reservations) do
                queries[#queries + 1] = { query = [[UPDATE sf_warehouse_produce_lots
                    SET reserved_quantity=GREATEST(0,reserved_quantity-?) WHERE id=?]],
                    values = { reservation.quantity, reservation.lot_id } }
                queries[#queries + 1] = { query = "UPDATE sf_produce_reservations SET status='released' WHERE order_id=? AND lot_id=? AND status='active'",
                    values = { order.id, reservation.lot_id } }
            end
            queries[#queries + 1] = { query = [[UPDATE sf_buyer_orders SET status='expired'
                WHERE id=? AND deadline_at<=? AND status IN ('open','accepted','planned','reserved','ready')]],
                values = { order.id, now } }
            MySQL.transaction.await(queries)
        end)
    end
end

function Fields.LoadBuyerOrder(source, orderId)
    if not Config.Features.BuyerOrders then return nil, 'unavailable' end
    local member = membership(source, 'buyer_orders.view')
    local row = member and MySQL.single.await([[SELECT * FROM sf_buyer_orders WHERE id=?
        AND (company_id IS NULL OR company_id=?) LIMIT 1]], { orderId, member.company_id })
    if not row then return nil, 'permission_denied' end
    return { id = row.id, reference = row.generation_key, buyer = row.buyer, buyerType = 'Scheduled NPC buyer',
        product = row.item_id, quantity = tonumber(row.quantity), unit = 'units', quality = ('≥ %.0f'):format(tonumber(row.minimum_quality)),
        status = row.status, statusLabel = row.status:gsub('_', ' '), deadline = iso(row.deadline_at),
        destination = decode(row.destination).label or 'Configured buyer destination', payout = dollars(row.payout_cents),
        reservedQuantity = tonumber(MySQL.scalar.await([[SELECT COALESCE(SUM(r.quantity),0) FROM sf_produce_reservations r
            WHERE r.order_id=? AND r.status='active']], { row.id })) or 0,
        fulfillment = 'Warehouse produce only', cargoOwnership = 'Company', linkedAssignments = {}, terms = {
            'Minimum quality is authoritative', 'Stock is reserved before physical delivery' },
        availableActions = row.status == 'open' and { 'accept' }
            or row.status == 'accepted' and { 'plan', 'reserve' }
            or row.status == 'planned' and { 'create_assignment', 'reserve' }
            or row.status == 'reserved' and { 'prepare' }
            or row.status == 'ready' and { 'complete' } or {} }
end

function Fields.TransitionBuyerOrder(source, orderId, action)
    if not Config.Features.BuyerOrders then return { ok = false, reason = 'unavailable' } end
    local member = membership(source, 'buyer_orders.manage')
    if not member then return { ok = false, reason = 'permission_denied' } end
    local acquired, result = Lock.With('company-finance', function()
        local order = MySQL.single.await('SELECT * FROM sf_buyer_orders WHERE id=? LIMIT 1', { orderId })
        if not order or order.deadline_at <= Sonar.Time.Now() then return { ok = false, reason = 'order_expired' } end
        if action == 'accept' and order.status == 'open' then
            local changed = MySQL.update.await([[UPDATE sf_buyer_orders SET company_id=?,accepted_by=?,status='accepted'
                WHERE id=? AND status='open' AND company_id IS NULL]], { member.company_id, member.identifier, orderId })
            return tonumber(changed) == 1 and { ok = true, changed = true, message = 'Buyer Order accepted.' } or { ok = false, reason = 'stale_state' }
        end
        if order.company_id ~= member.company_id then return { ok = false, reason = 'permission_denied' } end
        if action == 'plan' and order.status == 'accepted' then
            MySQL.update.await("UPDATE sf_buyer_orders SET status='planned' WHERE id=? AND status='accepted'", { orderId })
            return { ok = true, changed = true, message = 'Buyer Order is ready for linked Work.' }
        end
        if action == 'reserve' and contains({ 'accepted', 'planned' }, order.status) then
            local needed, queries = tonumber(order.quantity), {}
            local lots = MySQL.query.await([[SELECT * FROM sf_warehouse_produce_lots WHERE company_id=? AND item_id=?
                AND quality>=? AND quantity>reserved_quantity ORDER BY quality DESC,created_at]],
                { member.company_id, order.item_id, order.minimum_quality }) or {}
            for _, lot in ipairs(lots) do
                if needed <= 0 then break end
                local quantity = math.min(needed, tonumber(lot.quantity) - tonumber(lot.reserved_quantity))
                if quantity > 0 then
                    queries[#queries + 1] = { query = [[UPDATE sf_warehouse_produce_lots
                        SET reserved_quantity=reserved_quantity+? WHERE id=? AND quantity-reserved_quantity>=?]],
                        values = { quantity, lot.id, quantity } }
                    queries[#queries + 1] = { query = [[INSERT INTO sf_produce_reservations
                        (id,order_id,lot_id,quantity,status) VALUES (?,?,?,?,'active')]],
                        values = { Sonar.Utils.Uuid(), orderId, lot.id, quantity } }
                    needed = needed - quantity
                end
            end
            if needed > 0 then return { ok = false, reason = 'stock_insufficient' } end
            queries[#queries + 1] = { query = "UPDATE sf_buyer_orders SET status='reserved' WHERE id=?", values = { orderId } }
            if not MySQL.transaction.await(queries) then return { ok = false, reason = 'stock_changed' } end
            return { ok = true, changed = true, message = 'Quality-matched Warehouse stock reserved.' }
        end
        if action == 'prepare' and order.status == 'reserved' then
            MySQL.update.await("UPDATE sf_buyer_orders SET status='ready' WHERE id=? AND status='reserved'", { orderId })
            return { ok = true, changed = true, message = 'Order prepared for physical delivery.' }
        end
        if action == 'complete' and order.status == 'ready' then
            local destination = decode(order.destination)
            local coords = Validation.GetPlayerCoords(source)
            if not coords or not destination.coords or not Sonar.Utils.IsWithin(coords, destination.coords, Config.Fields.InteractionDistance) then
                return { ok = false, reason = 'too_far', message = 'Travel to the configured buyer destination.' }
            end
            local reservations = MySQL.query.await([[SELECT r.*,l.quantity lot_quantity,l.reserved_quantity
                FROM sf_produce_reservations r JOIN sf_warehouse_produce_lots l ON l.id=r.lot_id
                WHERE r.order_id=? AND r.status='active']], { orderId }) or {}
            local reservedTotal = 0
            for _, reservation in ipairs(reservations) do reservedTotal = reservedTotal + tonumber(reservation.quantity) end
            if reservedTotal ~= tonumber(order.quantity) then return { ok = false, reason = 'reservation_mismatch' } end
            local queries = {}
            for _, reservation in ipairs(reservations) do
                queries[#queries + 1] = { query = [[UPDATE sf_warehouse_produce_lots SET quantity=quantity-?,
                    reserved_quantity=reserved_quantity-? WHERE id=? AND quantity>=? AND reserved_quantity>=?]],
                    values = { reservation.quantity, reservation.quantity, reservation.lot_id, reservation.quantity, reservation.quantity } }
                queries[#queries + 1] = { query = "UPDATE sf_produce_reservations SET status='completed' WHERE id=?", values = { reservation.id } }
            end
            local company = MySQL.single.await('SELECT treasury_cents FROM sf_companies WHERE id=?', { member.company_id })
            local payout, ledgerId = tonumber(order.payout_cents), Sonar.Utils.Uuid()
            queries[#queries + 1] = { query = 'UPDATE sf_companies SET treasury_cents=treasury_cents+? WHERE id=?', values = { payout, member.company_id } }
            queries[#queries + 1] = { query = "UPDATE sf_buyer_orders SET status='completed' WHERE id=? AND status='ready'", values = { orderId } }
            queries[#queries + 1] = { query = [[INSERT INTO sf_company_ledger
                (id,company_id,idempotency_key,entry_type,direction,amount_cents,balance_after_cents,actor_identifier,linked_kind,linked_id)
                VALUES (?,?,?,?,?,?,?,?,?,?)]], values = { ledgerId, member.company_id, 'buyer-order:' .. orderId,
                'buyer_order', 'credit', payout, tonumber(company.treasury_cents) + payout,
                member.identifier, 'buyer_order', orderId } }
            if not MySQL.transaction.await(queries) then return { ok = false, reason = 'delivery_failed' } end
            return { ok = true, changed = true, message = 'Buyer Order delivered and Treasury credited.' }
        end
        return { ok = false, reason = 'stale_state' }
    end)
    return acquired and result or { ok = false, reason = 'already_in_progress' }
end

function Fields.BroadcastInvalidate(fieldId, reason)
    local field = active[fieldId]
    if not field then return end
    for source, subscription in pairs(subscribers) do
        if subscription.fieldId == fieldId then TriggerClientEvent('sonar_farm:fieldDelta', source, {
            kind = 'invalidate', fieldId = fieldId, topologyRevision = field.topologyRevision,
            sequence = field.sequence, reason = reason }) end
    end
end

function Fields.Subscribe(source, fieldId, afterSequence)
    if not Config.Features.Fields then subscribers[source] = nil; return false end
    if not fieldId or fieldId == '' then subscribers[source] = nil; return true end
    local member = Fields.ActorContext(source)
    local field = active[fieldId]
    if not member or not field or not owns(member.company_id, fieldId) then return false end
    local scopes = actorFieldScopes(source, member)
    if scopes and not scopes[fieldId] then return false end
    subscribers[source] = { fieldId = fieldId, afterSequence = tonumber(afterSequence) or 0 }
    return true
end

function Fields.Unsubscribe(source) subscribers[source] = nil end
AddEventHandler('playerDropped', function() Fields.Unsubscribe(source) end)

RegisterCommand('farmfield', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, Config.Fields.Ace) then return end
    local action = tostring(args[1] or ''):lower()
    if action == 'reload' then
        local ok = Fields.ImportSeeds() and Fields.Reload()
        if source > 0 then Bridge.Notify(source, ok and 'Field catalogue reloaded.' or 'Field reload failed.', ok and 'success' or 'error') end
    elseif action == 'activate' then
        local ok, reason = Fields.ActivateRevision(source, tostring(args[2] or ''), tostring(args[3] or ''))
        if source > 0 then Bridge.Notify(source, ok and 'Field revision activated.' or ('Activation failed: ' .. tostring(reason)), ok and 'success' or 'error') end
    elseif source > 0 then Bridge.Notify(source, 'Usage: /farmfield reload | activate <fieldId> <revisionId>', 'inform') end
end, false)
