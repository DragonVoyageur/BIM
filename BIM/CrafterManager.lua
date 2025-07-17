
--#region Locals--
local workbench = peripheral.find("workbench")
local menuError = false
local recipes = {}
local clickList = {}
local mainScreen = term.current()
local mainSize = { mainScreen.getSize() }
local screen = window.create(mainScreen, 1, 1, mainSize[1] - 1, mainSize[2] - 1)
local screenSize = { screen.getSize() }
local scrollBar = window.create(mainScreen, screenSize[1] + 1, 1, 1, screenSize[2])
local recipeMenu = window.create(mainScreen, 1, mainSize[2], mainSize[1], 1)

local buffer
local colAmount
local scrollIndex = 0
local clickMenu = {}
local selected = -1
local selectedMenu = 0

local workbenchInputSlots = { 1, 2, 3, 5, 6, 7, 9, 10, 11 }
--#endregion Locals--

--#region Function--
function ReadRecipe()
    local recipe={nil, {}}
    if turtle.getItemDetail(16)==nil then return true end
    recipe[1] = turtle.getItemDetail(16, true)
    for i, v in ipairs(workbenchInputSlots) do
        recipe[2][v] = turtle.getItemDetail(v, true)
    end
    if #recipe[2]<1 then return true end
    StoreFile(Vs.name..'/Recipes/'..recipe[1].displayName,recipe)
    selected=0
    recipes=fs.list(Vs.name..'/Recipes')
    clickList=Um.Print(recipes,selected,scrollIndex,scrollBar,screen,colAmount)
    return false
end

function LoadFile(name)
    if name==nil then
        printError('No file name given')
        return nil
    end
    if not fs.exists(name) then
        printError(name..' file not found')
        return nil
    end

    local file = fs.open(name, 'r')
    if file then
        local serialized = file.readAll()
        if serialized == nil then
            return
        end
        local value = textutils.unserialise(serialized)
        file.close()
        return value
    else
        error("Failed to open " .. name .. " for writing") -- in case of read only / disk full etc.
    end

end

function StoreFile(name,value)
    if name==nil then
        printError('No file name given')
        return nil
    end
    local file =fs.open(name,'w')
    if file then
        file.write(textutils.serialise(value))
        file.close()
    else
        error("Failed to open " .. name .. " for writing") -- in case of read only / disk full etc.
    end
end

function DeleteRecipe()
    if not selected then return true end
    if not fs.exists(Vs.name..'/Recipes/'..selected) then return true end
    fs.delete(Vs.name..'/Recipes/'..selected)
    selected=-1
    recipes=fs.list(Vs.name..'/Recipes')
    clickList=Um.Print(recipes,selected,scrollIndex,scrollBar,screen,colAmount)
    return false
end

function CraftOne()
    if not workbench then return false end
    if not selected then return true end
    if not fs.exists(Vs.name..'/Recipes/'..selected) then return true end
    local recipe = LoadFile(Vs.name..'/Recipes/'..selected)
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
    if not next(temp) then return true end
    for i, v in ipairs(workbenchInputSlots) do
        if temp[v]~=nil then
            for j, item in ipairs(temp[v])do
                os.queueEvent('turtle_inventory_ignore')
                buffer.pullItems(item.side,item.slot,item.count)
                turtle.select(v)
                turtle.suckDown()
            end
        end
    end
    workbench.craft()
    os.queueEvent('turtle_inventory_ignore')
    turtle.drop()
    Vs.chests=list
    return false
end

function CraftStack()
    if not workbench then return false end
    if not selected then return true end
    if not fs.exists(Vs.name..'/Recipes/'..selected) then return true end
    local recipe = LoadFile(Vs.name..'/Recipes/'..selected)
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
    if not next(temp) then return true end
    for i, v in ipairs(workbenchInputSlots) do
        if temp[v] ~= nil then
            for j, item in ipairs(temp[v])do
                buffer.pullItems(item.side,item.slot,item.count, v)
                os.queueEvent('turtle_inventory_ignore')
                turtle.select(v)
                turtle.suckDown()
            end
        end
    end
    workbench.craft()
    os.queueEvent('turtle_inventory_ignore')
    turtle.drop()
    Vs.chests=list
    return false
end

local function menu()
    if not workbench then
        recipeMenu.setCursorPos(1, 1)
        recipeMenu.write("Requires Crafty Turtle")
        return
    end
    local buttons={'Craft one','Craft stack','Save','Delete'}
    local size={recipeMenu.getSize()}
    local padding=size[1]
    for i,text in ipairs(buttons) do
        padding=padding-#text
    end
    padding=math.floor((padding/#buttons)/2)
    recipeMenu.setCursorPos(1,1)
    for i,text in ipairs(buttons) do
        local pos={recipeMenu.getCursorPos()}
        local t=string.rep(' ',padding)..text..string.rep(' ',padding)
        recipeMenu.blit(t,string.rep('f',#t),string.rep(selectedMenu==i and (menuError and 'e' or '7') or '8',#t))
        for j=pos[1],pos[1]+#t,1 do
            clickMenu[j]=i
        end
    end
end

function ClickedMenu(x)
    selectedMenu = clickMenu[x]
    if selectedMenu == 1 then
        menu()
        menuError = CraftOne()
    elseif selectedMenu == 2 then
        menu()
        menuError = CraftStack()
    elseif selectedMenu == 3 then
        menu()
        menuError = ReadRecipe()
    elseif selectedMenu == 4 then
        menu()
        menuError = DeleteRecipe()
    end
    menu()
    sleep(0.5)
    selectedMenu = 0
    menuError = false
    menu()
end

function LoopPrint()
    while true do
        local event = { os.pullEvent() }
        if event[1] == 'mouse_scroll' and scrollIndex ~=math.min(math.max(scrollIndex + event[2],0),math.max(math.ceil(#recipes/colAmount)-screenSize[2],0)) then
            scrollIndex = scrollIndex + event[2]
            clickList=Um.Print(recipes,selected,scrollIndex,scrollBar,screen,colAmount)
        elseif event[1] == 'mouse_click' then
            if event[4]>screenSize[2] then

                ClickedMenu(event[3])
            else
                selected=recipes[Um.Click(clickList,event[3], event[4])]
                Um.Print(recipes,selected,scrollIndex,scrollBar,screen,colAmount)
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
        selected=-1
        scrollIndex=0
        Um.Print(recipes,selected,scrollIndex,scrollBar,screen,colAmount)
    end
end

function LoadEnv()
    buffer=peripheral.wrap(Vs.getEnv('Buffer'))
    colAmount =  tonumber(Vs.getEnv('Columns'))
end
--#endregion Function--

--#region Main--
repeat
    sleep(0.1)
until Vs.getEnv()~=nil
LoadEnv()

scrollBar.setBackgroundColor(colors.gray)
recipeMenu.setBackgroundColor(colors.lightGray)
screen.clear()
scrollBar.clear()
recipeMenu.clear()
if not fs.exists(Vs.name..'/Recipes/') then
    fs.makeDir(Vs.name..'/Recipes')
end

menu()
screen.setCursorPos(1, 1)
recipes=fs.list(Vs.name..'/Recipes')
clickList=Um.Print(recipes,selected,scrollIndex,scrollBar,screen,colAmount)

local success, result = pcall(function()
    parallel.waitForAll(LoopPrint, LoopEnv)
end)

if not success then
    term.clear()
    term.setCursorPos(1, 1)
    print(success)
    print(result)
    print(debug.traceback())
    os.pullEvent("key")
end
--#endregion Main--