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
}
