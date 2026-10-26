local M = {}

function M.validate(config)
    assert(type(config.TimeSteps) == 'table' and #config.TimeSteps > 0, 'TimeSteps is empty')
    for _, step in ipairs(config.TimeSteps) do
        assert(type(step) == 'number' and step >= 1 and step <= 1440 and step % 1 == 0,
            'TimeSteps must contain whole minutes between 1 and 1440')
    end
    assert(type(config.LastMinuteOfDay) == 'number' and config.LastMinuteOfDay >= 1
        and config.LastMinuteOfDay <= 1438, 'Invalid end-of-day limit')
    assert(type(config.DayStartHour) == 'number' and config.DayStartHour >= 0
        and config.DayStartHour <= 23 and config.DayStartHour % 1 == 0, 'Invalid day start')
    assert(type(config.NearRangeCm) == 'number' and config.NearRangeCm > 0, 'Invalid nearby range')
    assert(type(config.TruckRangeCm) == 'number' and config.TruckRangeCm > 0, 'Invalid truck range')
    assert(type(config.AutoDepositPollMs) == 'number' and config.AutoDepositPollMs >= 1000, 'Invalid poll interval')
    return config
end

function M.stepIndex(steps, selected)
    for i, value in ipairs(steps) do
        if value == selected then return i end
    end
    return 1
end

function M.timeTarget(totalMinutes, requested, config)
    local current = math.floor(totalMinutes) % 1440
    local target = math.min(current + requested, config.LastMinuteOfDay)
    if target <= current then return nil, 0 end
    local displayMinutes = (target + config.DayStartHour * 60) % 1440
    return displayMinutes / 60 * 100, target - current
end

function M.distanceSquared(a, b)
    return (a.X-b.X)^2 + (a.Y-b.Y)^2 + (a.Z-b.Z)^2
end

return M
