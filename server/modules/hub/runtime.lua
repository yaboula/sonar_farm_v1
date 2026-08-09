-- Secure NUI session and dispatch boundary for the Business Hub.

HubRuntime = HubRuntime or {}
local sessions = {}
local CALLBACKS = Sonar.Constants.CALLBACKS

local function distanceAllowed(source, configured)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return false end
    return Sonar.Utils.IsWithin(GetEntityCoords(ped), configured.coords,
        Config.Supplies.InteractionDistance + (configured.radius or 0))
end

local function capabilities(member, surface, presence)
    local permission = member.permissionMap
    return {
        routes = { 'supplies', 'company' }, viewPrivateCompany = true,
        viewFinancials = permission['supplies.view_ledger'] == true,
        manageStaff = false, manageOperations = false,
        companyProcurement = permission['supplies.request'] == true,
        physicalTransactions = surface == 'office' and presence == 'office',
        viewOwnAssignments = false, viewTeamAssignments = false, createAssignments = false,
        manageBuyerOrders = false, browsePublicContracts = false, managePublicContracts = false, viewActiveContract = false,
        buyPersonalSupplies = false, buyCompanySupplies = permission['supplies.request'] == true,
        approveProcurement = permission['supplies.approve'] == true,
        manageIssuedMaterials = permission['warehouse.return'] == true,
        viewFieldPortfolio = false, viewAssignedFieldDetail = false, viewTeamFieldDetail = false,
        viewFieldEconomics = false, viewFieldMaterialDemand = false, viewFieldHistory = false,
        createCropPlans = false, createFieldAssignments = false, createFieldContracts = false, setFieldRoute = false,
        viewCompanyProfile = false, viewOwnCompanyCargo = false, viewTeamCompanyCargo = false,
        viewWarehouse = permission['warehouse.view'] == true,
        manageWarehouse = permission['warehouse.withdraw'] == true and presence == 'warehouse',
        sellWholesaleStock = false, viewStaff = false, reviewApplications = false, inviteStaff = false,
        viewProcurementLedger = permission['supplies.view_ledger'] == true,
        viewTreasury = permission['supplies.view_ledger'] == true, contributeTreasury = false,
        viewCompanyLedger = permission['supplies.view_ledger'] == true,
        viewLeases = false, manageLeases = false, manageRolePolicies = false, renameCompany = false,
        sellBusiness = false, buyBusiness = false,
    }
end

local function sessionContext(source, session, member)
    return {
        actorId = member.identifier, role = member.role_key, surface = session.surface,
        presence = session.presence, capabilitiesRevision = 1, viewState = 'ready',
        capabilities = capabilities(member, session.surface, session.presence), nonce = session.nonce,
        company = { id = member.company_id, name = member.company_name },
    }
end

function HubRuntime.Validate(source, nonce, presence)
    local session = sessions[source]
    if not session or session.nonce ~= nonce then return nil, 'invalid_session' end
    if session.expiresAt <= Sonar.Time.Now() then sessions[source] = nil; return nil, 'session_expired' end
    if presence and session.presence ~= presence then return nil, 'wrong_surface' end
    if presence == 'office' and not distanceAllowed(source, Config.Supplies.Office) then return nil, 'too_far' end
    if presence == 'warehouse' and not distanceAllowed(source, Config.Supplies.Warehouse) then return nil, 'too_far' end
    session.expiresAt = Sonar.Time.Now() + Config.Supplies.SessionTtlSeconds
    return session
end

lib.callback.register(CALLBACKS.HUB_OPEN, function(source, payload)
    if not Supplies.IsEnabled() then return { ok = false, reason = 'unavailable' } end
    local guarded = Runtime.GuardPlayer(source)
    if not guarded.ok then return guarded end
    payload = payload or {}
    local surface = payload.surface == 'tablet' and 'tablet' or 'office'
    local presence = surface == 'tablet' and 'remote' or tostring(payload.presence or 'office')
    if surface == 'office' then
        local point = presence == 'warehouse' and Config.Supplies.Warehouse or Config.Supplies.Office
        if not distanceAllowed(source, point) then return { ok = false, reason = 'too_far' } end
    end
    local allowed, member = Company.HasPermission(source, 'supplies.view', true)
    if not allowed then return { ok = false, reason = 'permission_denied' } end
    local session = { nonce = Sonar.Utils.Uuid(), surface = surface, presence = presence,
        expiresAt = Sonar.Time.Now() + Config.Supplies.SessionTtlSeconds }
    sessions[source] = session
    return { ok = true, data = sessionContext(source, session, member) }
end)

