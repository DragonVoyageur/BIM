--#region Function--
function ReadRecipe()
    local recipe={nil,{}}
    if turtle.getItemDetail(16)==nil then return true end
    recipe[1]=turtle.getItemDetail(16,true)
    for i=1,11,1 do
        if i%4~=0 then
            recipe[2][i]=turtle.getItemDetail(i,true)
        end
    end
    if #recipe[2]<1 then return true end
    StoreFile(Vs.name..'/Recipes/'..recipe[1].displayName,recipe)
    Selected=0
    Recipes=fs.list(Vs.name..'/Recipes')
    ClickList=Um.Print(Recipes,Selected,ScrollIndex,ScrollBar,Screen,ColAmount)
    return false
end

function  LoadFile(name)
    if name==nil then 
        printError('No file name given')
        return nil
    end
    if not fs.exists(name) then
        printError(name..' file not found')
        return nil
    end
    local file = fs.open(name, 'r')
    local value = textutils.unserialise(file.readAll())
    file.close()
    return value
end

function StoreFile(name,value)
    if name==nil then 
        printError('No file name given')
        return nil
    end
    local file =fs.open(name,'w')
    file.write(textutils.serialise(value))
    file.close()
end

function DeleteRecipe()
    if not Selected then return true end
    if not fs.exists(Vs.name..'/Recipes/'..Selected) then return true end
    fs.delete(Vs.name..'/Recipes/'..Selected)
    Selected=nil
    Recipes=fs.list(Vs.name..'/Recipes')
    ClickList=Um.Print(Recipes,Selected,ScrollIndex,ScrollBar,Screen,ColAmount)
    return false
end

