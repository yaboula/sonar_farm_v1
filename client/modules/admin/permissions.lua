-- sonar_farm - Client entry gate for developer/admin tools.

Admin = Admin or {}

function Admin.RequireAuthorization()
    if not Config.Debug then
        Bridge.Notify('Developer tools are disabled.', Sonar.Constants.NOTIFY.ERROR)
        return false
    end

    local allowed = lib.callback.await(Sonar.Constants.CALLBACKS.ADMIN_AUTHORIZED, false)
    if not allowed then
        Bridge.Notify('You are not authorized to use farming developer tools.', Sonar.Constants.NOTIFY.ERROR)
        return false
    end

    return true
end
