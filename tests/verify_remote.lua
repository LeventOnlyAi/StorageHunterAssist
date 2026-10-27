package.path='mod/StorageHunterAssist/Scripts/?.lua;'..package.path
local core=require('sh_assist_core')
local c=core.validate(require('sh_assist_config'))
local count=0
for minute=0,1439 do for _,step in ipairs(c.TimeSteps) do
    local target,delta=core.timeTarget(9*1440+minute,step,c)
    if minute>=1437 then assert(target==nil and delta==0)
    else
        assert(delta>0 and delta<=step and minute+delta<=1437)
        assert(math.abs(((target/100*60)-480)%1440-(minute+delta))<0.00001)
    end
    count=count+1
end end
local function obj(t) t=t or {}; t.IsValid=function() return true end; return t end
local function arr(values) return {ForEach=function(_,fn) for i,v in ipairs(values) do fn(i-1,{get=function() return v end}) end end} end
local origin={X=0,Y=0,Z=0}
local player=obj({HasAuthority=function() return true end,GetOwnerID=function() return 'CurrentPlayer' end,K2_GetActorLocation=function() return origin end})
package.loaded.UEHelpers={GetPlayer=function() return player end,GetPlayerController=function() return obj() end}
local nativeCalls,cash,queue=0,100,{}
player.PlayerState={GetPlayerCredits=function() return cash end}
local inv=obj({CurrentAmount=1,Capacity=5})
local warehouse=obj({bIsUnlocked=true,BP_TradableInventory_Comp=inv,OnTradableItemOverlappedDropZone=function(_,a,include,out)
    assert(include); nativeCalls=nativeCalls+1; inv.CurrentAmount=inv.CurrentAmount+1; out.WasItemAdded=true
end})
local area=obj()
local shop=obj({['As BP Trader Area']=area})
local owner=obj({IsUnlocked=true,OwnerID='LegacyPlayer',PawnShop=shop,BP_WarehousePawnshop=warehouse,
    PA_PawnShop_Data=obj({PawnshopID='Owned',PawnshopName='Owned shop'})})
local other=obj({IsUnlocked=false,OwnerID='SomeoneElse',PawnShop=shop,BP_WarehousePawnshop=warehouse,
    PA_PawnShop_Data=obj({PawnshopID='Other',PawnshopName='Other shop'})})
local function item(id,ownerId,x)
    return obj({OwnerPlayerID=ownerId or 'LegacyPlayer',IsVerified=true,GetFullName=function() return id end,
        K2_GetActorLocation=function() return {X=x or 10,Y=0,Z=0} end,
        GetItemName=function(_,out) out.ItemName=id end})
end
local a,b,unowned,foreign,far=item('a'),item('b'),item('u','None'),item('f','SomeoneElse'),item('far',nil,100000)
local held=item('held'); held.IsInPickingUpMode=true
local shelved=item('shelf'); shelved.IsInPawnShop=true
local inside=item('inside'); inside.IsInsideContainer=true
local packed=item('packed'); packed.IsAddedToWarehouse=true
local world={a,b,unowned,foreign,far,held,shelved,inside,packed}
local trunk=obj({TradableItemsRegisterBox=obj({K2_GetComponentLocation=function() return origin end}),PackedTradableItems=arr({a})})
function FindAllOf(class)
    if class=='BP_OwnerPawnShopController_C' then return {owner,other} end
    if class=='BP_Vehicle_Trunk_C' then return {trunk} end
    if class=='BP_TradableItemBase_C' then return world end
    return {}
