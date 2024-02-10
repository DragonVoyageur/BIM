--#region Functions--
function CountChests()
    local chestlist={}
    for i,chest in ipairs(Chests) do
        local items=chest.list()
        for j,item in pairs(items) do    
            local name=item.name
            if chestlist[name]==nil then chestlist[name]={} end
            table.insert(chestlist[name],{['side']=peripheral.getName(chest),['slot']=j,['count']=item.count,['name']=name})
        end
    end
    Vs.chests= chestlist
end

function SortItems()
    local list={}
    local itemlist={}
    for item,data in pairs(Vs.chests) do
        local count=0
        local disName=nil
        for i,slot1 in ipairs(data)do
            if slot1.count~=0 then
                local chest=peripheral.wrap(slot1.side)
                local limit=chest.getItemLimit(slot1.slot)
                if not disName then disName=chest.getItemDetail(slot1.slot).displayName end
                for j=i+1,#data,1 do
                    local transferd=chest.pullItems(data[j].side,data[j].slot,data[j].count,slot1.slot)
                    Vs.chests[item][j].count=data[j].count-transferd
                    Vs.chests[item][i].count=slot1.count+transferd
                end
                count=count+slot1.count
            end
        end
        table.insert(itemlist,{count,disName})
        table.insert(list,{count,disName,item})
    end
    table.sort(itemlist, function(left,right)
        return left[2]<right[2]
    end)
    table.sort(list, function(left,right)
        return left[2]<right[2]
    end)
    Vs.list=itemlist
    List=list
end

function StoreItems()
    while true do
        if Buffer then
            local  event={os.pullEvent()}
            if event[1]=='turtle_inventory' and multishell.getCurrent()==multishell.getFocus() then
                os.queueEvent('click_ignore')
                local id=0
                repeat
                    os.cancelTimer(id)
                    id =os.startTimer(1)
                    local  timer={os.pullEvent()}
                until timer[2]==id
                for i=1,16,1 do
                    turtle.select(i)
                    DropSide()
                end
                for i,item in pairs(Buffer.list())do
                    for j,chest in pairs(Chests)do
                        if item.count==0 then break end
                        Buffer.pushItems(peripheral.getName(chest),i)
                    end
                end
                os.queueEvent('click_start')
            elseif event[1]=='turtle_inventory_ignore' then
                os.pullEvent('turtle_inventory_start')
            end
        else
            os.pullEvent('Updated_Env')
        end
    end
end

function LoopSort()
    while true do
        if Buffer then
            CountChests()
            SortItems()
            ScrollIndex=math.min(math.max(ScrollIndex,0),math.max(math.ceil(#Vs.list/ColAmount)-ScreenSize[2],0))
            ClickList=Um.Print(Vs.list,Selected,ScrollIndex,ScrollBar,Screen,ColAmount)
            if Monitor then SClickList=Um.Print(Vs.list,Selected,0,nil,SecondScreen,ColAmount) end
            sleep(10)
        else
            Screen.clear()
            Screen.setCursorPos(1,1)
            Screen.write("No Buffer selected")
            os.pullEvent('Updated_Env')
            Screen.clear()
            Screen.setCursorPos(1,1)
            Screen.write('Sorting...')
        end
    end
end

function DropItem(id)
    if id==nil or List[id]==nil then return nil end
    local stack = 0
    Selected={Vs.list[id]}
    for i, data in ipairs(Vs.chests[List[id][3]]) do
        if data.count>0 then
            local transferd= Buffer.pullItems(data.side, data.slot, 64 - stack)
            stack = stack + transferd
            Vs.list[id][1] = Vs.list[id][1] - transferd
            Vs.chests[data.name][i].count=Vs.chests[data.name][i].count-transferd
            if stack >= 64 then
                break
            end
        end
    end
    Um.Print(Vs.list,Selected,ScrollIndex,ScrollBar,Screen,ColAmount)
    if Monitor then Um.Print(Vs.list,Selected,0,nil,SecondScreen,ColAmount) end
    turtle.drop() 
    repeat
        os.queueEvent('turtle_inventory_ignore')
        turtle.select(16)
        SuckSide()
        turtle.drop() 
    until table.maxn(Buffer.list())==0
    os.queueEvent('turtle_inventory_start')
end

function LoopPrint()
    while true do
        if Buffer then
            local event = { os.pullEvent() }
            if event[1] == 'mouse_scroll'  and ScrollIndex ~=math.min(math.max(ScrollIndex + event[2],0),math.max(math.ceil(#Vs.list/ColAmount)-ScreenSize[2],0)) then
                ScrollIndex = ScrollIndex + event[2]
                ClickList=Um.Print(Vs.list,Selected,ScrollIndex,ScrollBar,Screen,ColAmount)
                if Monitor then SClickList=Um.Print(Vs.list,Selected,0,nil,SecondScreen,ColAmount) end
            elseif event[1] == 'mouse_click' then
                DropItem(Um.Click(ClickList,event[3], event[4]))
            elseif event[1] =='monitor_touch' and Monitor then
                DropItem(Um.Click(SClickList,event[3], event[4]))
            elseif event[1]=='click_ignore' then
                os.pullEvent('click_start')
            end
        else
            os.pullEvent('Updated_Env')
        end
    end
end

function LoopEnv()
    while true do
        os.pullEvent('Update_Env')
        LoadEnv()
        Selected=0
        ScrollIndex=0
        ClickList=Um.Print(Vs.list,Selected,ScrollIndex,ScrollBar,Screen,ColAmount)
        if Monitor then SClickList=Um.Print(Vs.list,Selected,0,nil,SecondScreen,ColAmount) end
        os.queueEvent('Updated_Env')
    end
end

function LoadEnv()
    Buffer=peripheral.wrap(Vs.getEnv('Buffer'))

    local ignore={}
    for i,ig in pairs(Vs.getEnv('IgnoreInv'))do
        ignore[ig]=true
    end
    Chests={peripheral.find(Vs.getEnv('Inventories'), function(name,type)
        return not (ignore[name]) or false
    end)}

    local chestname={}
    for i,c in pairs(Chests) do
        table.insert(chestname,peripheral.getName(c))
    end

    ColAmount =  tonumber(Vs.getEnv('Columns'))

    Monitor=peripheral.wrap(Vs.getEnv('Monitor'))
    if Monitor then 
        local monitorSize={Monitor.getSize()}
        SecondScreen.reposition(1,1,monitorSize[1],monitorSize[2],Monitor)
        SecondScreen.setVisible(true)
    else
        SecondScreen.setVisible(false)
    end
end

--#endregion Functions--

--#region Main--

--#region Globals--
List={}
ClickList = {}
SClickList={}
ScrollIndex = 0
Selected=0
Buffer=nil
Chests={}
Monitor=nil

MainScreen=term.current()
MainSize={ MainScreen.getSize() }
ScrollBar=window.create(MainScreen,MainSize[1],1,1,MainSize[2])
ScrollBar.setBackgroundColor(colors.gray)
Screen=window.create(MainScreen,1,1,MainSize[1]-1,MainSize[2])
ScreenSize={ Screen.getSize() }
SecondScreen=window.create(MainScreen,1,1,1,1)
SecondScreen.setVisible(false)

ColAmount=2
DropSide=turtle.dropDown
SuckSide=turtle.suckDown
--#endregion Globals--


repeat
    sleep(0.1)
until Vs.getEnv()~=nil
LoadEnv()

Screen.clear()
ScrollBar.clear()
Screen.setCursorPos(1,1)
Screen.write('Sorting...')

parallel.waitForAll(LoopSort,LoopPrint,StoreItems, LoopEnv)
--#endregion