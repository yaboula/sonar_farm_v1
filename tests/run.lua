-- sonar_farm - Dependency-free Lua regression suite.

local passed = 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        io.stderr:write(('FAIL %s: %s\n'):format(name, tostring(err)))
        os.exit(1)
    end
    passed = passed + 1
    print(('PASS %s'):format(name))
end

local function equal(actual, expected, message)
    if actual ~= expected then
        error(('%s (expected %s, got %s)'):format(message or 'values differ', tostring(expected), tostring(actual)))
    end
end

-- Minimal FiveM/ox environment used by shared and server-pure modules.
function vec3(x, y, z) return { x = x, y = y, z = z } end
function GetCurrentResourceName() return 'sonar_farm' end
function IsDuplicityVersion() return true end
function GetNetworkTimeAccurate() return os.time() * 1000 end
function AddEventHandler() end
function RegisterCommand() end
function GetPlayerPed() return 1 end
function GetEntityCoords() return vec3(2236.0, 5031.0, 44.2) end
function GetPlayerRoutingBucket() return 0 end

local gameTimer = 1000
function GetGameTimer() return gameTimer end

json = {
    encode = function() return '{}' end,
    decode = function() return {} end,
}

Logger = {
    Info = function() end,
    Warn = function() end,
    Exploit = function() end,
}

Bridge = {
    Ready = true,
    GetIdentifier = function() return 'citizen-test' end,
    GetPlayerName = function() return 'Test Player' end,
    Inventory = {
        HasItem = function() return true end,
        GetSlotsWithItem = function() return {} end,
        SetDurability = function() return true end,
        RemoveFromSlot = function() return true end,
    },
}

dofile('config/config.lua')
dofile('config/crops.lua')
dofile('config/zones.lua')
dofile('config/minigames.lua')
dofile('shared/item_catalog.lua')
dofile('shared/constants.lua')
dofile('shared/utils.lua')
dofile('shared/time.lua')
dofile('shared/conditions.lua')
dofile('shared/growth.lua')
dofile('shared/physiology.lua')
dofile('shared/inspection.lua')
dofile('shared/zones.lua')
dofile('shared/config_validation.lua')
dofile('server/modules/minigames/tomato_plant_scoring.lua')
dofile('server/modules/inventory/items.lua')

