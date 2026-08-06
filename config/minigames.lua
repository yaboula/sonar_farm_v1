--[[
    sonar_farm - Minigame registry (data-driven)
    Minigames are their own module (Stage 5). This maps a farming action to the
    minigame that gates its quality/XP outcome. The server always validates the
    final score; the client cannot self-report a perfect result.

    NOTE: Placeholder schema for Stage 1.

    Schema per action:
      minigame   string   Registered minigame key (see Stage 5 framework).
      difficulty number   0.0 .. 1.0 base difficulty.
      qualityCap number   Max quality (0..100) achievable via this action.
]]

Config.Minigames = {
    -- Example (disabled until Stage 5):
    -- plant   = { minigame = 'precision_press', difficulty = 0.3, qualityCap = 100 },
    -- water   = { minigame = 'timing_bar',      difficulty = 0.4, qualityCap = 100 },
    -- harvest = { minigame = 'rhythm_pick',     difficulty = 0.5, qualityCap = 100 },
}
