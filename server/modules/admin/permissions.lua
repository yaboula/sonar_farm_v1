-- sonar_farm - Server-side authorization for developer/admin tools.

Admin = Admin or {}

function Admin.IsAuthorized(source)
    if source == 0 then return true end
    if not Config.Debug then return false end
    return IsPlayerAceAllowed(source, Config.Admin.Ace)
end

lib.callback.register(Sonar.Constants.CALLBACKS.ADMIN_AUTHORIZED, function(source)
    return Admin.IsAuthorized(source)
end)
