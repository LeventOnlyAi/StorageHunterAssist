-- Native game transactions. Run every public method on the game thread.
local M = {}
local H = require('UEHelpers')
local Core = require('sh_assist_core')
local Items = require('sh_assist_items')
local processed = {}
local busy = false
local function valid(o) return o ~= nil and o:IsValid() end
local function text(v)
    if v == nil then return '' end
    if type(v) == 'userdata' then
        local ok, s = pcall(function() return v:ToString() end)
        if ok then return s end
    end
    return tostring(v)
end
local function name(o) return o:GetFullName() end
local function log(s) print('[StorageHunterAssist] '..s..'\n') end
local function later(ms, fn)
    ExecuteWithDelay(ms, function() ExecuteInGameThread(fn) end)
end
M.valid, M.text = valid, text
function M.ready()
    local p = H.GetPlayer()
    if not valid(p) then return nil, 'Önce oyun kaydını yükle.' end
    if not p:HasAuthority() then return nil, 'Bu sürüm tek oyunculu / host içindir.' end
    if StaticFindObject('/Script/Engine.Default__GameplayStatics'):IsGamePaused(p) then
        return nil, 'Önce oyuna devam et.'
    end
    return p
end
function M.catalog()
    local result = {}
    for _, o in ipairs(FindAllOf('BP_OwnerPawnShopController_C') or {}) do
        if valid(o) and valid(o.PawnShop) and valid(o.PA_PawnShop_Data) then
            local area = o.PawnShop['As BP Trader Area']
            if valid(area) then
                result[#result+1] = {key=text(o.PA_PawnShop_Data.PawnshopID),
                    label=text(o.PA_PawnShop_Data.PawnshopName), owner=o,
                    shop=o.PawnShop, area=area, warehouse=o.BP_WarehousePawnshop,
                    owned=o.IsUnlocked == true}
            end
        end
    end
    table.sort(result,function(a,b) return a.key < b.key end)
    return result
end
local function aliases(p, catalog)
    local ids = {[text(p:GetOwnerID())]=true}
    -- Some existing saves retain the old profile name on bought items and shops.
    for _, d in ipairs(catalog) do
        if d.owned then ids[text(d.owner.OwnerID)] = true end
    end
    ids['None'], ids[''], ids['nil'] = nil, nil, nil
    return ids
end
function M.eligibleState(s, ids)
    return ids[s.owner] == true and not s.shelf and not s.warehouse
        and not s.inside and not s.held and not s.processed
end
local function eligible(o, ids)
    if not valid(o) then return false end
    return M.eligibleState({owner=text(o.OwnerPlayerID),shelf=o.IsInPawnShop,
        warehouse=o.IsAddedToWarehouse,inside=o.IsInsideContainer,
        held=o.IsInPickingUpMode,processed=processed[name(o)]},ids)
end
local function observeRecycled(ids)
    -- The game pools tradable actors. A successful transaction's actor can later
    -- represent another acquired item with the SAME full name. Clear only a
    -- confirmed latch when native ownership/storage state proves it has left
    -- the previous loose-goods lifecycle. Ambiguous failures remain latched.
    for key,mark in pairs(processed) do
        if type(mark)=='table' then
            local o=mark.actor
            local ok,released=pcall(function()
                return not valid(o) or not ids[text(o.OwnerPlayerID)] or o.IsAddedToWarehouse==true or o.IsInPawnShop==true
            end)
            if ok and released then processed[key]=nil end
        end
    end
