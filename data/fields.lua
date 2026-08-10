-- Canonical, version-controlled Field catalogue.
-- MySQL becomes authoritative after this catalogue is imported at boot.

Config.FieldSeeds = {
    {
        id = 'grapeseed_east', legacyZone = 'grapeseed_east', name = 'East Fields',
        location = 'Grapeseed · East service track', orientation = 0.0,
        starterEligible = true, starterPriority = 10, purchasePrice = 45000,
        catalogVisible = true, allowedCrops = {},
        access = { x = 2236.0, y = 5031.0, z = 44.0 },
        grid = { origin = { x = 2236.0, y = 5031.0, z = 44.2 }, rows = 5, cols = 8,
            spacing = { x = 2.2, y = 2.8 }, heading = 0.0 },
        blip = { enabled = true, sprite = 496, color = 25, scale = 0.8 },
    },
    {
        id = 'grapeseed_south', legacyZone = 'grapeseed_south', name = 'South Fields',
        location = 'Grapeseed · South farm road', orientation = 0.0,
        starterEligible = true, starterPriority = 20, purchasePrice = 38000,
        catalogVisible = true, allowedCrops = { 'carrot', 'potato' },
        access = { x = 2010.0, y = 4900.0, z = 41.0 },
        grid = { origin = { x = 2010.0, y = 4900.0, z = 41.2 }, rows = 4, cols = 6,
            spacing = { x = 2.2, y = 2.8 }, heading = 0.0 },
        blip = { enabled = true, sprite = 496, color = 25, scale = 0.8 },
    },
    {
        id = 'zone1', legacyZone = 'zone1', name = 'QA Tomato Field',
        location = 'Grapeseed · Development plot', orientation = 109.5,
        starterEligible = false, starterPriority = 999, purchasePrice = 0,
        catalogVisible = false, allowedCrops = { 'tomato' },
        access = { x = 2055.71, y = 4954.00, z = 40.08 },
        rows = {
            { slots = {
                { x=2045.92,y=4966.56,z=40.08,heading=130.8 }, { x=2048.59,y=4963.94,z=40.04,heading=131.5 },
                { x=2052.00,y=4960.57,z=40.06,heading=135.4 }, { x=2055.07,y=4957.47,z=40.04,heading=135.7 },
                { x=2059.13,y=4953.41,z=40.02,heading=135.6 }, { x=2061.88,y=4950.68,z=40.06,heading=138.3 },
                { x=2065.39,y=4947.21,z=40.05,heading=135.7 }, { x=2068.97,y=4943.99,z=40.07,heading=131.4 },
            } },
            { slots = {
                { x=2044.45,y=4965.16,z=40.12,heading=109.5 }, { x=2047.19,y=4962.62,z=40.11,heading=109.5 },
                { x=2050.48,y=4959.17,z=40.10,heading=109.5 }, { x=2053.62,y=4955.85,z=40.10,heading=109.5 },
                { x=2057.59,y=4951.96,z=40.09,heading=109.5 }, { x=2060.56,y=4949.31,z=40.10,heading=109.5 },
                { x=2063.88,y=4945.80,z=40.10,heading=109.5 }, { x=2067.38,y=4942.58,z=40.11,heading=109.5 },
            } },
            { slots = {
                { x=2066.21,y=4940.96,z=40.11,heading=109.5 }, { x=2062.69,y=4944.23,z=40.07,heading=109.5 },
                { x=2059.23,y=4947.66,z=40.09,heading=109.5 }, { x=2056.40,y=4950.47,z=40.09,heading=109.5 },
                { x=2052.29,y=4954.51,z=40.09,heading=109.5 }, { x=2048.97,y=4957.67,z=40.09,heading=109.5 },
                { x=2046.11,y=4960.66,z=40.09,heading=109.5 }, { x=2043.08,y=4963.62,z=40.12,heading=109.5 },
            } },
        },
        blip = { enabled = Config.Debug == true, sprite = 496, color = 25, scale = 0.8 },
    },
}
