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
    return obj({OwnerPlayerID=ownerId or 'LegacyPlayer',GetFullName=function() return id end,
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
-- An ambiguous engine failure latches the actor and never retries it automatically.
r=fresh(); world={a}; trunk.PackedTradableItems=arr({})
warehouse.OnTradableItemOverlappedDropZone=function() nativeCalls=nativeCalls+1; error('ambiguous native failure') end
r.deposit(c,'near','Owned',{a=true},function() end)
r.deposit(c,'near','Owned',{a=true},function(_,n) assert(n==0) end)
assert(nativeCalls==5 and not r.isBusy())
print('PASS: '..count..' time boundaries; ownership, held/container/shelf guards; truck deduplication; stale range; capacity; owned destinations; exactly-once deposit/sale; overlapping requests; ambiguous failure latch.')

