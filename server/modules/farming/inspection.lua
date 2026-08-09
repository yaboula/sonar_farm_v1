-- Authoritative read gate for the crop inspection HUD.

local CALLBACKS = Sonar.Constants.CALLBACKS
local REJECT = Sonar.Constants.REJECT

lib.callback.register(CALLBACKS.INSPECT, function(source, request)
    local runtime = Runtime.GuardPlayer(source)
    if not runtime.ok then return runtime end
    if not Security.Consume(source, 1, 'inspection') then
        return { ok = false, reason = REJECT.RATE_LIMITED }
    end

    local cropId = request and request.cropId
    if type(cropId) ~= 'string' then return { ok = false, reason = REJECT.CROP_NOT_FOUND } end
    local record = State.Get(cropId)
    if not record then return { ok = false, reason = REJECT.CROP_NOT_FOUND } end
    local distance = Validation.Distance(source, {
        x = record.pos_x,
        y = record.pos_y,
        z = record.pos_z,
    })
    if not distance.ok then return distance end

    local now = Sonar.Time.Now()
    return {
        ok = true,
        serverTime = now,
        crop = Sync.RenderPayload(record, runtime.identifier),
    }
end)
