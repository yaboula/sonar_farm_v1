-- Secure NUI session and authoritative Business Hub dispatch boundary.

HubRuntime = HubRuntime or {}
local sessions = {}
local CALLBACKS = Sonar.Constants.CALLBACKS

local function distanceAllowed(source, configured)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return false end
    return Sonar.Utils.IsWithin(GetEntityCoords(ped), configured.coords,
        Config.Supplies.InteractionDistance + (configured.radius or 0))
end

local function capabilities(actor, surface, presence)
    local permission = actor.permissionMap or {}
    local routes = {}
    if Config.Features.Fields and (permission['fields.view_portfolio'] or permission['fields.view_assigned']) then routes[#routes + 1] = 'fields' end
    if Config.Features.Work or Config.Features.PublicContracts then
        if permission['work.view_own'] or permission['work.view_team'] or permission['contracts.browse'] then routes[#routes + 1] = 'work' end
    end
    if Config.Features.Supplies and permission['supplies.view'] then routes[#routes + 1] = 'supplies' end
    if actor.company_id then routes[#routes + 1] = 'company' end
    return {
        routes = routes, viewPrivateCompany = actor.company_id ~= nil and actor.role_key ~= 'contractor',
        viewFinancials = permission['supplies.view_ledger'] == true,
        manageStaff = false, manageOperations = permission['work.create'] == true,
        companyProcurement = permission['supplies.request'] == true,
        physicalTransactions = surface == 'office' and presence == 'office',
        viewOwnAssignments = permission['work.view_own'] == true,
        viewTeamAssignments = permission['work.view_team'] == true,
        createAssignments = Config.Features.Work and permission['work.create'] == true,
        manageBuyerOrders = Config.Features.BuyerOrders and permission['buyer_orders.manage'] == true,
        browsePublicContracts = Config.Features.PublicContracts and permission['contracts.browse'] == true,
        managePublicContracts = Config.Features.PublicContracts and permission['contracts.create'] == true,
        viewActiveContract = actor.role_key == 'contractor', buyPersonalSupplies = false,
        buyCompanySupplies = Config.Features.Supplies and permission['supplies.request'] == true,
        approveProcurement = permission['supplies.approve'] == true,
        manageIssuedMaterials = permission['warehouse.return'] == true,
        viewFieldPortfolio = Config.Features.Fields and permission['fields.view_portfolio'] == true,
        viewAssignedFieldDetail = Config.Features.Fields and permission['fields.view_assigned'] == true,
        viewTeamFieldDetail = permission['fields.view_team'] == true,
        viewFieldEconomics = permission['fields.view_economics'] == true,
        viewFieldMaterialDemand = permission['fields.view_materials'] == true,
        viewFieldHistory = permission['fields.view_history'] == true,
        createCropPlans = Config.Features.Work and permission['fields.plan'] == true,
        createFieldAssignments = Config.Features.Work and permission['work.create'] == true,
        createFieldContracts = Config.Features.PublicContracts and permission['contracts.create'] == true,
        setFieldRoute = permission['fields.route'] == true,
        viewCompanyProfile = actor.company_id ~= nil,
        viewOwnCompanyCargo = Config.Features.CompanyCargo and permission['cargo.view_own'] == true,
        viewTeamCompanyCargo = Config.Features.CompanyCargo and permission['cargo.view_team'] == true,
        viewWarehouse = permission['warehouse.view'] == true,
        manageWarehouse = permission['warehouse.withdraw'] == true and presence == 'warehouse',
        sellWholesaleStock = false, viewStaff = false, reviewApplications = false, inviteStaff = false,
        viewProcurementLedger = permission['supplies.view_ledger'] == true,
        viewTreasury = permission['supplies.view_ledger'] == true, contributeTreasury = false,
        viewCompanyLedger = permission['supplies.view_ledger'] == true,
        viewLeases = Config.Features.Fields and permission['fields.view_portfolio'] == true,
        manageLeases = Config.Features.Fields and permission['fields.acquire'] == true,
        manageRolePolicies = false, renameCompany = false, sellBusiness = false, buyBusiness = false,
    }
end

local function sessionContext(session, actor)
    return { actorId = actor.identifier, role = actor.role_key, surface = session.surface,
        presence = session.presence, capabilitiesRevision = 2, viewState = 'ready',
        capabilities = capabilities(actor, session.surface, session.presence), nonce = session.nonce,
        serverTime = Sonar.Time.Now(),
        company = actor.company_id and { id = actor.company_id, name = actor.company_name } or nil }
end

function HubRuntime.Validate(source, nonce, presence)
    local session = sessions[source]
    if not session or session.nonce ~= nonce then return nil, 'invalid_session' end
    if session.expiresAt <= Sonar.Time.Now() then sessions[source] = nil; Fields.Unsubscribe(source); return nil, 'session_expired' end
    if presence and session.presence ~= presence then return nil, 'wrong_surface' end
    if presence == 'office' and not distanceAllowed(source, Config.Supplies.Office) then return nil, 'too_far' end
    if presence == 'warehouse' and not distanceAllowed(source, Config.Supplies.Warehouse) then return nil, 'too_far' end
    session.expiresAt = Sonar.Time.Now() + Config.Supplies.SessionTtlSeconds
    return session
end

lib.callback.register(CALLBACKS.HUB_OPEN, function(source, payload)
    local guarded = Runtime.GuardPlayer(source)
    if not guarded.ok then return guarded end
    local actor = Fields.ActorContext(source)
    if not actor then return { ok = false, reason = 'permission_denied' } end
    payload = payload or {}
    local surface = payload.surface == 'tablet' and 'tablet' or 'office'
    local presence = surface == 'tablet' and 'remote' or tostring(payload.presence or 'office')
    if surface == 'office' then
        local point = presence == 'warehouse' and Config.Supplies.Warehouse or Config.Supplies.Office
        if not distanceAllowed(source, point) then return { ok = false, reason = 'too_far' } end
    end
    local session = { nonce = Sonar.Utils.Uuid(), surface = surface, presence = presence,
        expiresAt = Sonar.Time.Now() + Config.Supplies.SessionTtlSeconds, actorId = actor.identifier }
    sessions[source] = session
    return { ok = true, data = sessionContext(session, actor) }
end)

lib.callback.register(CALLBACKS.HUB_LOAD, function(source, payload)
    payload = payload or {}
    local session, reason = HubRuntime.Validate(source, payload.nonce)
    if not session then return { ok = false, reason = reason } end
    local request, data, dataReason = payload.request or {}
    if request.kind == 'hub' and request.route == 'supplies' then data, dataReason = Supplies.LoadHub(source)
    elseif request.kind == 'hub' and request.route == 'fields' or request.kind == 'fieldsOverview' then data, dataReason = Fields.LoadOverview(source)
    elseif request.kind == 'fieldDetail' then data, dataReason = Fields.LoadDetail(source, request.fieldId)
    elseif request.kind == 'hub' and request.route == 'work' then data, dataReason = Fields.LoadWorkQueue(source)
    elseif request.kind == 'assignmentDetail' or request.kind == 'contractDetail' then data, dataReason = Fields.LoadWorkDetail(source, request.assignmentId or request.contractId)
    elseif request.kind == 'assignmentCreate' then data, dataReason = Fields.LoadWorkCreate(source, 'assignment')
    elseif request.kind == 'contractCreate' then data, dataReason = Fields.LoadWorkCreate(source, 'contract')
    elseif request.kind == 'buyerOrderDetail' then data, dataReason = Fields.LoadBuyerOrder(source, request.orderId)
    elseif request.kind == 'purchaseReview' then data, dataReason = Supplies.LoadPurchase(source, request.purchaseId)
    elseif request.kind == 'companyWarehouse' then
        data, dataReason = Supplies.LoadWarehouse(source)
        if data then data.atWarehouse = session.presence == 'warehouse' end
    elseif request.kind == 'companyHome' then data, dataReason = Supplies.LoadCompanyHome(source)
    elseif request.kind == 'companyTreasury' then data, dataReason = Supplies.LoadTreasury(source)
    elseif request.kind == 'companyLedger' then data, dataReason = Supplies.LoadLedger(source)
    elseif request.kind == 'companyCargo' then data, dataReason = Fields.LoadCargo(source)
    elseif request.kind == 'companyLeases' then data, dataReason = Fields.LoadLand(source)
    elseif request.kind == 'companyLeaseDetail' then data, dataReason = Fields.LoadLandDetail(source, request.leaseId)
    else return { ok = true, data = { request = request, state = 'unavailable', data = nil } } end
    if not data then return { ok = true, data = { request = request,
        state = dataReason == 'permission_denied' and 'restricted' or 'unavailable', data = nil } } end
    return { ok = true, data = { request = request, state = 'ready', data = data } }
end)

lib.callback.register(CALLBACKS.HUB_DISPATCH, function(source, payload)
    payload = payload or {}
    local session, reason = HubRuntime.Validate(source, payload.nonce)
    if not session then return { ok = false, reason = reason, message = 'The Hub session expired.' } end
    local intent = payload.intent or {}
    if intent.type == 'cropPlan.create' then return Fields.CreatePlan(source, intent.input)
    elseif intent.type == 'cropPlan.update' then return Fields.UpdatePlan(source, intent.planId, intent.input)
    elseif intent.type == 'cropPlan.cancel' then return Fields.CancelPlan(source, intent.planId)
    elseif intent.type == 'assignment.create' then return Fields.CreateWork(source, 'assignment', intent.input)
    elseif intent.type == 'contract.create' then return Fields.CreateWork(source, 'contract', intent.input)
    elseif intent.type == 'contract.accept' then return Fields.AcceptContract(source, intent.contractId)
    elseif intent.type == 'assignment.accept' then return Fields.StartAssignment(source, intent.assignmentId)
    elseif intent.type == 'assignment.resume' then return Fields.ResumeWork(source, intent.assignmentId)
    elseif intent.type == 'contract.transition' and intent.action == 'publish' then return Fields.PublishContract(source, intent.contractId)
    elseif intent.type == 'contract.transition' and intent.action == 'submit' then return Fields.SubmitWork(source, intent.contractId)
    elseif intent.type == 'contract.transition' and intent.action == 'complete' then return Fields.ReviewWork(source, intent.contractId, true, intent.note)
    elseif intent.type == 'contract.transition' and intent.action == 'abandon' then return Fields.CancelWork(source, intent.contractId, intent.note, true)
    elseif intent.type == 'contract.transition' and intent.action == 'cancel' then return Fields.CancelWork(source, intent.contractId, intent.note, false)
    elseif intent.type == 'contract.transition' and intent.action == 'set_route_field' then return Fields.ResumeWork(source, intent.contractId)
    elseif intent.type == 'buyerOrder.transition' then return Fields.TransitionBuyerOrder(source, intent.orderId, intent.action)
    elseif intent.type == 'assignment.submit' then return Fields.SubmitWork(source, intent.assignmentId)
    elseif intent.type == 'assignment.approve' then return Fields.ReviewWork(source, intent.assignmentId, true, intent.note)
    elseif intent.type == 'assignment.requestCorrection' then return Fields.ReviewWork(source, intent.assignmentId, false, intent.note)
    elseif intent.type == 'assignment.reassign' then return Fields.ReassignAssignment(source, intent.assignmentId, intent.assigneeId)
    elseif intent.type == 'assignment.cancel' then return Fields.CancelWork(source, intent.assignmentId, intent.reason, false)
    elseif intent.type == 'field.purchase' then
        local valid, presenceReason = HubRuntime.Validate(source, payload.nonce, 'office')
        if not valid or session.surface ~= 'office' then return { ok = false, reason = presenceReason or 'wrong_surface', message = 'Office presence is required.' } end
        return Fields.Purchase(source, intent.fieldId, intent.operationId)
    elseif intent.type == 'field.preparePurchase' then
        return Fields.PreparePurchase(source, intent.fieldId)
    elseif intent.type == 'field.setRoute' then
        local field = Fields.Get(intent.scope and intent.scope.fieldId)
        local detail = field and Fields.LoadDetail(source, field.id) or nil
        if not field or not detail then return { ok = false, reason = 'field_unavailable' } end
        if detail.permittedRowIds and intent.scope.rowIds then
            local allowed = {}; for _, rowId in ipairs(detail.permittedRowIds) do allowed[rowId] = true end
            for _, rowId in ipairs(intent.scope.rowIds) do
                if not allowed[rowId] then return { ok = false, reason = 'permission_denied' } end
            end
        end
        return { ok = true, changed = false, closeSurface = true, message = 'Field route set.', route = field.access,
            handoff = { kind = 'route', scope = { fieldId = field.id, rowIds = intent.scope.rowIds } } }
    elseif intent.type == 'cargo.deposit' then
        local valid, presenceReason = HubRuntime.Validate(source, payload.nonce, 'warehouse')
        if not valid then return { ok = false, reason = presenceReason } end
        return Fields.DepositCargo(source, intent.cargoId, intent.quantity, intent.operationId)
    elseif intent.type == 'purchase.createDraft' then
        if intent.payer ~= 'company' then return { ok = false, message = 'Company Treasury is the only supported payer.' } end
        return Supplies.CreateDraft(source, intent.lines)
    elseif intent.type == 'procurement.resolve' then return Supplies.Approve(source, intent.requestId, intent.decision)
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
    elseif intent.type == 'company.setRoute' then return { ok = true, closeSurface = true, message = 'Route marker requested.' } end
    return { ok = false, message = 'This action is unavailable in the authoritative runtime.' }
end)

lib.callback.register(CALLBACKS.HUB_SUBSCRIBE_FIELD, function(source, payload)
    payload = payload or {}
    local session, reason = HubRuntime.Validate(source, payload.nonce)
    if not session then return { ok = false, reason = reason } end
    return { ok = Fields.Subscribe(source, tostring(payload.fieldId or ''), payload.afterSequence) }
end)

lib.callback.register(CALLBACKS.HUB_CLOSE, function(source, payload)
    if not payload or sessions[source] and sessions[source].nonce == payload.nonce then sessions[source] = nil end
    Fields.Unsubscribe(source)
    return { ok = true }
end)

AddEventHandler('playerDropped', function() sessions[source] = nil; Fields.Unsubscribe(source) end)
