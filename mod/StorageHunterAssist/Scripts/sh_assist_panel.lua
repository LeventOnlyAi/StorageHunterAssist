local M={}
function M.start(c, time, notify, options)
    local Menu=require('ModMenu.ModMenu')
    local R=require('sh_assist_remote')
    local Items=require('sh_assist_items')
    local state={source='both',mode='sort',target=nil,saleTarget=nil,auto=false,rows={},ids={},serial=0,
        rules={sell={[1]=true},collectorDepot=false},signature=nil,groups={}}
    local refresh,targets,syncSelection
    local function status(s) Menu.SetLabel('Transfer','status',s) end
    local function stopAuto()
        state.auto=false; Menu.Set('Transfer','auto',false)
    end
    local function later(fn)
        ExecuteWithDelay(100,function() ExecuteInGameThread(function()
            local ok,e=pcall(fn)
            if not ok then
                stopAuto(); Menu.SetButtonEnabled('Transfer','run',true)
                notify('Panel işlemi durdu. Günlük dosyasını kontrol et.')
                print('[StorageHunterAssist] PANEL ERROR '..tostring(e)..'\n')
            end
        end) end)
    end
    local function selectedKeys()
        local keys={}
        for _,r in ipairs(state.rows) do if Menu.Get('Items',state.ids[r.key])==true then keys[r.key]=true end end
        return keys
    end
    syncSelection=function()
        local keys,n=selectedKeys(),0
        for _ in pairs(keys) do n=n+1 end
        for _,g in ipairs(state.groups) do
            local all=#g.rows>0
            for _,r in ipairs(g.rows) do if not keys[r.key] then all=false; break end end
            Menu.Set('Items',g.id,all)
        end
        local parts=Items.partition(state.rows,keys,state.rules)
        local ns,nd,nh=0,0,0
        for _ in pairs(parts.sell) do ns=ns+1 end
        for _ in pairs(parts.depot) do nd=nd+1 end
        for _ in pairs(parts.hold) do nh=nh+1 end
        Menu.SetLabel('Transfer','selection',string.format('Seçili: %d | Kalite kuralı: %d sat / %d depo / %d beklet.',n,ns,nd,nh))
    end
    local function finish(message,count,halt)
        if halt then stopAuto() end
        status(message); notify(message)
        Menu.SetButtonEnabled('Transfer','run',true)
        later(function() refresh(true) end)
    end
    local function execute(keys,done)
        if state.mode=='sort' then R.sort(c,state.source,state.saleTarget,state.target,keys,state.rules,done)
        elseif state.mode=='sell' then R.sell(c,state.source,state.target,keys,done)
        else R.deposit(c,state.source,state.target,keys,done) end
    end
    local function run()
        if R.isBusy() then status('Önceki işlem sürüyor.'); return end
        local keys=selectedKeys()
        if not next(keys) then status('Eşyalar sekmesinden ürün veya kalite grubu seç.'); return end
        Menu.SetButtonEnabled('Transfer','run',false); status('İşleniyor...')
        execute(keys,finish)
    end
    targets=function()
        local opts,sales,allowed,saleAllowed={},{},{},{}
        for _,d in ipairs(R.catalog()) do
            sales[#sales+1]={label=d.label,value=d.key}; saleAllowed[d.key]=true
            if state.mode=='sell' or d.owned then
                local label=d.label
                if state.mode~='sell' and R.valid(d.warehouse) then
                    local inv=d.warehouse.BP_TradableInventory_Comp
                    if R.valid(inv) then label=label..string.format(' [%d/%d]',inv.CurrentAmount,inv.Capacity) end
                end
                opts[#opts+1]={label=label,value=d.key}; allowed[d.key]=true
            end
        end
        if not allowed[state.target] then state.target=opts[1] and opts[1].value or nil end
        if not saleAllowed[state.saleTarget] then state.saleTarget=sales[1] and sales[1].value or nil end
        if #opts==0 then opts[1]={label='Uygun mağaza yok',value=''} end
        if #sales==0 then sales[1]={label='Satış noktası yok',value=''} end
        Menu.SetOptions('Transfer','target',opts,state.target or false)
        Menu.SetOptions('Transfer','saleTarget',sales,state.saleTarget or false)
        Menu.SetButtonLabel('Transfer','run',state.mode=='sort' and 'Seçilenleri KALİTEYE GÖRE AYIR'
            or (state.mode=='sell' and 'Seçilenleri SAT' or 'Seçilenleri DEPOYA GÖNDER'))
    end
    refresh=function(preserveStatus,scanned,passive)
        local rows,reason
        if scanned then rows=scanned else rows,reason=R.scan(c,state.source) end
        local signature={state.source,reason or ''}
        for _,r in ipairs(rows) do signature[#signature+1]=table.concat({r.key,r.source,r.label,r.quality,r.collector or '',tostring(r.wanted),tostring(r.saleReady)},'|') end
        signature=table.concat(signature,'\n')
        state.rows=rows
        if passive and signature==state.signature then return end
        state.signature=signature
        local items,groups={},{}
        local function group(id,label,members)
            local g={id=id,rows=members}; groups[#groups+1]=g
            items[#items+1]={type='checkbox',id=id,label=label..' ('..#members..') — tümünü seç',default=false,
                onChange=function(v)
                    for _,r in ipairs(g.rows) do Menu.Set('Items',state.ids[r.key],v) end
                    syncSelection()
                end}
            for _,r in ipairs(members) do
                if not state.ids[r.key] then state.serial=state.serial+1; state.ids[r.key]='i'..state.serial end
                items[#items+1]={type='checkbox',id=state.ids[r.key],
                    label='['..r.quality..' / '..r.source..'] '..r.label..(r.wanted and ' ★ BU HAFTA ARANIYOR' or '')..(not r.saleReady and ' [Doğrulanmadı: satış bekler]' or ''),
                    default=false,onChange=syncSelection}
            end
        end
        for _,q in ipairs(Items.qualities) do
            local members={}
            for _,r in ipairs(rows) do if not r.collectible and r.rarity==q.value then members[#members+1]=r end end
            group('q'..q.value,q.label,members)
        end
        items[#items+1]={type='label',label='KOLEKSİYONLUKLAR — kalite gruplarından ayrı tutulur'}
        local byCollector,names={},{}
        for _,r in ipairs(rows) do if r.collectible then
            local label=r.collector or 'Koleksiyoncu'
            if not byCollector[label] then byCollector[label]={}; names[#names+1]=label end
            byCollector[label][#byCollector[label]+1]=r
        end end
        table.sort(names)
        if #names==0 then items[#items+1]={type='label',label='Bu kaynakta koleksiyonluk eşya yok.'} end
        for _,label in ipairs(names) do group('collector_'..label,'Koleksiyonluk — '..label,byCollector[label]) end
        if #rows==0 then table.insert(items,1,{type='label',label=reason or 'Uygun eşya yok.'}) end
        state.groups=groups
        Menu.Register({id='Items',title='Eşyalar ('..#rows..')',tab='Eşyalar',items=items})
        targets(); syncSelection()
        if not preserveStatus then status(string.format('%d uygun eşya. Liste açıkken kendini yeniler. Yakın: %d m | Kamyon: %d m.',#rows,c.NearRangeCm/100,c.TruckRangeCm/100)) end
    end
    Menu.Init({title='Storage Hunter | Kalite ve Koleksiyon',instanceId=options and options.instanceId or 'SHAssist',
        key=options and options.key or Key.F8,keyHint=options and options.keyHint or 'F8',
        dock='right',widthFrac=0.46,theme='dark',ignoreLook=true,
        tabs={'Aktarım','Eşyalar','Kurallar','Zaman'},canOpen=function() local p,e=R.ready(); return p~=nil,e end})
    Menu.Register({id='Transfer',title='Hedef ve işlem',tab='Aktarım',items={
        {type='label',label='Eşyalar sekmesinde kalite kutusunu veya tek tek ürünleri seç.'},
        {type='dropdown',id='source',label='Kaynak',default='both',options={
            {label='Kamyon + yakınımdaki eşyalar',value='both'},
            {label='Yalnız kamyondaki eşyalar',value='truck'},
            {label='Yalnız yakınımdaki eşyalar',value='near'}},
            onChange=function(v) state.source=v; stopAuto(); later(refresh) end},
        {type='dropdown',id='mode',label='İşlem',default='sort',options={
            {label='Kaliteye göre ayır: SAT / DEPO',value='sort'},
            {label='Hepsini mağazamın deposuna gönder',value='depot'},
            {label='Hepsini satış noktasında doğrudan sat',value='sell'}},
            onChange=function(v) state.mode=v; stopAuto(); later(function() targets(); syncSelection() end) end},
        {type='dropdown',id='target',label='Depo mağazam (SAT modunda: satış bölgesi)',options={{label='Listeyi yenile',value=''}},allowEmpty=true,
            onChange=function(v) state.target=v; stopAuto() end},
        {type='dropdown',id='saleTarget',label='Kaliteye göre ayırma: satış bölgesi',options={{label='Listeyi yenile',value=''}},allowEmpty=true,
            onChange=function(v) state.saleTarget=v; stopAuto() end},
        {type='label',id='selection',label='Seçili: 0'},
        {type='label',id='status',label='Liste yükleniyor...'},
        {type='button',id='refresh',label='Listeyi yenile',onClick=function() later(refresh) end},
        {type='button',id='run',label='Seçilenleri KALİTEYE GÖRE AYIR',variant='primary',onClick=function() later(run) end},
        {type='checkbox',id='auto',label='Otomatik: kaynakta bulunan tüm uygun ürünlere uygula',default=false,onChange=function(v)
            if v and (state.mode=='sell' or not state.target or (state.mode=='sort' and not state.saleTarget)) then
                stopAuto(); status('Otomatik için ayırma/depo modunu ve hedeflerini seç.'); return
            end
            state.auto=v
            status(v and 'OTOMATİK AÇIK: seçim kutularını kullanmaz. Ayırma modunda kurala göre SATAR / depolar.' or 'Otomatik KAPALI.')
        end},
        {type='label',label='Yaygın SAT; diğer kaliteler DEPO. Koleksiyonluk / bilinmeyen / satış için doğrulanmamış BEKLET.'},
        {type='label',label='SAT modu seçtiğin koleksiyonlukları da satar. Otomatik, her açılışta kapalıdır.'},
    }})
    Menu.Register({id='Selection',title='Toplu seçim',tab='Eşyalar',items={
        {type='row',items={
            {type='button',id='refresh',label='Yenile',onClick=function() later(refresh) end},
            {type='button',id='all',label='Tümünü seç',onClick=function()
                for _,r in ipairs(state.rows) do Menu.Set('Items',state.ids[r.key],true) end; syncSelection()
            end},
            {type='button',id='none',label='Seçimi temizle',onClick=function()
                for _,r in ipairs(state.rows) do Menu.Set('Items',state.ids[r.key],false) end; syncSelection()
            end}}},
        {type='label',label='Kalite başlığındaki kutu o gruptaki ürünleri seçer. İşlem için Aktarım sekmesine dön.'},
    }})
    Menu.Register({id='Items',title='Eşyalar',tab='Eşyalar',items={{type='label',label='Liste yükleniyor...'}}})
    local rules={{type='label',label='İşaretli kalite SATILIR; işaretsiz kalite seçtiğin DEPOYA gider. Yalnız ayırma modu içindir.'}}
    for _,q in ipairs(Items.qualities) do if q.value>0 then
        local n=q.value
        rules[#rules+1]={type='checkbox',id='sell'..n,label=q.label..' ürünleri SAT',default=n==1,
            onChange=function(v) state.rules.sell[n]=v; stopAuto(); syncSelection() end}
    end end
    rules[#rules+1]={type='checkbox',id='collectorDepot',label='Koleksiyonlukları bekletmek yerine seçtiğim DEPOYA gönder',default=false,
        onChange=function(v) state.rules.collectorDepot=v; stopAuto(); syncSelection() end}
    rules[#rules+1]={type='label',label='Koleksiyonluklar kalite kuralıyla satılmaz. ★ bu hafta aranan, henüz teslim edilmemiş ürün demektir.'}
    rules[#rules+1]={type='label',label='Kalitesi veya koleksiyon bilgisi okunamayan ürünler ayırmada bekler. İstersen elle depo/sat modunu kullan.'}
    rules[#rules+1]={type='label',label='Satış ürünlerini önce oyunda doğrula. Doğrulanmamış satış bekler; mod otomatik doğrulama yapmaz.'}
    Menu.Register({id='Rules',title='Kalite kuralları',tab='Kurallar',items=rules})
    local steps={}; for _,n in ipairs(c.TimeSteps) do steps[#steps+1]={label=n..' dakika',value=n} end
    Menu.Register({id='Time',title='Zamanı ileri al',tab='Zaman',items={
        {type='label',label='F6: ileri al | F7: süreyi değiştir | F5: kısa yardım'},
        {type='dropdown',id='step',label='Atlama süresi',options=steps,default=time.GetStep(),onChange=function(v) time.SetStep(v) end},
        {type='button',id='skip',label='Seçili süre kadar ileri al',onClick=time.Skip},
        {type='label',label='Gün sonundan önce durur. Sonraki gün için yatakta uyu.'}
    }})
    Menu.OnOpen(function() later(function() refresh(); Menu.Set('Time','step',time.GetStep()) end) end)
    LoopAsync(c.AutoDepositPollMs,function()
        if state.auto or Menu.IsOpen() then later(function()
            if R.isBusy() then return end
            local rows,reason=R.scan(c,state.source)
            if Menu.IsOpen() then refresh(true,reason and nil or rows,true) end
            if not state.auto then return end
            local keys={}
            for _,r in ipairs(rows) do
                if state.mode~='sort' or Items.action(r,state.rules)~='hold' then keys[r.key]=true end
            end
            if next(keys) then execute(keys,function(message,count,halt)
                status(message)
                if count==0 or halt then stopAuto(); notify(message..' Otomatik kapatıldı.') end
                later(function() refresh(true) end)
            end) end
        end) end
        return false
    end)
    M.Menu,M.State,M.Refresh,M.Run,M.SelectedKeys=Menu,state,refresh,run,selectedKeys
    M.StopAuto=stopAuto
    return M
end
return M
