local M={}
function M.start(c, time, notify, options)
    local Menu=require('ModMenu.ModMenu')
    local R=require('sh_assist_remote')
    local state={source='both',mode='depot',target=nil,auto=false,rows={},ids={},serial=0}
    local refresh, targets
    local function status(s) Menu.SetLabel('Transfer','status',s) end
    local function later(fn)
        ExecuteWithDelay(100,function() ExecuteInGameThread(function()
            local ok,e=pcall(fn)
            if not ok then state.auto=false; Menu.Set('Transfer','auto',false); notify('Panel işlemi durdu. Günlük dosyasını kontrol et.'); print('[StorageHunterAssist] PANEL ERROR '..tostring(e)..'\n') end
        end) end)
    end
    local function stopAuto()
        state.auto=false; Menu.Set('Transfer','auto',false)
    end
    local function finish(message,count)
        status(message); notify(message)
        Menu.SetButtonEnabled('Transfer','run',true)
        later(function() refresh(true) end)
    end
    local function selectedKeys()
        local keys={}
        for _,r in ipairs(state.rows) do
            if Menu.Get('Items',state.ids[r.key])==true then keys[r.key]=true end
        end
        return keys
    end
    local function run()
        if R.isBusy() then status('Önceki işlem sürüyor.'); return end
        local keys=selectedKeys()
        if not next(keys) then status('Önce aşağıdan eşya seç veya Tümünü seç düğmesine bas.'); return end
        Menu.SetButtonEnabled('Transfer','run',false)
        status('İşleniyor...')
        local ok,e=pcall(function()
            if state.mode=='sell' then R.sell(c,state.source,state.target,keys,finish)
            else R.deposit(c,state.source,state.target,keys,finish) end
        end)
        if not ok then Menu.SetButtonEnabled('Transfer','run',true); error(e) end
    end
    targets=function()
        local opts,allowed={},{ }
        for _,d in ipairs(R.catalog()) do
            if state.mode=='sell' or d.owned then
                local label=d.label
                if state.mode=='depot' and R.valid(d.warehouse) then
                    local inv=d.warehouse.BP_TradableInventory_Comp
                    if R.valid(inv) then label=label..string.format(' [%d/%d]',inv.CurrentAmount,inv.Capacity) end
                end
                opts[#opts+1]={label=label,value=d.key}; allowed[d.key]=true
            end
        end
        if not allowed[state.target] then state.target=opts[1] and opts[1].value or nil end
        if #opts==0 then opts[1]={label='Uygun mağaza yok',value=''} end
        Menu.SetOptions('Transfer','target',opts,state.target or false)
        Menu.SetButtonLabel('Transfer','run',state.mode=='sell' and 'Seçilenleri SAT' or 'Seçilenleri DEPOYA GÖNDER')
    end
    refresh=function(preserveStatus)
        local rows,reason=R.scan(c,state.source)
        state.rows=rows
        local items={}
        if #rows==0 then items[1]={type='label',label=reason or 'Uygun eşya yok. Kamyonuna yaklaş veya kendi eşyanı yere bırak.'} end
        for _,r in ipairs(rows) do
            if not state.ids[r.key] then state.serial=state.serial+1; state.ids[r.key]='i'..state.serial end
            items[#items+1]={type='checkbox',id=state.ids[r.key],label='['..r.source..'] '..r.label,default=false}
        end
        Menu.Register({id='Items',title='Eşyalar ('..#rows..')',tab='Aktarım',items=items})
        targets()
        if not preserveStatus then status(string.format('%d uygun eşya. Yakın: %d m | Kamyon: %d m.',#rows,c.NearRangeCm/100,c.TruckRangeCm/100)) end
    end
    Menu.Init({title='Storage Hunter | Satış ve Depo',instanceId=options and options.instanceId or 'SHAssist',
        key=options and options.key or Key.F8,keyHint=options and options.keyHint or 'F8',
        dock='right',widthFrac=0.43,theme='dark',ignoreLook=true,
        tabs={'Aktarım','Zaman'},canOpen=function() local p,e=R.ready(); return p~=nil,e end})
    Menu.Register({id='Transfer',title='Hedef ve işlem',tab='Aktarım',items={
        {type='label',label='Sadece sana ait, yerdeki veya kamyondaki eşyalar.'},
        {type='dropdown',id='source',label='Kaynak',default='both',options={
            {label='Kamyon + yakınımdaki eşyalar',value='both'},
            {label='Yalnız kamyondaki eşyalar',value='truck'},
            {label='Yalnız yakınımdaki eşyalar',value='near'}},
            onChange=function(v) state.source=v; stopAuto(); later(refresh) end},
        {type='dropdown',id='mode',label='İşlem',default='depot',options={
            {label='Mağazamın deposuna gönder',value='depot'},
            {label='Satış noktasında doğrudan sat',value='sell'}},
            onChange=function(v) state.mode=v; stopAuto(); later(targets) end},
        {type='dropdown',id='target',label='Hedef mağaza / bölge',options={{label='Listeyi yenile',value=''}},allowEmpty=true,
            onChange=function(v) state.target=v; stopAuto() end},
        {type='label',id='status',label='Listeyi yenile.'},
        {type='row',items={
            {type='button',id='refresh',label='Listeyi yenile',onClick=function() later(refresh) end},
            {type='button',id='all',label='Tümünü seç',onClick=function() for _,r in ipairs(state.rows) do Menu.Set('Items',state.ids[r.key],true) end end},
            {type='button',id='none',label='Seçimi temizle',onClick=function() for _,r in ipairs(state.rows) do Menu.Set('Items',state.ids[r.key],false) end end}}},
        {type='button',id='run',label='Seçilenleri DEPOYA GÖNDER',variant='primary',onClick=run},
        {type='checkbox',id='auto',label='Otomatik depo: listedeki tüm uygun eşyalar',default=false,onChange=function(v)
            if v and (state.mode~='depot' or not state.target) then stopAuto(); status('Otomatik için depo işlemi ve kendi mağazanı seç.'); return end
            state.auto=v
            status(v and 'Otomatik depo AÇIK. Kaynaktaki tüm uygun eşyalar gönderilir.' or 'Otomatik depo KAPALI.')
        end},
        {type='label',label='Satış düğmesi hemen satar. Otomatik depo seçim kutularını kullanmaz.'},
    }})
    Menu.Register({id='Items',title='Eşyalar',tab='Aktarım',items={{type='label',label='Liste yükleniyor...'}}})
    local steps={}; for _,n in ipairs(c.TimeSteps) do steps[#steps+1]={label=n..' dakika',value=n} end
    Menu.Register({id='Time',title='Zamanı ileri al',tab='Zaman',items={
        {type='label',label='F6: ileri al | F7: süreyi değiştir | F5: kısa yardım'},
        {type='dropdown',id='step',label='Atlama süresi',options=steps,default=time.GetStep(),onChange=function(v) time.SetStep(v) end},
        {type='button',id='skip',label='Seçili süre kadar ileri al',onClick=time.Skip},
        {type='label',label='Gün sonundan önce durur. Sonraki gün için yatakta uyu.'}
    }})
    Menu.OnOpen(function() later(function() refresh(); Menu.Set('Time','step',time.GetStep()) end) end)
    LoopAsync(c.AutoDepositPollMs,function()
        if state.auto then later(function()
            if not state.auto or R.isBusy() then return end
            local keys={}; for _,r in ipairs(R.scan(c,state.source)) do keys[r.key]=true end
            if next(keys) then R.deposit(c,state.source,state.target,keys,function(message,count)
                status(message)
                if count==0 then stopAuto(); notify(message..' Otomatik depo kapatıldı.') end
                later(function() refresh(true) end)
            end) end
        end) end
        return false
    end)
    M.Menu, M.State, M.Refresh, M.Run, M.SelectedKeys = Menu,state,refresh,run,selectedKeys
    M.StopAuto=stopAuto
    return M
end
return M