function CraftOne()
    if not Selected then return true end
    if not fs.exists(Vs.name..'/Recipes/'..Selected) then return true end
    local recipe = LoadFile(Vs.name..'/Recipes/'..Selected)
    local list = Vs.chests
    if recipe==nil or list==nil then return true end
    --validate and select items
    local temp={}
    for i,item in pairs(recipe[2]) do
        local counter= item.count
        local temp2={}
        if list[item.name] ==nil then return true end
        for j, items in pairs(list[item.name]) do
            if items.count==0 then
            elseif counter<=items.count then
                list[item.name][j].count=list[item.name][j].count-counter
                table.insert(temp2,textutils.unserialiseJSON(textutils.serialiseJSON(items)))
                temp2[#temp2].count=counter
                counter=0
            else
                counter=counter-items.count
                table.insert(temp2,textutils.unserialiseJSON(textutils.serialiseJSON(items)))
                list[item.name][j].count=0
            end
            if counter<=0 then
                temp[i]=temp2
                break
            end
        end 
        
        if counter >0 then
            return true
        end
    end
    if table.maxn(temp)==0 then return true end
    for i=1,11,1 do
        if i%4~=0 and temp[i]~=nil then
            for j, item in ipairs(temp[i])do
                os.queueEvent('turtle_inventory_ignore')
                Buffer.pullItems(item.side,item.slot,item.count)
                turtle.select(i)
                SuckSide()
            end
        end
    end
    peripheral.call('left','craft')
    os.queueEvent('turtle_inventory_ignore')
    DropSide()
    Vs.chests=list
    return false
end

function CraftStack()
    if not Selected then return true end
    if not fs.exists(Vs.name..'/Recipes/'..Selected) then return true end
    local recipe = LoadFile(Vs.name..'/Recipes/'..Selected)
    local list = Vs.chests
    if recipe==nil or list==nil then return true end
    --validate and select items
    local temp={}

    local multiplier=math.floor(recipe[1].maxCount/recipe[1].count)
    for i,item in pairs(recipe[2]) do
        local tm=math.floor(item.maxCount/item.count)
        if tm<multiplier then
            multiplier=tm
        end
    end
    repeat
        local counter=1
        for i,item in pairs(recipe[2]) do
            if list[item.name] ==nil then return true end
            counter= item.count*multiplier
            local temp2={}
            for j, items in pairs(list[item.name]) do
                if items.count==0 then
                elseif counter<=items.count then
                    list[item.name][j].count=list[item.name][j].count-counter
                    table.insert(temp2,textutils.unserialiseJSON(textutils.serialiseJSON(items)))
                    temp2[#temp2].count=counter
                    counter=0
                else
                    counter=counter-items.count
                    table.insert(temp2,textutils.unserialiseJSON(textutils.serialiseJSON(items)))
                    list[item.name][j].count=0
                end
                if counter<=0 then
                    temp[i]=temp2
                    break
                end
            end 
            
            if counter>0 then
                multiplier=math.floor((item.count*multiplier)-counter/item.count)
                list = Vs.chests
                break
            end
        end
    until counter<=0
    if table.maxn(temp)==0 then return true end
    for i=1,11,1 do
        if i%4~=0 and temp[i]~=nil then
            for j, item in ipairs(temp[i])do
                Buffer.pullItems(item.side,item.slot,item.count,i)
                os.queueEvent('turtle_inventory_ignore')
                turtle.select(i)
                SuckSide()
            end
        end
    end
    peripheral.call('left','craft')
    os.queueEvent('turtle_inventory_ignore')
    DropSide()
    Vs.chests=list
    return false
end

function ClickedMenu(x)
    SelectedMenu = ClickMenu[x]
    if SelectedMenu==1 then
        Menu()
        MenuError=CraftOne()
    elseif SelectedMenu==2 then
        Menu()
        MenuError=CraftStack()
    elseif SelectedMenu==3 then
        Menu()
        MenuError=ReadRecipe()
    elseif SelectedMenu==4 then
        Menu()
        MenuError=DeleteRecipe()
    end
    Menu()
    sleep(0.5)
    SelectedMenu=0
    MenuError=false
    Menu()
end

function Menu()
    local buttons={'Craft one','Craft stack','Save','Delete'}
    local size={RecipeMenu.getSize()}
    local padding=size[1]
    for i,text in ipairs(buttons) do
        padding=padding-#text
    end
    padding=math.floor((padding/#buttons)/2)
    RecipeMenu.setCursorPos(1,1)
    for i,text in ipairs(buttons) do
        local pos={RecipeMenu.getCursorPos()}
        local t=string.rep(' ',padding)..text..string.rep(' ',padding)
        RecipeMenu.blit(t,string.rep('f',#t),string.rep(SelectedMenu==i and (MenuError and 'e' or '7') or '8',#t))
        for j=pos[1],pos[1]+#t,1 do
            ClickMenu[j]=i
        end
    end
end

function LoopPrint()
    while true do
        local event = { os.pullEvent() }
        if event[1] == 'mouse_scroll' and ScrollIndex ~=math.min(math.max(ScrollIndex + event[2],0),math.max(math.ceil(#Recipes/ColAmount)-ScreenSize[2],0)) then
            ScrollIndex = ScrollIndex + event[2]
            ClickList=Um.Print(Recipes,Selected,ScrollIndex,ScrollBar,Screen,ColAmount)
        elseif event[1] == 'mouse_click' then
            if event[4]>ScreenSize[2] then
                
                ClickedMenu(event[3])
            else
                Selected=Recipes[Um.Click(ClickList,event[3], event[4])]
                Um.Print(Recipes,Selected,ScrollIndex,ScrollBar,Screen,ColAmount)
            end
        elseif event[1]=='click_ignore' then
            os.pullEvent('click_start')
        end
    end
end

function LoopEnv()
    while true do
        os.pullEvent('Update_Env')
        LoadEnv()
        Selected=''
        ScrollIndex=0
        Um.Print(Recipes,Selected,ScrollIndex,ScrollBar,Screen,ColAmount)
    end
end

function LoadEnv()
    Buffer=peripheral.wrap(Vs.getEnv('Buffer'))

    ColAmount =  tonumber(Vs.getEnv('Columns'))
end
--#endregion Function--

--#region Main--
--#region Globals--
ScrollIndex = 0
Recipes={}
ClickList = {}
ClickMenu={}
Selected=-1
SelectedMenu=0
MenuError=false
Buffer={}

MainScreen=term.current()
MainSize = { MainScreen.getSize() }
Screen=window.create(MainScreen,1,1,MainSize[1]-1,MainSize[2]-1)
ScreenSize={ Screen.getSize() }
ScrollBar=window.create(MainScreen,ScreenSize[1]+1,1,1,ScreenSize[2])
RecipeMenu=window.create(MainScreen,1,MainSize[2],MainSize[1],1)


ColAmount=2
DropSide=turtle.drop
SuckSide=turtle.suckDown


--#endregion Globals--
repeat
    sleep(0.1)
until Vs.getEnv()~=nil
LoadEnv()

ScrollBar.setBackgroundColor(colours.grey)
RecipeMenu.setBackgroundColor(colours.lightGrey)
Screen.clear()
ScrollBar.clear()
RecipeMenu.clear() 
if not fs.exists(Vs.name..'/Recipes/') then
    fs.makeDir(Vs.name..'/Recipes')
end

Menu()
Screen.setCursorPos(1, 1 )
Recipes=fs.list(Vs.name..'/Recipes')
ClickList=Um.Print(Recipes,Selected,ScrollIndex,ScrollBar,Screen,ColAmount)

parallel.waitForAll(LoopPrint,LoopEnv)
--#endregion Main--