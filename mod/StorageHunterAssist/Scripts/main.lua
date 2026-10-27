-- StorageHunterAssist: native remote sale / warehouse panel and configurable time skip.
local VERSION = '0.3.0'
local H = require('UEHelpers')
local Core = require('sh_assist_core')
local C = Core.validate(require('sh_assist_config'))
local index = Core.stepIndex(C.TimeSteps, C.DefaultStep)
local Panel
local timeBusy = false
local lastPress = {}
local function valid(o) return o ~= nil and o:IsValid() end
local function log(s) print('[StorageHunterAssist] '..tostring(s)..'\n') end
local function notify(s)
    log(s)
    pcall(function()
        local popup = FindFirstOf('BP_PopupSystem_Comp_C')
        if valid(popup) then popup:MakePopup(FText(s), {}) end
    end)
end
local function playerReady()
    local player = H.GetPlayer()
    if not valid(player) then return nil, 'Once kaydi yukle.' end
    if not player:HasAuthority() then return nil, 'Bu surum yalnizca tek oyunculu/host icindir.' end
    local game = StaticFindObject('/Script/Engine.Default__GameplayStatics')
    if valid(game) and game:IsGamePaused(player) then return nil, 'Devam etmek icin duraklatmayi kapat.' end
    return player
end

local function skipTime()
    if timeBusy then return false end
    local player, reason = playerReady()
    if not player then notify(reason); return false end
    local ts = FindFirstOf('BP_TimeSystemChild_Comp_C')
    if not valid(ts) then ts = FindFirstOf('BP_TimeSystem_Compp_C') end
    if not valid(ts) or not valid(ts.UDS) then notify('Saat sistemi hazir degil.'); return false end
    local out = {}
    ts:GetPassedMinutesNumber(out)
    if type(out.Result) ~= 'number' then error('Saat okunamadi') end
    local requested = C.TimeSteps[index]
    local target, advanced = Core.timeTarget(out.Result, requested, C)
    if not target then notify('Gunun sonuna geldin. Sonraki gun icin yatakta uyu.'); return false end
    local before = out.Result
    ts.UDS['Set New Time Of Day'](ts.UDS, target)
    timeBusy = true
    -- Clock counters update on the following frame; observe instead of claiming
    -- success merely because ProcessEvent accepted the call.
    ExecuteWithDelay(300, function()
        ExecuteInGameThread(function()
            timeBusy = false
            local ok, err = pcall(function()
                if not valid(ts) then return end
                local after = {}
                ts:GetPassedMinutesNumber(after)
                local delta = type(after.Result)=='number' and (after.Result-before) or 0
                if delta > 0 then
                    notify(string.format('Zaman +%d dakika. Secili adim: %d dk.',
                        math.floor(delta), requested))
                else
                    notify('Saat atlama dogrulanamadi; oyun gunlugunu kontrol et.')
                end
                log(string.format('TIME before=%d after=%s requested=%d clamped=%d',
                    before, tostring(after.Result), requested, advanced))
            end)
            if not ok then log('TIME CHECK ERROR '..tostring(err)) end
        end)
    end)
    return true
end

local function cycleTime()
    index = index % #C.TimeSteps + 1
    if Panel then Panel.Menu.Set('Time','step',C.TimeSteps[index]) end
    notify('Zaman adimi: '..C.TimeSteps[index]..' dakika. F6: ileri al.')
end
local function status()
    notify(string.format('F8: Satış / Depo paneli | F6: +%d dk | F7: süre', C.TimeSteps[index]))
end
local function guarded(fn)
    return function()
        local ok, err = pcall(fn)
        if not ok then notify('Islem tamamlanamadi. Ayrinti UE4SS.log dosyasinda.'); log('ERROR '..tostring(err)) end
    end
end
local function bind(key, fn)
    if IsKeyBindRegistered(key) then log('KEY CONFLICT '..tostring(key)); return end
    RegisterKeyBind(key, function()
        local now = os.clock()
        if lastPress[key] and now-lastPress[key] < 0.5 then return end
        lastPress[key] = now
        ExecuteInGameThread(guarded(fn))
    end)
end
bind(Key.F6,skipTime)
bind(Key.F7,cycleTime)
bind(Key.F5,status)
Panel=require('sh_assist_panel').start(C,{
    Skip=guarded(skipTime),
    GetStep=function() return C.TimeSteps[index] end,
    SetStep=function(value) index=Core.stepIndex(C.TimeSteps,value) end,
},notify)
StorageHunterAssist = {
    SkipTime=skipTime, CycleTime=cycleTime, Status=status, Panel=Panel,
}
log('v'..VERSION..' loaded. F8=remote panel F6=time F7=step F5=help')