end
local saleRows={}
local widget=obj({Init=function(_,target) assert(target==area) end,
    SpawnItems=function(_,actors,target)
        assert(target==shop); saleRows={}
        for i,v in ipairs(actors) do saleRows[#saleRows+1]=obj({['Tradable Item']=v,Index=i,ItemId='x',AssignedIndividualData={}}) end
    end,
    AddToViewport=function() end,SetVisibility=function() end,RemoveFromParent=function() end,
    OnClicked_PawnShopWarehouseItems_QuickSell_Event=function(_,actor) nativeCalls=nativeCalls+1; cash=cash+50 end})
widget.WBP_PawnShop_WarehouseItems=setmetatable({},{__index=function(_,k) if k=='PresetsArray' then return arr(saleRows) end end})
function StaticFindObject(path)
    if path:find('GameplayStatics',1,true) then return obj({IsGamePaused=function() return false end}) end
    if path:find('WidgetBlueprintLibrary',1,true) then return obj({Create=function() return widget end}) end
    return obj()
end
function ExecuteWithDelay(_,fn) queue[#queue+1]=fn end
function ExecuteInGameThread(fn) fn() end
local function drain() local q=queue; queue={}; for _,fn in ipairs(q) do fn() end end
local function fresh() package.loaded.sh_assist_remote=nil; return require('sh_assist_remote') end
local r=fresh()
assert(#r.catalog()==2)
local rows=r.scan(c,'both'); assert(#rows==2 and rows[1].source=='Kamyon')
assert(#r.scan(c,'truck')==1 and #r.scan(c,'near')==2)
local keys={a=true,b=true,u=true,f=true,far=true,held=true,shelf=true,inside=true,packed=true}
local got
r.deposit(c,'both','Other',keys,function(_,n) got=n end); assert(got==0 and nativeCalls==0)
inv.CurrentAmount=5
r.deposit(c,'both','Owned',keys,function(_,n) got=n end); assert(got==0 and nativeCalls==0)
inv.CurrentAmount=1
r.deposit(c,'both','Owned',keys,function(_,n) got=n end); assert(got==2 and nativeCalls==2 and inv.CurrentAmount==3)
r.deposit(c,'both','Owned',keys,function(_,n) got=n end); assert(got==0 and nativeCalls==2)
-- Stale selection moved beyond the active source range.
r=fresh(); trunk.PackedTradableItems=arr({}); world={far}
r.deposit(c,'near','Owned',{far=true},function(_,n) got=n end); assert(got==0 and nativeCalls==2)
-- Two overlapping sale requests must call the native sale route exactly once per item.
r=fresh(); world={a,b}; trunk.PackedTradableItems=arr({a})
r.sell(c,'both','Other',keys,function(_,n) got=n end); assert(r.isBusy())
r.sell(c,'both','Other',keys,function(_,n) assert(n==0) end)
drain(); assert(got==2 and nativeCalls==4 and cash==200 and not r.isBusy())
r.sell(c,'both','Other',keys,function(_,n) got=n end); drain(); assert(got==0 and nativeCalls==4)
-- Native actor pooling reuses a successfully sold full name for future goods.
a.OwnerPlayerID='None'; world={a}; r.scan(c,'near')
a.OwnerPlayerID='LegacyPlayer'; assert(#r.scan(c,'near')==1,'recycled acquired actor remained invisible')
-- Cleanup must also run in truck-only mode, after the old actor leaves cargo.
r=fresh(); world={a}; trunk.PackedTradableItems=arr({a})
local beforePoolCalls=nativeCalls
r.sell(c,'truck','Other',{a=true},function() end); drain()
a.OwnerPlayerID='None'; trunk.PackedTradableItems=arr({}); r.scan(c,'truck')
a.OwnerPlayerID='LegacyPlayer'; trunk.PackedTradableItems=arr({a})
assert(#r.scan(c,'truck')==1,'truck-only actor reuse remained invisible')
-- Restore the existing transaction-count fixture after this isolated sale.
nativeCalls=beforePoolCalls; cash=200
-- An ambiguous engine failure latches the actor and never retries it automatically.
r=fresh(); world={a}; trunk.PackedTradableItems=arr({})
warehouse.OnTradableItemOverlappedDropZone=function() nativeCalls=nativeCalls+1; error('ambiguous native failure') end
r.deposit(c,'near','Owned',{a=true},function() end)
r.deposit(c,'near','Owned',{a=true},function(_,n) assert(n==0) end)
assert(nativeCalls==5 and not r.isBusy())
print('PASS: '..count..' time boundaries; ownership, held/container/shelf guards; truck deduplication; stale range; capacity; owned destinations; exactly-once deposit/sale; overlapping requests; ambiguous failure latch.')

-- 0.3: per-item failures must not hide the rest of the nearby list.
r=fresh(); world={item('bad-name'),item('good-name')}
world[1].GetItemName=function() error('name not ready') end
local oldRemote=rawget(_G,'REGRESSION_OLD_REMOTE')
if oldRemote then r=assert(loadfile(oldRemote))() end
assert(pcall(function() rows=r.scan(c,'near'); assert(#rows==2) end),'a name failure hid nearby goods')
if oldRemote then return end
local broken=item('invalid'); broken.IsValid=function() error('expired handle') end
world={broken,item('still-visible')}; assert(#r.scan(c,'near')==1)

local items=require('sh_assist_items')
local field='AssignedCollectorType_174_A1086401466DCD2A33FE7FB241E8CDC2'
local function graded(id,rarity,collector)
    local o=item(id); o.ID='BasicTradables/'..id; o.Rarity=rarity; o.IsRarityKnown=true
    o.SharedData={[field]=collector or 0}; return o
end
local common,rare,collect,unknown=graded('common',1),graded('rare',3),graded('collection',1,2),graded('unknown',2)
unknown.IsRarityKnown=false
local meta=items.describe(collect,{collection={label='Arkeolog',wanted=true}})
assert(meta.collectible and meta.collector=='Arkeolog' and meta.wanted and meta.quality=='Yaygın')
assert(items.describe(unknown,{}).rarity==0)
local unverified=graded('unverified',1); unverified.IsVerified=false
local rules={sell={[1]=true},collectorDepot=false}
assert(items.action(items.describe(unverified,{}),rules)=='hold')
local missing=items.describe(item('missing-metadata'),{})
assert(items.action(missing,rules)=='hold')
local entries={}
for _,o in ipairs({common,rare,collect,unknown}) do local row=items.describe(o,{}); row.key=o:GetFullName(); entries[#entries+1]=row end
local parts=items.partition(entries,nil,rules)
assert(parts.sell.common and parts.depot.rare and parts.hold.collection and parts.hold.unknown)
rules.collectorDepot=true; assert(items.partition(entries,nil,rules).depot.collection)
rules.collectorDepot=false
rules.sell[3]=true; assert(items.partition(entries,nil,rules).sell.rare); rules.sell[3]=false

-- Native collector names use bare IDs; tradables use a folder-prefixed ID.
local npc=obj({CollectorData=obj({CollectorName='Arkeolog'}),AllItemsID=arr({'collection','delivered'}),
    CurrentWeekItemsID=arr({'collection','delivered'}),CurrentWeekTakenStatus=arr({false,true})})
local baseFind=FindAllOf
FindAllOf=function(class) if class=='BP_NPCCollector_C' then return {npc} end; return baseFind(class) end
local ci=items.collectors(); assert(ci.collection.wanted and not ci.delivered.wanted)
assert(items.describe(collect,ci).collector=='Arkeolog')

-- Mixed batch: the low-quality collectible must remain untouched.
local normalDeposit=function(_,actor,include,out)
    assert(include); nativeCalls=nativeCalls+1; inv.CurrentAmount=inv.CurrentAmount+1; out.WasItemAdded=true
end
warehouse.OnTradableItemOverlappedDropZone=normalDeposit
world={unverified}; trunk.PackedTradableItems=arr({}); r=fresh(); local saleCalls=nativeCalls
r.sell(c,'near','Other',{unverified=true},function(_,n,halt) assert(n==0 and halt) end)
drain(); assert(nativeCalls==saleCalls)
inv.CurrentAmount=1; world={common,rare,collect,unknown}; trunk.PackedTradableItems=arr({common})
r=fresh(); local beforeCalls,beforeCash=nativeCalls,cash
local mixedKeys={common=true,rare=true,collection=true,unknown=true}
r.sort(c,'both','Other','Owned',mixedKeys,rules,function(_,n) got=n end)
assert(r.isBusy() and inv.CurrentAmount==2); drain()
assert(got==2 and nativeCalls==beforeCalls+2 and cash==beforeCash+50)
local remaining=r.scan(c,'both'); assert(#remaining==2 and remaining[1].collectible~=nil)
-- Preflight prevents a full depot from selling the other half of the batch.
r=fresh(); inv.CurrentAmount=5; beforeCalls=nativeCalls
r.sort(c,'both','Other','Owned',mixedKeys,rules,function(_,n) got=n end); drain()
assert(got==0 and nativeCalls==beforeCalls)
-- A partial warehouse rejection must never start sale, even after one deposit.
r=fresh(); inv.CurrentAmount=0; world={common,rare,graded('rare2',2)}; mixedKeys.rare2=true
local calls=0
warehouse.OnTradableItemOverlappedDropZone=function(_,actor,include,out)
    calls=calls+1; out.WasItemAdded=calls==1
    if calls==1 then inv.CurrentAmount=inv.CurrentAmount+1 end
end
local halted=false; beforeCash=cash
r.sort(c,'both','Other','Owned',mixedKeys,rules,function(_,n,halt) got=n; halted=halt end); drain()
assert(got==1 and halted and cash==beforeCash)
warehouse.OnTradableItemOverlappedDropZone=normalDeposit
-- Recheck range and classification after native sale UI is constructed.
r=fresh(); world={common}; trunk.PackedTradableItems=arr({}); inv.CurrentAmount=0; beforeCash=cash
r.sort(c,'near','Other','Owned',{common=true},rules,function(_,n,halt) got=n; halted=halt end)
common.IsInPickingUpMode=true; drain(); assert(got==0 and halted and cash==beforeCash); common.IsInPickingUpMode=false
r=fresh(); r.sort(c,'near','Other','Owned',{common=true},rules,function(_,n) got=n end)
common.Rarity=3; drain(); assert(got==0 and cash==beforeCash); common.Rarity=1
r=fresh(); r.sell(c,'near','Other',{common=true},function(_,n) got=n end)
common.IsVerified=false; drain(); assert(got==0 and cash==beforeCash); common.IsVerified=true
print('PASS: quality routes; unknown/collectible protection; collector names and weekly status; mixed deposit/sale; full and partially rejecting depots; delayed sale changes; per-item scan isolation.')

-- Reproduce the stale-list bug with automatic transfer OFF and the panel OPEN.
local sections,values,loops={},{},{}
local registerCount=0
local menu={}
function menu.Init() end
function menu.Register(s)
    sections[s.id]=s; registerCount=registerCount+1
    local function seed(list) for _,i in ipairs(list) do
        if i.id and values[s.id..'.'..i.id]==nil then values[s.id..'.'..i.id]=i.default end
        if i.items then seed(i.items) end
    end end
    seed(s.items)
end
function menu.Get(s,i) return values[s..'.'..i] end
function menu.Set(s,i,v) values[s..'.'..i]=v end
function menu.SetLabel() end
function menu.SetOptions() end
function menu.SetButtonLabel() end
function menu.SetButtonEnabled() end
function menu.OnOpen(fn) menu.open=fn end
function menu.IsOpen() return true end
package.loaded['ModMenu.ModMenu']=menu
function LoopAsync(_,fn) loops[#loops+1]=fn end
Key={F8=119}
world={common}; package.loaded.sh_assist_remote=nil; package.loaded.sh_assist_panel=nil
local uiCalls,uiCash=nativeCalls,cash
local panel=require('sh_assist_panel').start(c,{GetStep=function() return 60 end,SetStep=function() end,Skip=function() end},function() end)
menu.open(); drain(); assert(#panel.State.rows==1 and not panel.State.auto)
local function control(section,id)
    for _,i in ipairs(sections[section].items) do if i.id==id then return i end end
end
control('Items','q1').onChange(true); assert(panel.SelectedKeys().common)
world={common,rare,collect}; loops[1](); drain()
assert(#panel.State.rows==3 and panel.SelectedKeys().common and not panel.SelectedKeys().rare)
local previousRegisters=registerCount; loops[1](); drain(); assert(registerCount==previousRegisters,'unchanged scan rebuilt UI')
local cg=control('Items','collector_Arkeolog'); assert(cg); cg.onChange(true); assert(panel.SelectedKeys().collection)
control('Rules','sell3').onChange(true); assert(panel.State.rules.sell[3])
menu.Set('Transfer','auto',true); control('Transfer','auto').onChange(true); assert(panel.State.auto)
control('Rules','sell3').onChange(false); assert(not panel.State.auto)
assert(nativeCalls==uiCalls and cash==uiCash) -- UI polling never executes a transaction while auto is off.
print('PASS: live nearby refresh while auto OFF; stable selections; unchanged UI not rebuilt; quality and collector group selection; rule changes stop automation.')