test('production config validates', function()
    local errors = Sonar.ConfigValidation.Validate()
    equal(#errors, 0, table.concat(errors, '; '))
end)

test('invalid operational config is rejected', function()
    local ace = Config.Admin.Ace
    local buckets = Config.Security.AllowedRoutingBuckets
    Config.Admin.Ace = ''
    Config.Security.AllowedRoutingBuckets = { -1 }

    local errors = Sonar.ConfigValidation.Validate()
    assert(#errors >= 2, 'admin ACE and routing bucket errors expected')

    Config.Admin.Ace = ace
    Config.Security.AllowedRoutingBuckets = buckets
end)

test('malformed crop config reports an error instead of crashing validation', function()
    local stage = Config.Crops.carrot.stages[1]
    Config.Crops.carrot.stages[1] = 'invalid'

    local ok, errors = pcall(Sonar.ConfigValidation.Validate)
    equal(ok, true, 'validator must not crash')
    assert(#errors > 0, 'malformed crop must be rejected')

    Config.Crops.carrot.stages[1] = stage
end)

test('advanced care config rejects malformed bounds and overrides', function()
    local window = Config.Crops.carrot.criticalWindow
    local effects = Config.Crops.carrot.conditionEffects
    Config.Crops.carrot.criticalWindow = { from = 0.8, to = 0.2 }
    Config.Crops.carrot.conditionEffects = { pests = 'yes', weather = true }
    local errors = Sonar.ConfigValidation.Validate()
    assert(#errors >= 3, 'window, boolean and unsupported override errors expected')
    Config.Crops.carrot.criticalWindow = window
    Config.Crops.carrot.conditionEffects = effects
end)

test('advanced care config rejects incomplete operational effects', function()
    local advanced = Config.Farming.AdvancedCare
    local fertilizer = Sonar.ItemCatalog.byId.fertilizer_organic.consumable.amount
    local treatment = Sonar.ItemCatalog.byId.pest_spray_chemical.consumable.reduction
    local weedRemoval = Sonar.ItemCatalog.byId.hand_hoe.tool.weedRemoval
    local waterPenalty = advanced.GrowthPenaltyPerDeficitHour.water
    local nutrientPenalty = advanced.GrowthPenaltyPerDeficitHour.nutrients

    Sonar.ItemCatalog.byId.fertilizer_organic.consumable.amount = nil
    Sonar.ItemCatalog.byId.pest_spray_chemical.consumable.reduction = nil
    Sonar.ItemCatalog.byId.hand_hoe.tool.weedRemoval = 0
    advanced.GrowthPenaltyPerDeficitHour.water = 0.7
    advanced.GrowthPenaltyPerDeficitHour.nutrients = 0.6

    local errors = Sonar.ConfigValidation.Validate()
    local report = table.concat(errors, '\n')
    assert(report:find('fertilizer_organic', 1, true), 'missing fertilizer effect rejected')
    assert(report:find('pest_spray_chemical', 1, true), 'missing treatment effect rejected')
    assert(report:find('hand_hoe', 1, true), 'ineffective weed removal rejected')
    assert(report:find('sum to at most 1', 1, true), 'growth rates that can reverse progress rejected')

    Sonar.ItemCatalog.byId.fertilizer_organic.consumable.amount = fertilizer
    Sonar.ItemCatalog.byId.pest_spray_chemical.consumable.reduction = treatment
    Sonar.ItemCatalog.byId.hand_hoe.tool.weedRemoval = weedRemoval
    advanced.GrowthPenaltyPerDeficitHour.water = waterPenalty
    advanced.GrowthPenaltyPerDeficitHour.nutrients = nutrientPenalty
end)

test('zone grids and explicit slots resolve', function()
    equal(Sonar.Zones.Count('grapeseed_east'), 40, 'east slot count')
    equal(Sonar.Zones.Count('grapeseed_south'), 24, 'south slot count')
    equal(Sonar.Zones.Count('zone1'), 24, 'explicit slot count')
    equal(Sonar.Zones.Slot('zone1', 1).zone, 'zone1', 'slot zone')
end)

test('growth is timestamp based and clamped', function()
    local record = {
        crop_type = 'carrot',
        planted_at = 1000,
        growth_time = 100,
        data = {},
    }
    equal(Growth.Evaluate(record, 1050).progress, 0.5, 'half growth')
    equal(Growth.Evaluate(record, 1200).state, Sonar.Constants.CROP_STATE.MATURE, 'mature state')
end)

test('physiology derives drought and spoilage without mutation', function()
    local record = {
        crop_type = 'lettuce',
        planted_at = 1000,
        growth_time = 100,
        data = { water = 0, health = 100, spoilage = 0, lastCare = 1000 },
    }
    local condition = Physiology.Evaluate(record, 4600)
    assert(condition.health < 100, 'dry crop should lose health')
    assert(condition.spoilage > 0, 'mature crop should spoil')
    equal(record.data.health, 100, 'evaluation must be pure')
end)

test('incomplete planting never progresses or dries out', function()
    local record = {
        crop_type = 'tomato',
        state = Sonar.Constants.CROP_STATE.PLANTING_FAILED,
        planted_at = 1000,
        growth_time = 100,
        data = { water = 0, health = 100, lastCare = 1000 },
    }
    local condition = Physiology.Evaluate(record, 9999)
    equal(condition.state, Sonar.Constants.CROP_STATE.PLANTING_FAILED, 'incomplete state')
    equal(condition.progress, 0, 'incomplete progress')
    equal(condition.health, 100, 'incomplete health')
end)

test('advanced condition gating respects global and per-crop ceilings', function()
    local enabled = Config.Features.AdvancedCare
    Config.Features.AdvancedCare = true
    equal(Sonar.Conditions.IsEnabled('carrot', 'nutrients'), true, 'configured crop inherits global gate')
    local tomatoEffects = Config.Crops.tomato.conditionEffects
    Config.Crops.tomato.conditionEffects = { weeds = false, pests = false }
    equal(Sonar.Conditions.IsEnabled('tomato', 'weeds'), false, 'crop override narrows global gate')
    Config.Crops.tomato.conditionEffects = tomatoEffects
    local global = Config.Farming.ConditionEffects.Pests
    Config.Farming.ConditionEffects.Pests = false
    equal(Sonar.Conditions.IsEnabled('carrot', 'pests'), false, 'global off and crop unset stays off')
    local override = Config.Crops.carrot.conditionEffects
    Config.Crops.carrot.conditionEffects = { pests = true }
    equal(Sonar.Conditions.IsEnabled('carrot', 'pests'), false, 'crop cannot widen global gate')
    Config.Crops.carrot.conditionEffects = override
    Config.Farming.ConditionEffects.Pests = global
    Config.Features.AdvancedCare = enabled
end)

test('inspection builds real history forecast timing and disabled conditions', function()
    local enabled = Config.Features.AdvancedCare
    local pests = Config.Farming.ConditionEffects.Pests
    Config.Features.AdvancedCare = true
    local record = {
        id = 'inspection-crop', crop_type = 'carrot', zone = 'east', slot = 7,
        planted_at = 1000, growth_time = 900, state = Sonar.Constants.CROP_STATE.GROWING,
        isMine = true,
        data = { lastCare = 1000, water = 44, health = 92, nutrients = 62, weedCover = 38,
            pestPressure = 12, nutrientProtectionTier = 'plus', nutrientProtectionUntil = 1900 },
    }
    local payload = Sonar.Inspection.Build(record, 1600)
    equal(payload.version, 1, 'inspection contract version')
    equal(payload.series.historyStart, 1000, 'history starts at last care')
    equal(payload.series.now, 1600, 'series marks server now')
    equal(payload.series.forecastEnd, 2200, 'forecast uses configured horizon')
    equal(#payload.series.samples, 41, 'thirty-second history and forecast samples')
    equal(payload.subject.stage, 'Root development', 'data-driven stage label')
    assert(payload.timing.readyAt and payload.timing.readyAt > 1600, 'stress-aware ETA resolved')
    equal(payload.metrics[2].protectionTier, 'plus', 'protection tier exposed')

    Config.Farming.ConditionEffects.Pests = false
    local withoutPests = Sonar.Inspection.Build(record, 1600, { includeSeries = false })
    equal(withoutPests.metrics[4].value, 0, 'disabled condition is a real flat zero')
    equal(withoutPests.metrics[4].status, 'unaffected', 'disabled condition is labelled unaffected')
    equal(withoutPests.series, nil, 'lightweight refresh omits series')
    Config.Farming.ConditionEffects.Pests = pests
    Config.Features.AdvancedCare = enabled
end)

test('inspection diagnoses immediate water stress and can report stalled growth', function()
    local enabled = Config.Features.AdvancedCare
    local rates = Config.Farming.AdvancedCare.GrowthPenaltyPerDeficitHour
    Config.Features.AdvancedCare = true
    local record = {
        id = 'stressed-crop', crop_type = 'lettuce', zone = 'east', slot = 8,
        planted_at = 1000, growth_time = 600, state = Sonar.Constants.CROP_STATE.GROWING,
        data = { lastCare = 1000, water = 0, health = 100, nutrients = 0, weedCover = 0, pestPressure = 0 },
    }
    local urgent = Sonar.Inspection.Build(record, 1060, { includeSeries = false })
    equal(urgent.diagnosis.cause, 'water', 'immediate deficit wins deterministic diagnosis')
    Config.Farming.AdvancedCare.GrowthPenaltyPerDeficitHour = { water = 0.5, nutrients = 0.5 }
    local stalled = Sonar.Inspection.Build(record, 1060, { includeSeries = false })
    equal(stalled.timing.readyAt, nil, 'fully stalled crop has no fake ETA')
    Config.Farming.AdvancedCare.GrowthPenaltyPerDeficitHour = rates
    Config.Features.AdvancedCare = enabled
end)

test('inspection callback accepts only crop identity and revalidates authority', function()
    local file = assert(io.open('server/modules/farming/inspection.lua', 'rb'))
    local source = file:read('*a')
    file:close()
    assert(source:find('Runtime.GuardPlayer(source)', 1, true), 'runtime gate')
    assert(source:find("Security.Consume(source, 1, 'inspection')", 1, true), 'inspection rate limit')
    assert(source:find('local cropId = request and request.cropId', 1, true), 'crop id is the only request input')
    assert(source:find('State.Get(cropId)', 1, true), 'authoritative crop lookup')
    assert(source:find('Validation.Distance(source', 1, true), 'server distance validation')
    assert(source:find('Sync.RenderPayload(record, runtime.identifier)', 1, true), 'minimal synchronized snapshot')
    assert(not source:find('request.coords', 1, true), 'client coordinates are never trusted')
end)

test('advanced trajectories are causal and old records stay compatible', function()
    local enabled = Config.Features.AdvancedCare
    Config.Features.AdvancedCare = true
    local base = {
        crop_type = 'carrot', planted_at = 1000, growth_time = 7200,
        data = { water = 100, health = 100, lastCare = 1000 },
    }
    local old = Sonar.Conditions.Evaluate(base, 4600)
    assert(old.nutrients < 100, 'missing nutrient state defaults safely then decays')
    assert(old.weedCover > 0, 'missing weed state defaults safely then grows')

    local clean = {
        crop_type = 'carrot', planted_at = 1000, growth_time = 7200,
        data = { water = 100, nutrients = 100, weedCover = 0, pestPressure = 0, lastCare = 1000 },
    }
    local weedy = {
        crop_type = 'carrot', planted_at = 1000, growth_time = 7200,
        data = { water = 100, nutrients = 100, weedCover = 70, pestPressure = 0, lastCare = 1000 },
    }
    local cleanResult = Sonar.Conditions.Evaluate(clean, 4600)
    local weedyResult = Sonar.Conditions.Evaluate(weedy, 4600)
    assert(weedyResult.water < cleanResult.water, 'weeds accelerate water loss')
    assert(weedyResult.nutrients < cleanResult.nutrients, 'weeds accelerate nutrient loss')
    assert(weedyResult.pestPressure > cleanResult.pestPressure, 'weeds accelerate pest pressure')
    Config.Features.AdvancedCare = enabled
end)

test('sustained deficits slow growth and critical windows amplify stress', function()
    local enabled = Config.Features.AdvancedCare
    Config.Features.AdvancedCare = true
    local stressed = {
        crop_type = 'carrot', planted_at = 1000, growth_time = 3600,
        data = { water = 0, nutrients = 0, weedCover = 0, pestPressure = 0, lastCare = 1000 },
    }
    assert(Growth.Evaluate(stressed, 4600).progress < 1, 'deficit penalty stretches maturation')

    local outside = {
        crop_type = 'carrot', planted_at = 0, growth_time = 10000,
        data = { water = 0, nutrients = 0, weedCover = 0, pestPressure = 0, lastCare = 100 },
    }
    local inside = {
        crop_type = 'carrot', planted_at = 0, growth_time = 10000,
        data = { water = 0, nutrients = 0, weedCover = 0, pestPressure = 0, lastCare = 4000 },
    }
    local outsideResult = Sonar.Conditions.Evaluate(outside, 1100)
    local insideResult = Sonar.Conditions.Evaluate(inside, 5000)
    assert(insideResult.waterStressDelta > outsideResult.waterStressDelta, 'critical window weights equal stress more')
    Config.Features.AdvancedCare = false
    local originalGrowth = Growth.Evaluate(stressed, 4600)
    equal(originalGrowth.progress, 1, 'disabled feature preserves original growth')
    equal(originalGrowth.effectiveElapsed, nil, 'disabled feature preserves original response shape')
    Config.Features.AdvancedCare = enabled
end)

test('neglect never reverses growth and critical windows follow effective progress', function()
    local enabled = Config.Features.AdvancedCare
    Config.Features.AdvancedCare = true
    local delayed = {
        crop_type = 'carrot', planted_at = 0, growth_time = 3600,
        data = { water = 0, nutrients = 0, weedCover = 0, pestPressure = 0,
            growthPenaltyHours = 0, lastCare = 0 },
    }

    local previous = 0
    for now = 300, 7200, 300 do
        local progress = Growth.Evaluate(delayed, now).progress
        assert(progress + 1e-9 >= previous, ('growth reversed at %d seconds'):format(now))
        previous = progress
    end
    assert(previous > 0, 'neglect may stop growth but cannot erase completed growth')

    local rates = Config.Farming.AdvancedCare.GrowthPenaltyPerDeficitHour
    local waterRate, nutrientRate = rates.water, rates.nutrients
    rates.water, rates.nutrients = 2, 3
    previous = 0
    for now = 300, 7200, 300 do
        local progress = Growth.Evaluate(delayed, now).progress
        assert(progress + 1e-9 >= previous, ('runtime safety failed at %d seconds'):format(now))
        previous = progress
    end
    rates.water, rates.nutrients = waterRate, nutrientRate

    local nominallyInside = Sonar.Conditions.Evaluate(delayed, 1800)
    equal(nominallyInside.criticalFactor, 1, 'wall-clock critical window ignored before biological stage')

    local biologicallyInside = {
        crop_type = 'carrot', planted_at = 0, growth_time = 3600,
        data = { water = 0, nutrients = 0, weedCover = 0, pestPressure = 0,
            growthPenaltyHours = 1.4, lastCare = 6300 },
    }
    local actualWindow = Sonar.Conditions.Evaluate(biologicallyInside, 7200)
    equal(actualWindow.criticalFactor, Config.Farming.AdvancedCare.CriticalStressMultiplier,
        'delayed crop receives critical stress only at effective critical progress')
    Config.Features.AdvancedCare = enabled
end)

test('tomato planting traces are bounded and scored deterministically', function()
    local cfg = Config.Minigames.Plant.tomato
    local prepare = { durationMs = 4000, samples = {} }
    for index = 1, 32 do
        local angle = (index - 1) / 32 * math.pi * 2
        prepare.samples[index] = {
            t = (index - 1) * 100,
            x = 0.5 + math.cos(angle) * 0.083,
            y = (750 / 1536) + math.sin(angle) * 0.083,
            down = true,
            pressure = 0.4,
        }
    end

    local place = { durationMs = 3000, samples = {} }
    for index = 1, 12 do
        place.samples[index] = {
            t = (index - 1) * 200,
            x = 0.70 - (index - 1) / 11 * 0.20,
            y = 0.35 + (index - 1) / 11 * ((720 / 1536) - 0.35),
            down = true,
            tilt = 0,
        }
    end

    local cover = { durationMs = 4000, samples = {} }
    for index = 1, 32 do
        cover.samples[index] = {
            t = (index - 1) * 100,
            x = ((index - 1) % 8 + 0.5) / 8,
            y = 0.45 + (math.floor((index - 1) / 8) + 0.5) / 4 * 0.30,
            down = true,
            pressure = 0.35,
            side = index % 2 == 0 and 1 or -1,
        }
    end

    local water = { durationMs = 6000, samples = {} }
    for index = 1, 54 do
        local gx = (index - 1) % 6
        local gy = math.floor((index - 1) / 6) % 4
        water.samples[index] = {
            t = (index - 1) * 100,
            x = 0.405 + gx / 5 * 0.19,
            y = 0.35 + gy / 3 * 0.14,
            pouring = true,
            tilt = 0.5,
        }
    end

    local steps = {}
    for step, trace in pairs({ prepare = prepare, place = place, cover = cover, water = water }) do
        local result, reason = TomatoPlantScoring.ScoreStep(step, trace, cfg)
        assert(result, reason)
        steps[step] = result
    end
    local final, reason = TomatoPlantScoring.Finalize(steps, cfg, 0)
    assert(final, reason)
    assert(final.score >= 70 and final.score <= 100, 'good evidence should produce bounded quality')
    equal(final.outcomes.depth ~= nil, true, 'depth outcome')
    equal(final.outcomes.alignment ~= nil, true, 'alignment outcome')

    local compact = { durationMs = 4000, samples = {} }
    for index, sample in ipairs(prepare.samples) do
        compact.samples[index] = {
            (index - 1) * 2,
            math.floor(sample.x * 2048 + 0.5),
            math.floor(sample.y * 1536 + 0.5),
            3,
            0,
            102,
        }
    end
    local compactResult, compactReason = TomatoPlantScoring.ScoreStep('prepare', compact, cfg)
    assert(compactResult, compactReason)
    assert(math.abs(compactResult.score - steps.prepare.score) < 2, 'compact trace matches object trace')

    prepare.samples[1].x = 2
    local invalid = TomatoPlantScoring.ScoreStep('prepare', prepare, cfg)
    equal(invalid, nil, 'out-of-bounds sample rejected')
end)

dofile('server/modules/farming/quality.lua')

test('validated planting quality contributes to final harvest quality', function()
    local condition = { health = 100, spoilage = 0 }
    local poorPlanting = Quality.Resolve(50, condition, { plantingQuality = 0 })
    local strongPlanting = Quality.Resolve(50, condition, { plantingQuality = 100 })
    assert(strongPlanting > poorPlanting, 'planting quality must remain economically meaningful')
end)

test('production and quality respond independently with visible defects', function()
    local enabled = Config.Features.AdvancedCare
    Config.Features.AdvancedCare = true
    local record = { crop_type = 'carrot', data = {} }
    local waterDamaged = {
        health = 100, spoilage = 0, waterStressAccumulated = 80,
        nutrientStressAccumulated = 0, pestDamageAccumulated = 0, overfertilizeExcess = 0,
    }
    local pestDamaged = {
        health = 100, spoilage = 0, waterStressAccumulated = 0,
        nutrientStressAccumulated = 0, pestDamageAccumulated = 80, overfertilizeExcess = 0,
    }
    equal(Quality.ResolveProduction(record, waterDamaged, 0), 100, 'water stress does not reduce quantity directly')
    assert(Quality.ResolveProduction(record, pestDamaged, 0) < 100, 'pests reduce production')
    equal(Quality.DominantDefect(record, waterDamaged), 'water_stress', 'water defect')
    equal(Quality.DominantDefect(record, pestDamaged), 'pest_damage', 'pest defect')
    local tied = {
        waterStressAccumulated = 100, nutrientStressAccumulated = 100,
        pestDamageAccumulated = 100, overfertilizeExcess = 0,
    }
    equal(Sonar.Conditions.DominantDefect(tied), 'water_stress', 'shared tie order is stable')
    equal(Quality.DominantDefect(record, tied), 'water_stress', 'harvest uses shared tie order')
    assert(Quality.Resolve(100, waterDamaged) < 100, 'water history still reduces quality')
    Config.Features.AdvancedCare = enabled
end)

Database = {
    LoadAllCrops = function() return {} end,
    UpsertCrops = function() return true end,
    DeleteCrops = function() return true end,
}

dofile('server/modules/state/state.lua')
dofile('server/modules/farming/physiology.lua')

test('state keeps cell, owner and slot indexes consistent', function()
    Sonar.Utils.SeedRandom(1234, 5678)
    local id, record = State.Add({
        crop_type = 'carrot',
        owner = 'owner-a',
        zone = 'grapeseed_east',
        slot = 1,
        pos_x = 2236.0,
        pos_y = 5031.0,
        pos_z = 44.2,
    })
    equal(#id, 36, 'UUID length')
    equal(State.CountByOwner('owner-a'), 1, 'owner index')
    equal(State.SlotOccupant('grapeseed_east', 1), id, 'slot index')

    State.Update(id, { owner = 'owner-b', pos_x = 2000.0 })
    equal(State.CountByOwner('owner-a'), 0, 'old owner removed')
    equal(State.CountByOwner('owner-b'), 1, 'new owner added')
    equal(record.cell, State.CellKey(2000.0, record.pos_y), 'cell reindexed')

    State.Remove(id)
    equal(State.Count(), 0, 'crop removed')
    equal(State.SlotOccupant('grapeseed_east', 1), nil, 'slot released')
end)

test('advanced care mutators settle weeds pests and overfertilize consequences', function()
    local enabled = Config.Features.AdvancedCare
    Config.Features.AdvancedCare = true
    local id, record = State.Add({
        crop_type = 'carrot', owner = 'owner-a', zone = 'grapeseed_east', slot = 2,
        pos_x = 2237.0, pos_y = 5031.0, pos_z = 44.2, planted_at = Sonar.Time.Now(),
        growth_time = 900,
        data = { water = 100, health = 100, nutrients = 75, weedCover = 80,
            pestPressure = 70, lastCare = Sonar.Time.Now() },
    })
    local nutrients, excess = Physiology.Fertilize(record, 30, 1)
    equal(nutrients, 100, 'fertilizer respects crop ceiling')
    assert(excess > 0, 'overfertilizing creates a durable consequence')
    assert(Physiology.Weed(record, 70) < 80, 'weeding removes cover')
    assert(Physiology.TreatPests(record, 45) < 70, 'treatment reduces pressure')
    State.Remove(id)
    Config.Features.AdvancedCare = enabled
end)

test('protection trajectories split exactly at expiry', function()
    local enabled = Config.Features.AdvancedCare
    local weeds = Config.Farming.ConditionEffects.Weeds
    local pests = Config.Farming.ConditionEffects.Pests
    Config.Features.AdvancedCare = true
    Config.Farming.ConditionEffects.Weeds = false
    Config.Farming.ConditionEffects.Pests = true

    local def = Config.Crops.carrot
    local record = {
        crop_type = 'carrot', planted_at = -100000, growth_time = 999999,
        data = {
            lastCare = 1000, water = 100, nutrients = 80, pestPressure = 10,
            nutrientProtectionStrength = 0.5, nutrientProtectionUntil = 1000 + 2 * 3600,
            pestProtectionStrength = 0.5, pestProtectionUntil = 1000 + 2 * 3600,
        },
    }
    local trajectory = Sonar.Conditions.Evaluate(record, 1000 + 4 * 3600)
    local expectedNutrients = Sonar.Utils.Clamp(80 - def.nutrients.decayPerHour * 3, 0, 100)
    equal(Sonar.Utils.Round(trajectory.nutrients, 4), Sonar.Utils.Round(expectedNutrients, 4), 'nutrient protection split')
    local pestRate = Config.Farming.AdvancedCare.PestGrowthPerHour * def.pests.susceptibility
    local expectedPests = Sonar.Utils.Clamp(10 + pestRate * 3, 0, 100)
    equal(Sonar.Utils.Round(trajectory.pestPressure, 4), Sonar.Utils.Round(expectedPests, 4), 'pest protection split')

    Config.Features.AdvancedCare = enabled
    Config.Farming.ConditionEffects.Weeds = weeds
    Config.Farming.ConditionEffects.Pests = pests
end)

test('item runtime selects lowest durability and breaks exact slot', function()
    local slots = {
        { slot = 8, count = 1, metadata = { durability = 80 } },
        { slot = 3, count = 1, metadata = { durability = 30 } },
    }
    local setSlot, setValue, removedSlot
    Bridge.Inventory.GetSlotsWithItem = function(_, item)
        return item == 'watering_can' and slots or {}
    end
    Bridge.Inventory.SetDurability = function(_, slot, value) setSlot, setValue = slot, value; return true end
    Bridge.Inventory.RemoveFromSlot = function(_, _, _, slot) removedSlot = slot; return true end

    local selected = assert(Items.Resolve(1, 'water', 'watering_can'))
    equal(selected.slot, 3, 'lowest durability slot selected')
    local consumed, broken = Items.Consume(1, selected)
    equal(consumed, true, 'tool use committed')
    equal(broken, false, 'tool remains')
    equal(setSlot, 3, 'exact slot durability updated')
    equal(Sonar.Utils.Round(setValue, 4), 25, 'one of twenty uses consumed')

    slots = { { slot = 9, count = 1, metadata = { durability = 5 } } }
    selected = assert(Items.Resolve(1, 'water', 'watering_can'))
    consumed, broken = Items.Consume(1, selected)
    equal(consumed, true, 'final use committed')
    equal(broken, true, 'tool broke')
    equal(removedSlot, 9, 'broken tool removed from exact slot')

    slots = {
        { slot = 10, count = 1, metadata = { durability = 0 } },
        { slot = 11, count = 1, metadata = { durability = 50 } },
    }
    selected = assert(Items.Resolve(1, 'water', 'watering_can'))
    equal(selected.slot, 11, 'zero durability tools are never offered')
    local options = Items.ListForAction(1, 'water')
    equal(options[1].usesRemaining, 10, 'menu excludes broken tool uses')
end)

test('state load fails closed on database errors', function()
    Database.LoadAllCrops = function() return nil, 'database unavailable' end
    local ok, err = State.LoadAll()
    equal(ok, false, 'load must fail')
    assert(tostring(err):find('database unavailable', 1, true), 'database error must propagate')
end)

test('state load rejects invalid persisted growth data', function()
    Database.LoadAllCrops = function()
        return {
            {
                id = '00000000-0000-4000-8000-000000000099',
                crop_type = 'carrot',
                pos_x = 2236.0,
                pos_y = 5031.0,
                pos_z = 44.2,
                planted_at = 1000,
                growth_time = 0,
            },
        }
    end
    local ok = State.LoadAll()
    equal(ok, false, 'invalid row must fail boot')
    equal(State.loaded, false, 'state remains unavailable')
end)

test('state load repairs stale spatial cells', function()
    Database.LoadAllCrops = function()
        return {
            {
                id = '00000000-0000-4000-8000-000000000001',
                crop_type = 'carrot',
                owner = 'owner-a',
                zone = 'grapeseed_east',
                slot = 1,
                cell = 'stale',
                pos_x = 2236.0,
                pos_y = 5031.0,
                pos_z = 44.2,
                planted_at = 1000,
                growth_time = 900,
                data = nil,
            },
        }
    end
    local ok, loaded = State.LoadAll()
    equal(ok, true, 'load should succeed')
    equal(loaded, 1, 'loaded count')
    equal(State.Get('00000000-0000-4000-8000-000000000001').cell, State.CellKey(2236.0, 5031.0), 'cell repaired')
    equal(State.dirty['00000000-0000-4000-8000-000000000001'], true, 'repair queued')
end)

dofile('server/modules/farming/lock.lua')

test('locks reject concurrent acquisition and release after errors', function()
    equal(Lock.Acquire('crop'), true, 'first lock')
    equal(Lock.Acquire('crop'), false, 'second lock')
    Lock.Release('crop')
    local ok = pcall(function()
        Lock.With('crop', function() error('expected') end)
    end)
    equal(ok, false, 'error propagated')
    equal(Lock.Acquire('crop'), true, 'lock released after error')
    Lock.Release('crop')
end)

dofile('server/modules/runtime/runtime.lua')

test('runtime gate enforces lifecycle, bucket and identifier', function()
    Runtime.SetStatus(Runtime.STATUS.BOOTING)
    equal(Runtime.GuardPlayer(1).reason, Sonar.Constants.REJECT.SERVICE_UNAVAILABLE, 'boot gate')

    Runtime.SetStatus(Runtime.STATUS.READY)
    equal(Runtime.GuardPlayer(1).ok, true, 'ready player')

    local originalBucket = GetPlayerRoutingBucket
    GetPlayerRoutingBucket = function() return 99 end
    equal(Runtime.GuardPlayer(1).reason, Sonar.Constants.REJECT.WRONG_INSTANCE, 'bucket gate')
    GetPlayerRoutingBucket = originalBucket

    local originalIdentifier = Bridge.GetIdentifier
    Bridge.GetIdentifier = function() return nil end
    equal(Runtime.GuardPlayer(1).reason, Sonar.Constants.REJECT.PLAYER_NOT_READY, 'identifier gate')
    Bridge.GetIdentifier = originalIdentifier
end)

dofile('server/modules/security/ratelimit.lua')

test('rate limit scopes are independent and refill lazily', function()
    Security.Release(1)
    for _ = 1, Config.Security.SubscriptionBucket.capacity do
        equal(Security.Consume(1, 1, 'subscribe'), true, 'subscription token')
    end
    equal(Security.Consume(1, 1, 'subscribe'), false, 'subscription limited')
    equal(Security.Consume(1, 1, 'action'), true, 'action scope unaffected')
    gameTimer = gameTimer + 1000
    equal(Security.Consume(1, 1, 'subscribe'), true, 'subscription refilled')
end)

test('database serializes nullable slots and reports failed transactions', function()
    local captured
    MySQL = {
        transaction = {
            await = function(queries)
                captured = queries
                return true
            end,
        },
    }

    dofile('server/modules/database/database.lua')
    local ok = Database.UpsertCrops({
        {
            id = '00000000-0000-4000-8000-000000000002',
            crop_type = 'carrot',
            cell = '1:1',
            pos_x = 1,
            pos_y = 2,
            pos_z = 3,
            planted_at = 1000,
            growth_time = 900,
        },
    })

    equal(ok, true, 'upsert succeeds')
    assert(captured[1].query:find('NULLIF%(%?, 0%)'), 'numeric NULLIF placeholder')
    equal(captured[1].values[5], 0, 'slot sentinel')
    equal(#captured[1].values, 14, 'dense parameter array')

    MySQL.transaction.await = function()
        return false
    end
    equal(Database.UpsertCrops({
        {
            id = '00000000-0000-4000-8000-000000000003',
            crop_type = 'carrot',
            cell = '1:1',
            pos_x = 1,
            pos_y = 2,
            pos_z = 3,
            planted_at = 1000,
            growth_time = 900,
        },
    }), false, 'failed transaction is reported')
end)

test('database rejects an empty but incompatible schema', function()
    local columns = {
        'id', 'crop_type', 'owner', 'zone', 'slot', 'cell',
        'pos_x', 'pos_y', 'pos_z', 'heading',
        'planted_at', 'growth_time', 'state', 'data',
    }

    MySQL.query = {
        await = function(sql)
            if sql:find('information_schema.COLUMNS', 1, true) then
                local rows = {}
                for _, name in ipairs(columns) do
                    rows[#rows + 1] = { COLUMN_NAME = name }
                end
                return rows
            end
            return {
                { COLUMN_NAME = 'zone', NON_UNIQUE = 0, SEQ_IN_INDEX = 1 },
                { COLUMN_NAME = 'slot', NON_UNIQUE = 0, SEQ_IN_INDEX = 2 },
            }
        end,
    }

    equal(Database.ValidateSchema(), true, 'complete schema')
    table.remove(columns)
    equal(Database.ValidateSchema(), false, 'missing data column')
end)

test('company custody closes consumables and tools per consumed unit', function()
    local transaction, outboxStatus = {}, {}
    MySQL.insert = { await = function(_, values) outboxStatus[values[1]] = 'prepared'; return 1 end }
    MySQL.single = { await = function(sql)
        if sql:find('FROM sf_company_members', 1, true) then
            return { company_id = 'company-test', identifier = 'citizen-test', display_name = 'Test Player',
                role_key = 'worker', status = 'active', permissions = { 'warehouse.withdraw' },
                treasury_cents = 0, monthly_budget_cents = 0 }
        end
        return nil
    end }
    MySQL.scalar = { await = function(sql, values)
        if sql:find('FROM sf_material_issues', 1, true) then return 'issued' end
        return outboxStatus[values[1]]
    end }
    MySQL.update = { await = function(_, values)
        if outboxStatus[values[1]] == 'prepared' then outboxStatus[values[1]] = 'inventory_done'; return 1 end
        return 0
    end }
    MySQL.transaction = { await = function(queries)
        transaction = queries
        local outboxId = queries[#queries].values[1]
        outboxStatus[outboxId] = 'completed'
        return true
    end }
    Bridge.Inventory.GetItemCount = function() return 1 end
    dofile('server/modules/company/company.lua')

    local consumableMetadata = { ownership = 'company', companyId = 'company-test',
        issueId = 'issue-consumable', itemId = 'fertilizer_organic' }
    local prepared, outboxId, payload = Company.PrepareItemUse(1, consumableMetadata, 'fertilize',
        { slot = 1, count = 1, durability = 100 }, false)
    equal(prepared, true, 'consumable custody is durably reserved before mutation')
    Company.RecordItemUse(1, consumableMetadata, 'fertilize', false, outboxId, payload)
    equal(transaction[1].values[1], 1, 'consumable increments consumed units')
    equal(transaction[1].values[2], 1, 'consumable can close its custody total')

    transaction = {}
    local toolMetadata = { ownership = 'company', companyId = 'company-test', issueId = 'issue-tool', itemId = 'watering_can' }
    prepared, outboxId, payload = Company.PrepareItemUse(1, toolMetadata, 'water',
        { slot = 2, count = 1, durability = 5 }, true)
    equal(prepared, true, 'broken tool custody is reserved')
    Company.RecordItemUse(1, toolMetadata, 'water', true, outboxId, payload)
    equal(transaction[1].values[1], 1, 'broken tool consumes one issued unit')
    assert(transaction[2].query:find("status='consumed'", 1, true), 'warehouse tool unit is retired')

    transaction = {}
    prepared, outboxId, payload = Company.PrepareItemUse(1, toolMetadata, 'water',
        { slot = 2, count = 1, durability = 50 }, false)
    equal(prepared, true, 'ordinary tool custody is reserved')
    Company.RecordItemUse(1, toolMetadata, 'water', false, outboxId, payload)
    equal(transaction[1].values[1], 0, 'ordinary tool use does not consume the unit')
    equal(#transaction, 2, 'ordinary tool use only updates custody and outbox')
end)

test('warehouse schema preserves tool durability and operation idempotency', function()
    local function read(path)
        local file = assert(io.open(path, 'rb'))
        local value = file:read('*a')
        file:close()
        return value
    end
    local schema = read('server/modules/company/database.lua')
    local service = read('server/modules/supplies/service.lua')
    assert(schema:find('sf_warehouse_tool_units', 1, true), 'per-tool warehouse storage required')
    assert(schema:find('uniq_sf_issue_operation', 1, true), 'withdrawal idempotency constraint required')
    assert(service:find('identifier = member.identifier', 1, true), 'return outbox must bind its owner')
    assert(service:find("ORDER BY durability,id LIMIT 1", 1, true), 'lowest durability warehouse tool selected first')
    assert(service:find("row.status == 'prepared'", 1, true), 'prepared usage rows must be reconciled after a restart')
    assert(service:find("Lock.With('member-custody:' .. member.identifier", 1, true), 'withdrawal and member removal share a custody lock')
end)

print(('All %d tests passed.'):format(passed))
