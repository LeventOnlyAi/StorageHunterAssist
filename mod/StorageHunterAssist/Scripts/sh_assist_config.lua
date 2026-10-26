return {
    -- F7 cycles these values; F6 advances by the selected number of minutes.
    TimeSteps = {15, 30, 60, 120, 240},
    DefaultStep = 60,
    -- 08:00 starts the game's day; stop short of the forced day-end.
    DayStartHour = 8,
    LastMinuteOfDay = 1437,
    -- Owned loose goods within 15 m, and cargo in trucks within 50 m.
    NearRangeCm = 1500,
    TruckRangeCm = 5000,
    AutoDepositPollMs = 2000,
}

