--[[
    sonar_farm - Public farming zones and planting slots (data-driven)

    Crops grow only at configured slots. Free-planting was dropped because it
    produced overlapping props, messy-looking fields and no way to cap how much a
    zone can hold. With slots, capacity is a design decision: a zone with 40 slots
    can hold exactly 40 crops, never 41.

    Schema per zone:
      label        string   Display name.
      center       vector3  Used for the map blip only.
      allowedCrops table    Crop keys plantable here. Empty/absent = all crops.
      blip         table    Optional map blip:
                              enabled, sprite, color, scale

      grid         table    Optional generated block of slots (preferred: it
                            guarantees the symmetry hand-typed coordinates never
                            quite reach).
                              origin   vector3  centre of the block
                              rows     number   slots along Y
                              cols     number   slots along X
                              spacing  table    { x = number, y = number } meters
                              heading  number   degrees, rotates the whole block
                                                so rows align with the field

      slots        table    Optional explicit vector3 list, appended after the
                            grid. Use it for odd corners the grid cannot cover.

    Slot indices are assigned in order (grid first, then explicit) and are 1-based.
    IMPORTANT: reordering or resizing a grid renumbers the slots, which orphans
    the crops already planted in them. Add new slots at the end, or clear the zone
    first. See docs/RUNBOOK.md.

    Coordinates are defaults around the Grapeseed farmland. Adjust them to your
    map: the server only ever plants at these positions.
]]

Config.Zones = {
    grapeseed_east = {
        label = 'Grapeseed East Fields',
        center = vec3(2236.0, 5031.0, 44.0),
        allowedCrops = {},

        -- 5 rows of 8 = 40 slots.
        grid = {
            origin = vec3(2236.0, 5031.0, 44.2),
            rows = 5,
            cols = 8,
            spacing = { x = 2.2, y = 2.8 },
            heading = 0.0,
        },

        blip = {
            enabled = true,
            sprite = 496,
            color = 25,
            scale = 0.8,
        },
    },

    grapeseed_south = {
        label = 'Grapeseed South Fields',
        center = vec3(2010.0, 4900.0, 41.0),
        -- Restricted zone: only the hardy tubers grow here.
        allowedCrops = { 'carrot', 'potato' },

        -- 4 rows of 6 = 24 slots.
        grid = {
            origin = vec3(2010.0, 4900.0, 41.2),
            rows = 4,
            cols = 6,
            spacing = { x = 2.2, y = 2.8 },
            heading = 0.0,
        },

        blip = {
            enabled = true,
            sprite = 496,
            color = 25,
            scale = 0.8,
        },
    },


    zone1 = {
        label        = 'local test',
        center       = vec3(2055.71, 4954.00, 40.08),
        allowedCrops = { 'tomato' },

        slots = {
        { x = 2045.92, y = 4966.56, z = 40.08, heading = 130.8 },
        { x = 2048.59, y = 4963.94, z = 40.04, heading = 131.5 },
        { x = 2052.00, y = 4960.57, z = 40.06, heading = 135.4 },
        { x = 2055.07, y = 4957.47, z = 40.04, heading = 135.7 },
        { x = 2059.13, y = 4953.41, z = 40.02, heading = 135.6 },
        { x = 2061.88, y = 4950.68, z = 40.06, heading = 138.3 },
        { x = 2065.39, y = 4947.21, z = 40.05, heading = 135.7 },
        { x = 2068.97, y = 4943.99, z = 40.07, heading = 131.4 },
        { x = 2044.45, y = 4965.16, z = 40.12, heading = 109.5 },
        { x = 2047.19, y = 4962.62, z = 40.11, heading = 109.5 },
        { x = 2050.48, y = 4959.17, z = 40.10, heading = 109.5 },
        { x = 2053.62, y = 4955.85, z = 40.10, heading = 109.5 },
        { x = 2057.59, y = 4951.96, z = 40.09, heading = 109.5 },
        { x = 2060.56, y = 4949.31, z = 40.10, heading = 109.5 },
        { x = 2063.88, y = 4945.80, z = 40.10, heading = 109.5 },
        { x = 2067.38, y = 4942.58, z = 40.11, heading = 109.5 },
        { x = 2066.21, y = 4940.96, z = 40.11, heading = 109.5 },
        { x = 2062.69, y = 4944.23, z = 40.07, heading = 109.5 },
        { x = 2059.23, y = 4947.66, z = 40.09, heading = 109.5 },
        { x = 2056.40, y = 4950.47, z = 40.09, heading = 109.5 },
        { x = 2052.29, y = 4954.51, z = 40.09, heading = 109.5 },
        { x = 2048.97, y = 4957.67, z = 40.09, heading = 109.5 },
        { x = 2046.11, y = 4960.66, z = 40.09, heading = 109.5 },
        { x = 2043.08, y = 4963.62, z = 40.12, heading = 109.5 },
        },

        blip = { enabled = true, sprite = 496, color = 25, scale = 0.8 },
    },

}
