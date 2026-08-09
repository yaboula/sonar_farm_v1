--[[
    sonar_farm - Minigame registry (data-driven)
    Minigames are their own module (Stage 5). This maps a farming action to the
    minigame that gates its quality/XP outcome. The server always validates the
    final score; the client cannot self-report a perfect result.

    Tomato Initial Planting is the first Stage 5 slice. The client renders the
    interaction, but every world mutation and score is validated on the server.
]]

Config.Minigames = {
    Plant = {
        tomato = {
            key = 'tomato_initial_planting',
            contractVersion = '1.0.0',
            qualityCap = 100,
            sessionTtl = 180,
            incompleteTtl = 1800,
            maxSamplesPerStep = 400,
            maxPayloadBytes = 49152,
            sampleIntervalMs = 50,
            stepWeights = {
                prepare = 0.25,
                place = 0.30,
                cover = 0.25,
                water = 0.20,
            },
            minimumStepDurationMs = {
                prepare = 3000,
                place = 2500,
                cover = 3000,
                water = 5000,
            },
            maximumStepDurationMs = 120000,
            interruptionPenalty = 8,
            maxInterruptionPenalty = 20,
            initialWater = { min = 55, max = 100 },
        },
    },
}
