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
    Vs.list=itemlist
    List=list
    SortList()
end

function SortList()
    table.sort(List, SortFunction[2])
    Filter(textutils.unserialiseJSON(textutils.serialiseJSON(Vs.list)))
    table.sort(Filtered, SortFunction[2])
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
            ScrollIndex=math.min(math.max(ScrollIndex,0),math.max(math.ceil(#Filtered/ColAmount)-ScreenSize[2],0))
            PrintScreen()
            if Monitor then SClickList=Um.Print(Filtered,Selected,0,nil,SecondScreen,ColAmount) end
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
    Selected={Filtered[id]}
    for i, data in ipairs(Vs.chests[List[id][3]]) do
        if data.count>0 then
            local transferd= Buffer.pullItems(data.side, data.slot, 64 - stack)
            stack = stack + transferd
            Vs.list[id][1] = Vs.list[id][1] - transferd
            Filtered[id][1] = Filtered[id][1] - transferd
            Vs.chests[data.name][i].count=Vs.chests[data.name][i].count-transferd
            if stack >= 64 then
                break
            end
        end
    end
    Um.Print(Filtered,Selected,ScrollIndex,ScrollBar,Screen,ColAmount)
    if Monitor then Um.Print(Filtered,Selected,0,nil,SecondScreen,ColAmount) end
    turtle.drop() 
    repeat
        os.queueEvent('turtle_inventory_ignore')
        turtle.select(16)
        SuckSide()
        turtle.drop() 
    until table.maxn(Buffer.list())==0
    os.queueEvent('turtle_inventory_start')
end

function PrintScreen()
    SearchBar.setCursorBlink(false)
    ClickList=Um.Print(Filtered,Selected,ScrollIndex,ScrollBar,Screen,ColAmount)
    if Searching then
        SearchBar.setCursorBlink(true)
        SearchBar.setCursorPos(math.min(#Stext,SearchLenght)+1,1)
    end
end

function LoopPrint()
    while true do
        if Buffer then
            local event = { os.pullEvent() }
            if event[1] == 'mouse_scroll'  and ScrollIndex ~=math.min(math.max(ScrollIndex + event[2],0),math.max(math.ceil(#Filtered/ColAmount)-ScreenSize[2],0)) then
                ScrollIndex = ScrollIndex + event[2]
                PrintScreen()
                if Monitor then SClickList=Um.Print(Filtered,Selected,0,nil,SecondScreen,ColAmount) end
            elseif event[1] == 'mouse_click' and event[4]>=2 then
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
        PrintScreen()
        if Monitor then SClickList=Um.Print(Filtered,Selected,0,nil,SecondScreen,ColAmount) end
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

function LoopTopBar()
    while true do
        local event = { os.pullEvent() }
        if  event[1] == 'mouse_click' and event[4]==1 and event[3]>(#SearchTitel) and event[3]<(SBSize[1]+#SearchTitel) then
            BeginSearch()
        elseif event[1] == 'mouse_click' and event[3]>(SearchSize[1]-#SortDisplay[SortFunction[1]]) then
            if SortFunction[1]+1<=4 then
                SortFunction={SortFunction[1]+1,ListSort[SortFunction[1]+1]}
            else 
                SortFunction={1,ListSort[1]}
            end
            Search.setCursorPos(SearchSize[1]-#SortDisplay[SortFunction[1]]-3,1)
            Search.write("   "..SortDisplay[SortFunction[1]])
            SortList()
            PrintScreen()
        end
    end
end

function BeginSearch()
    SearchBar.setCursorPos(math.min(#Stext+1,SearchLenght-1),1)
    SearchBar.setCursorBlink(true)
    Searching=true
    while true do
        local event = { os.pullEvent() }
        if  event[1] == 'mouse_click' and not (event[4]==1 and event[3]>(#SearchTitel) and event[3]<(SBSize[1]+#SearchTitel)) then
            break
        elseif  event[1] == 'char' then
            if SearchLenght<=#Stext+3 then
                SearchBar.setCursorPos(1,1)
                SearchBar.write(Stext:sub(#Stext-SearchLenght+3, -1))
            end
            SearchBar.write(event[2])
            Stext=Stext..event[2]
        elseif event[1] == 'key'  and #Stext>0 then
            local k= keys.getName(event[2])
            if k == 'backspace' then
                if SearchLenght<=#Stext then
                    SearchBar.setCursorPos(1,1)
                    SearchBar.write(Stext:sub(#Stext+1-SearchLenght, -2))
                    SearchBar.write(' ')
                else
                    SearchBar.setCursorPos(#Stext,1)
                    SearchBar.write(' ')
                end
                Stext=Stext:sub(1, -2)
            end
        end
        if  event[1] == 'char' or event[1] == 'key' then
        SortList()
        PrintScreen()
        end
    end
    SearchBar.setCursorBlink(false)
    Searching=false
end

function MetaCall(table)
    local file =fs.open(".test3",'w')
    file.write(textutils.serialise( table))
    file.close()
    local keylist={}
    for i,v in ipairs(table) do
        keylist[v[2]:lower():gsub("%s+", "")]=i
    end
    return keylist
end

function Filter(list)
    if #Stext<1 then Filtered=list return end
    
    setmetatable(list,{__call=MetaCall})
    local searchtext=Stext:lower():gsub("%s+", "")
    local inverted=list()
    local filtering={}
    local results=textutils.complete(searchtext,inverted)
    
    for i,v in ipairs(results) do
        local value=inverted[searchtext..v]
        if value then
            table.insert(filtering,Vs.list[value])
        end
    end

    Filtered=filtering
    
end

--#endregion Functions--

--#region Main--

--#region Globals--
List={}
Filtered={}
ClickList = {}
SClickList={}
ScrollIndex = 0
Selected=0
Buffer=nil
Chests={}
Monitor=nil

ListSort={
    function(left,right)return left[2]<right[2]end,
    function(left,right)return left[2]>right[2]end,
    function(left,right)return left[1]<right[1]end,
    function(left,right)return left[1]>right[1]end,
}
SortFunction={1,ListSort[1]}
SortDisplay={
    "Name ^",
    "Name v",
    "Amount ^",
    "Amount v",
}
MainScreen=term.current()
MainSize={ MainScreen.getSize() }
SecondScreen=window.create(MainScreen,1,1,1,1)
SecondScreen.setVisible(false)
Screen,ScreenSize,ScrollBar=Um.Create(MainScreen,1,2,MainSize[1],MainSize[2],colors.black,colors.white,true,colors.gray,colors.white)
Search,SearchSize=Um.Create(MainScreen,1,1,MainSize[1],1,colors.lightGray,colors.black)
SearchTitel='Search:'
Searching=false
SearchLenght=(SearchSize[1]/2)-#SearchTitel
SearchBar,SBSize=Um.Create(Search,#SearchTitel+1,1,#SearchTitel+1+SearchLenght,1,colors.lightGray,colors.black)
Stext=""
ColAmount=2
DropSide=turtle.dropDown
SuckSide=turtle.suckDown
--#endregion Globals--


repeat
    sleep(0.1)
until Vs.getEnv()~=nil
LoadEnv()


Screen.setCursorPos(1,1)
Screen.write('Sorting...')
Search.setCursorPos(1,1)
Search.write(SearchTitel..string.rep(' ',(SearchLenght)+1)..'|')
Search.setCursorPos(SearchSize[1]-#SortDisplay[SortFunction[1]],1)
Search.write(SortDisplay[SortFunction[1]])
SearchBar.clear()
parallel.waitForAll(LoopSort,LoopPrint,StoreItems, LoopEnv,LoopTopBar)
--#endregion