end
function M.scan(c, source)
    local p, err = M.ready()
    if not p then return {}, err end
    local ids = aliases(p, M.catalog())
    observeRecycled(ids)
    local origin = p:K2_GetActorLocation()
    local rows, seen = {}, {}
    local collectors=Items.collectors()
    local rejected,errors=0,0
    local function add(o, where)
        if not eligible(o,ids) then rejected=rejected+1; return end
        local key=name(o)
        if seen[key] then return end
        seen[key]=true
        local out={}; pcall(function() o:GetItemName(out) end)
        local row=Items.describe(o,collectors)
        row.key,row.actor,row.label,row.source=key,o,text(out.ItemName),where
        if row.label=='' then row.label=text(o.ID) end
        rows[#rows+1]=row
    end
    if source ~= 'near' then
        for _, trunk in ipairs(FindAllOf('BP_Vehicle_Trunk_C') or {}) do
            if valid(trunk) and valid(trunk.TradableItemsRegisterBox)
                and Core.distanceSquared(origin,trunk.TradableItemsRegisterBox:K2_GetComponentLocation()) <= c.TruckRangeCm^2 then
                trunk.PackedTradableItems:ForEach(function(_,e)
                    local ok=pcall(function() add(e:get(),'Kamyon') end)
                    if not ok then errors=errors+1 end
                end)
            end
        end
    end
    if source ~= 'truck' then
        for _, o in ipairs(FindAllOf('BP_TradableItemBase_C') or {}) do
            local ok=pcall(function()
                if valid(o) and Core.distanceSquared(origin,o:K2_GetActorLocation()) <= c.NearRangeCm^2 then add(o,'Yakında') end
            end)
            if not ok then errors=errors+1 end
        end
    end
    table.sort(rows,function(a,b) if a.source==b.source then return a.label<b.label end return a.source<b.source end)
    local reason
    if #rows==0 then
        reason='Uygun eşya yok. Kaynağı ve mesafeyi kontrol et.'
        if rejected>0 then reason=reason..' Yakındaki '..rejected..' eşya sahiplik / elde / kutu / raf / depo nedeniyle dışarıda.' end
        if errors>0 then reason=reason..' '..errors..' geçersiz eşya atlandı; tekrar yenile.' end
    end
    return rows,reason
end
function M.isBusy() return busy end
-- Re-scan immediately before committing: stale UI selections cannot sell moved goods.
function M.resolve(c, source, keys)
    local result={}
    for _,r in ipairs(M.scan(c,source)) do if keys[r.key] then result[#result+1]=r end end
    return result
end
function M.deposit(c, source, targetKey, keys, done, guard)
    if busy then done('Önceki işlem devam ediyor.',0); return end
    local p,err=M.ready(); if not p then done(err,0); return end
    local target
    for _,d in ipairs(M.catalog()) do if d.key==targetKey and d.owned then target=d end end
    if not target or not valid(target.warehouse) or not target.warehouse.bIsUnlocked then
        done('Sahip olduğun açık bir mağaza deposunu seç.',0); return
    end
    local rows=M.resolve(c,source,keys)
    if guard then local filtered={}; for _,r in ipairs(rows) do if guard(r) then filtered[#filtered+1]=r end end; rows=filtered end
    if #rows==0 then done('Seçili uygun eşya yok. Listeyi yenile.',0); return end
    busy=true
    local inv=target.warehouse.BP_TradableInventory_Comp
    local count,full=0,false
    local ok,failure=pcall(function()
        for _,r in ipairs(rows) do
            if inv.CurrentAmount >= inv.Capacity then full=true; break end
            local before=inv.CurrentAmount
            local out={}
            -- Latch before calling into the engine; an ambiguous failure must never duplicate.
            processed[r.key]=true
            target.warehouse:OnTradableItemOverlappedDropZone(r.actor,true,out)
            if out.WasItemAdded == true then
                processed[r.key]={actor=r.actor}
                count=count+1
                log(string.format('DEPOSIT target=%s item=%s before=%d after=%d',target.key,r.key,before,inv.CurrentAmount))
            else
                processed[r.key]=nil
                full=true
                break
            end
        end
    end)
    busy=false
    if not ok then log('DEPOSIT ERROR '..tostring(failure)); done('Depo işlemi durdu; günlük dosyasını kontrol et.',count,true); return end
    done(string.format('%d eşya depoya gönderildi: %s.%s',count,target.label,full and ' Depo dolu veya eşya kabul edilmedi.' or ''),count,full)
end
function M.sell(c, source, targetKey, keys, done, guard)
    if busy then done('Önceki işlem devam ediyor.',0); return end
    local p,err=M.ready(); if not p then done(err,0); return end
    local target
    for _,d in ipairs(M.catalog()) do if d.key==targetKey then target=d end end
    if not target then done('Bir satış noktası seç.',0); return end
    local rows=M.resolve(c,source,keys)
    if guard then local filtered={}; for _,r in ipairs(rows) do if guard(r) then filtered[#filtered+1]=r end end; rows=filtered end
    if #rows==0 then done('Seçili uygun eşya yok. Listeyi yenile.',0); return end
    for _,r in ipairs(rows) do
        if not r.saleReady then done('Satış için önce seçili ürünleri oyunda doğrula. Sıfır bedelli satış önlendi.',0,true); return end
    end
    busy=true
    local widget, completed= nil,0
    local function cleanup(message,halt)
        if valid(widget) then pcall(function() widget:RemoveFromParent() end) end
        busy=false
        done(message,completed,halt)
    end
    local function fail(e)
        log('SALE ERROR '..tostring(e)); cleanup('Satış durduruldu. Tekrar denemeden önce listeyi yenile.',true)
    end
    local ok,failure=pcall(function()
        local cls=StaticFindObject('/Game/SH/Systems/PawnShopSystem/UI/WBP_PawnShop_Sell.WBP_PawnShop_Sell_C')
        widget=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(p,cls,H.GetPlayerController())
        widget:Init(target.area)
        widget.bIsQuickSell=true
        local actors={}; for _,r in ipairs(rows) do actors[#actors+1]=r.actor end
        widget:SpawnItems(actors,target.shop)
        -- Construct binds the native delegates and creates the correct regional prices.
        widget:AddToViewport(-100)
        widget:SetVisibility(1) -- Collapsed. This helper never takes input focus.
    end)
    if not ok then fail(failure); return end
    later(350,function()
        local ok2,e=pcall(function()
            if not valid(widget) or not valid(p) then error('Sale context expired') end
            local current={}
            for _,r in ipairs(M.resolve(c,source,keys)) do if r.saleReady and (not guard or guard(r)) then current[r.key]=true end end
            for _,r in ipairs(rows) do if not current[r.key] then error('Sale selection moved or changed') end end
            local presets={}
            widget.WBP_PawnShop_WarehouseItems.PresetsArray:ForEach(function(_,e) presets[#presets+1]=e:get() end)
            if #presets~=#rows then error('Native sale rows did not match selection') end
            local byKey={}; for _,r in ipairs(rows) do byKey[r.key]=true end
            local creditsBefore=p.PlayerState:GetPlayerCredits()
            for _,r in ipairs(presets) do
                local actor=r['Tradable Item']
                if not valid(actor) or not byKey[name(actor)] or processed[name(actor)] then error('Sale item changed') end
                local actorKey=name(actor)
                processed[actorKey]=true
                -- Native quick-sale event includes the normal regional accounting and removal.
                widget:OnClicked_PawnShopWarehouseItems_QuickSell_Event(actor,r.Index,r.ItemId,r.AssignedIndividualData,r)
                processed[actorKey]={actor=actor}
                completed=completed+1
            end
            local after=p.PlayerState:GetPlayerCredits()
            log(string.format('SALE target=%s count=%d cashBefore=%s cashAfter=%s',target.key,completed,tostring(creditsBefore),tostring(after)))
            cleanup(string.format('%d eşya satıldı: %s. Nakit değişimi: %+d.',completed,target.label,after-creditsBefore))
        end)
        if not ok2 then fail(e) end
    end)
end
-- Deposit first; a full/rejected warehouse must stop the batch before any sale.
function M.sort(c, source, saleKey, depotKey, keys, rules, done)
    if busy then done('Önceki işlem devam ediyor.',0); return end
    local snapshot={sell={},collectorDepot=rules.collectorDepot==true}
    for k,v in pairs(rules.sell) do snapshot.sell[k]=v==true end
    local parts=Items.partition(M.resolve(c,source,keys),nil,snapshot)
    local function size(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
    local ns,nd,nh=size(parts.sell),size(parts.depot),size(parts.hold)
    if ns+nd==0 then done('İşlenecek eşya yok. Koleksiyonluk, bilinmeyen ve satış için doğrulanmamış ürünler bekler.',0); return end
    local saleTarget,depotTarget
    for _,d in ipairs(M.catalog()) do
        if d.key==saleKey then saleTarget=d end
        if d.key==depotKey and d.owned then depotTarget=d end
    end
    if ns>0 and not saleTarget then done('Önce satış bölgesini seç.',0); return end
    if nd>0 and (not depotTarget or not valid(depotTarget.warehouse) or not depotTarget.warehouse.bIsUnlocked) then
        done('Önce kendi açık mağaza deponu seç.',0); return
    end
    if nd>0 then
        local inv=depotTarget.warehouse.BP_TradableInventory_Comp
        if inv.Capacity-inv.CurrentAmount<nd then done('Depoda bütün seçili eşyalara yer yok. İşlem başlatılmadı.',0); return end
    end
    local deposited=0
    local function sellRest()
        if ns==0 then done(string.format('%d depoya gönderildi; %d bekletildi.',deposited,nh),deposited); return end
        M.sell(c,source,saleKey,parts.sell,function(message,n,halt)
            done(string.format('%d depoya; %d satıldı; %d bekletildi. %s',deposited,n,nh,message),deposited+n,halt or n~=ns)
        end,function(r) return Items.action(r,snapshot)=='sell' end)
    end
    if nd==0 then sellRest(); return end
    M.deposit(c,source,depotKey,parts.depot,function(message,n)
        deposited=n
        if n~=nd then done(message..' Ayırma durdu; satış başlatılmadı.',n,true); return end
        sellRest()
    end,function(r) return Items.action(r,snapshot)=='depot' end)
end
return M
