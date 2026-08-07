--[[
    sonar_farm - Public farming zones (data-driven)
    MVP uses public, delimited zones. Private plots / properties arrive in Phase 2.

    Schema per zone:
      label        string   Display name.
      center       vector3  Zone center.
      radius       number   Zone radius in meters (planting must happen inside).
      allowedCrops table    Crop keys plantable here. Empty table = all crops.

    Coordinates are sensible defaults around the Grapeseed farmland. Adjust them
    to your map: any position outside a zone is rejected by the server.
]]

Config.Zones = {
    grapeseed_east = {
        label = 'Grapeseed East Fields',
        center = vec3(2236.0, 5031.0, 44.0),
        radius = 90.0,
        allowedCrops = {},
    },

    grapeseed_south = {
        label = 'Grapeseed South Fields',
        center = vec3(2010.0, 4900.0, 41.0),
        radius = 80.0,
        -- Example of a restricted zone: only hardy tubers grow here.
        allowedCrops = { 'carrot', 'potato' },
    },
}