lib.callback.register(CALLBACKS.HUB_LOAD, function(source, payload)
    payload = payload or {}
    local session, reason = HubRuntime.Validate(source, payload.nonce)
    if not session then return { ok = false, reason = reason } end
    local request = payload.request or {}
    local data, dataReason
    if request.kind == 'hub' and request.route == 'supplies' then data, dataReason = Supplies.LoadHub(source)
    elseif request.kind == 'purchaseReview' then data, dataReason = Supplies.LoadPurchase(source, request.purchaseId)
    elseif request.kind == 'companyWarehouse' then
        data, dataReason = Supplies.LoadWarehouse(source)
        if data then data.atWarehouse = session.presence == 'warehouse' end
    elseif request.kind == 'companyHome' then data, dataReason = Supplies.LoadCompanyHome(source)
    elseif request.kind == 'companyTreasury' then data, dataReason = Supplies.LoadTreasury(source)
    elseif request.kind == 'companyLedger' then data, dataReason = Supplies.LoadLedger(source)
    else
        return { ok = true, data = { request = request, state = 'unavailable', data = nil } }
    end
    if not data then return { ok = true, data = { request = request, state = dataReason == 'permission_denied' and 'restricted' or 'unavailable', data = nil } } end
    return { ok = true, data = { request = request, state = 'ready', data = data } }
end)

lib.callback.register(CALLBACKS.HUB_DISPATCH, function(source, payload)
    payload = payload or {}
    local session, reason = HubRuntime.Validate(source, payload.nonce)
    if not session then return { ok = false, reason = reason, message = 'The Hub session expired.' } end
    local intent = payload.intent or {}
    if intent.type == 'purchase.createDraft' then
        if intent.payer ~= 'company' then return { ok = false, message = 'Company Treasury is the only supported payer.' } end
        return Supplies.CreateDraft(source, intent.lines)
    elseif intent.type == 'procurement.resolve' then
        return Supplies.Approve(source, intent.requestId, intent.decision)
    elseif intent.type == 'purchase.confirm' then
        local valid, presenceReason = HubRuntime.Validate(source, payload.nonce, 'office')
        if not valid or session.surface ~= 'office' then return { ok = false, reason = presenceReason or 'wrong_surface', closeSurface = true, message = 'Office Terminal presence is required.' } end
        return Supplies.Confirm(source, intent.purchaseId)
    elseif intent.type == 'warehouse.withdraw' then
        local valid, presenceReason = HubRuntime.Validate(source, payload.nonce, 'warehouse')
        if not valid or session.surface ~= 'office' then return { ok = false, reason = presenceReason or 'wrong_surface', message = 'Physical Warehouse presence is required.' } end
        return Supplies.Withdraw(source, intent.itemId, intent.quantity, intent.operationId)
    elseif intent.type == 'issuedMaterial.transition' and intent.action == 'return' then
        local valid, presenceReason = HubRuntime.Validate(source, payload.nonce, 'warehouse')
        if not valid or session.surface ~= 'office' then return { ok = false, reason = presenceReason or 'wrong_surface', message = 'Return materials at the physical Warehouse.' } end
        return Supplies.Return(source, intent.materialId, intent.operationId)
    elseif intent.type == 'company.setRoute' then
        return { ok = true, changed = false, closeSurface = true, message = 'Route marker requested.' }
    end
    return { ok = false, message = 'This area is unavailable in the authoritative runtime.' }
end)

lib.callback.register(CALLBACKS.HUB_CLOSE, function(source, payload)
    if not payload or sessions[source] and sessions[source].nonce == payload.nonce then sessions[source] = nil end
    return { ok = true }
end)

AddEventHandler('playerDropped', function() sessions[source] = nil end)
