-- Read-only item metadata and routing decisions; never infer unknown rarity as Common.
local M = {}
M.qualities = {
    {value=1,label='Yaygın'}, {value=2,label='Nadir'}, {value=3,label='Epik'},
    {value=4,label='Efsanevi'}, {value=5,label='Benzersiz'}, {value=0,label='Bilinmiyor'},
}
local collectorField='AssignedCollectorType_174_A1086401466DCD2A33FE7FB241E8CDC2'
local function value(v)
    if v==nil then return '' end
    if type(v)=='userdata' then local ok,s=pcall(function() return v:ToString() end); if ok then return s end end
    return tostring(v)
end
function M.qualityLabel(n)
    for _,q in ipairs(M.qualities) do if q.value==n then return q.label end end
    return 'Bilinmiyor'
end
function M.collectors()
    local index={}
    for _,npc in ipairs(FindAllOf('BP_NPCCollector_C') or {}) do
        pcall(function()
            if not npc:IsValid() or not npc.CollectorData:IsValid() then return end
            local label=value(npc.CollectorData.CollectorName)
            local week,taken={},{}
            npc.CurrentWeekItemsID:ForEach(function(i,e) week[value(e:get())]=i end)
            npc.CurrentWeekTakenStatus:ForEach(function(i,e) taken[i]=e:get()==true end)
            npc.AllItemsID:ForEach(function(_,e)
                local id=value(e:get()); local wi=week[id]
                index[id]={label=label,wanted=wi~=nil and not taken[wi]}
            end)
        end)
    end
    return index
end
function M.describe(o, collectors)
    local rarity,collectorType,id=0,nil,''
    pcall(function()
        local n=tonumber(o.Rarity)
        if o.IsRarityKnown==true and n and n>=1 and n<=5 and n%1==0 then rarity=n end
    end)
    pcall(function() id=value(o.ID) end)
    pcall(function() collectorType=tonumber(o.SharedData[collectorField]) end)
    local entry=collectors[id] or collectors[id:match('([^/]+)$')]
    local collectible=entry~=nil or (collectorType~=nil and collectorType>0)
    local saleReady=false
    pcall(function() saleReady=o.IsVerified==true end)
    return {rarity=rarity,quality=M.qualityLabel(rarity),collectible=collectible,saleReady=saleReady,
        collector=entry and entry.label or (collectible and 'Koleksiyoncu' or nil),
        wanted=entry and entry.wanted==true or false,
        collectionKnown=entry~=nil or collectorType~=nil}
end
function M.action(row, rules)
    if row.collectible then return rules.collectorDepot and 'depot' or 'hold' end
    if not row.collectionKnown or row.rarity==0 then return 'hold' end
    if rules.sell[row.rarity]==true then return row.saleReady and 'sell' or 'hold' end
    return 'depot'
end
function M.partition(rows, keys, rules)
    local result={sell={},depot={},hold={}}
    for _,r in ipairs(rows) do
        if not keys or keys[r.key] then result[M.action(r,rules)][r.key]=true end
    end
    return result
end
return M
