--#region Functions--
function CreateEnv()
    local setVal={'inventory',{'left','right','top','bottom','front','back'},'none','2','none'}
    for i, name in ipairs(SetNames)do
        settings.set(Vs.name..'.'..name,setVal[i])
    end
    settings.save(SettingPath)
end

function LoadEnv()
    local options={{description =' Inventory by type to store items',default ='inventory',type ='string'},{description =' Inventories by name to ignore, like the buffer',default ={'left','right','top','bottom','front','back'},type ='table'},
    {description =' The inventory at the bottom that the turtle uses to manage items',default ='none',type ='string'},{description =' Amount of columns to display information',default ='2',type ='string'},
    {description =' Monitor to output display information to',default ='none',type ='string'}}
    local env={}
    for i,name in ipairs(SetNames)do
        env[name]=settings.get(Vs.name..'.'..name)
        settings.define(Vs.name..'.'..name,options[i])
    end
    env['Name']=Vs.name
    Vs.setEnv(env)
end

function PeripheralTypes()
    local inventories={}
    for i, inv in ipairs(peripheral.getNames()) do
        local type={peripheral.getType(inv)}
        if type[2]=='inventory' then
           inventories[type[1]]=type[1]
        end
    end
    local list={'inventory'}
    for i,name in pairs(inventories) do
        table.insert(list,name)
    end
    return list
end

function FindType(tp)
    local per={peripheral.find(tp)}
    local list={}
    for i,p in ipairs(per) do
        table.insert(list,peripheral.getName(p))
    end
    return list
end

function FindBuffer()
    local valid={'top','bottom','front'}
    local per={}
    for i,v in ipairs(valid) do
        if peripheral.hasType(v,'inventory') then
            table.insert(per,v)
        end
    end
    return per
end

function LisVal(id)
    local switch={
    ['Inventories']=function() 
            ValueList=PeripheralTypes()
            ValueSlected= Vs.getEnv('Inventories')
        end,
    ['IgnoreInv']=function() 
            ValueList= FindType(Vs.getEnv('Inventories'))
            local dontShow={['left']=true,['right']=true,['top']=true,['bottom']=true,['front']=true,['back']=true}
            for i,p in pairs(ValueList) do
                if dontShow[p] then
                    table.remove(ValueList,i)
                end
            end
            ValueSlected= Vs.getEnv('IgnoreInv')
           
        end,
    ['Buffer']=function() 
            ValueList= FindType('inventory')
            local dontShow={['left']=true,['right']=true,['top']=true,['bottom']=true,['front']=true,['back']=true}
            for i,p in pairs(ValueList) do
                if dontShow[p] then
                    table.remove(ValueList,i)
                end
            end
            ValueSlected= Vs.getEnv('Buffer')
        end,
    ['Columns']=function() 
            ValueList={'1','2','3','4'} 
            ValueSlected= Vs.getEnv('Columns')
        end,
    ['Monitor']=function()
            ValueList=FindType('monitor')
            table.insert(ValueList,1,'none')
            ValueSlected= Vs.getEnv('Monitor')
        end}
       
    Descriptions.clear()
    local desc=id and require 'cc.strings'.wrap(settings.getDetails(Vs.name..'.'..id).description,DescSize[1]-2) or ''
    for i = 1, #desc do
        Descriptions.setCursorPos(1,i)
        Descriptions.write( desc[i])
    end

    if type(switch[id])=='function' then
        switch[id]()
    else
        ValueList={}
    end
    ValueClick=Um.Print(ValueList,ValueSlected,0,BarValues,EnvValues,1)
end

function ValClicked(id)
    if MenuSelected~=nil  then
        local selection
        if MenuSelected=='IgnoreInv' then
            local ignore=Vs.getEnv('IgnoreInv')
            local exist=false
            for i, l in pairs(ignore) do
                if l==id then
                    table.remove(ignore,i)-------------
                    exist=true
                    break
                end
            end
            if not exist then table.insert(ignore,id) end
            selection=ignore
        elseif MenuSelected=='Buffer' then
            local oldBuffer=Vs.getEnv('Buffer')
            if oldBuffer~=id then
                local ignore=Vs.getEnv('IgnoreInv')
                for i, l in ipairs(ignore) do
                    if l==oldBuffer and l~=id then
                        table.remove(ignore,i)
                        break
                    end
                end
                table.insert(ignore,id)
                settings.set(Vs.name..'.IgnoreInv',ignore)
                Vs.setKeyEnv(ignore,'IgnoreInv')
            end
            selection=id
        else
            selection=id
        end
        if selection then
            settings.set(Vs.name..'.'..MenuSelected,selection)
            Vs.setKeyEnv(selection,MenuSelected)
            Um.Print(ValueList,selection,ScrollIndex,BarValues,EnvValues,1)
            settings.save(SettingPath)
            os.queueEvent('Update_Env')
        end
    end   
end

function LoopPrint()
    while true do
        local event = { os.pullEvent() }
        if event[1] == 'mouse_scroll' and ScrollIndex ~=math.min(math.max(ScrollIndex + event[2],0),math.max(#ValueList-ValuesSize[2],0)) then
            ScrollIndex = ScrollIndex + event[2]
            ValueClick=Um.Print(ValueList, Vs.getEnv(SetNames[MenuSelected]),ScrollIndex,BarValues,EnvValues,1)
        elseif event[1] == 'mouse_click' then
            if event[3]<=MenuPos[1]+MenuSize[1]+2 then
                MenuSelected=SetNames[Um.Click(MenuClick,event[3],event[4])]
                Um.Print(SetNames,MenuSelected,0,nil,EnvMenu,1)
                ValueSlected=-1
                ScrollIndex=0
                LisVal(MenuSelected)
            else
                ValueSlected=ValueList[Um.Click(ValueClick,event[3],event[4]) or ValueSlected]
                ValClicked(ValueSlected)
            end
        end
    end
end
--#endregion Functions--

--#region Main--
--#region Globals--
MenuClick={}
MenuSelected=0
ValueClick={}
ValueSlected=0
ValueList={}
SettingPath=Vs.name..'/'..Vs.name..'.settings'

Env={}
ScrollIndex=0
SetNames={'Inventories','IgnoreInv','Buffer','Columns','Monitor'}

--#endregion Globals--

if not settings.load(SettingPath) then
    CreateEnv()
end
LoadEnv()

MainScreen = (Env.Monitor == 'none' or Env.Monitor == nil) and term.current() or peripheral.wrap(Env.Monitor)
if MainScreen==nil then MainScreen=term.current() end
MainScreen.setBackgroundColor(colors.lightGray)
ScreenSize = { MainScreen.getSize() }

Width=#SetNames[1]+1
local height=#SetNames
local yOffset=math.floor((ScreenSize[2]-height)/2)
EnvMenu=window.create(MainScreen,3,yOffset,Width,height)
BackMenu=window.create(MainScreen,2,yOffset-1,2+Width,height+2)
Descriptions=window.create(MainScreen,2,yOffset+height+2,ScreenSize[1]-2,2)
MenuSize={ EnvMenu.getSize() }
MenuPos={ EnvMenu.getPosition() }
DescSize={Descriptions.getSize()}

EnvValues=window.create(MainScreen,MenuPos[1]+MenuSize[1]+3,yOffset,ScreenSize[1]-(4+MenuPos[1]+MenuSize[1]),height)
BackVal=window.create(MainScreen,MenuPos[1]+MenuSize[1]+2,yOffset-1,ScreenSize[1]-(2+MenuPos[1]+MenuSize[1]),height+2)
ValuesSize={ EnvValues.getSize() }
BarValues=window.create(BackVal,ValuesSize[1]+2,1,1,ValuesSize[2]+2)
BarValues.setBackgroundColor(colors.gray)

MainScreen.clear()
BackMenu.clear()
BackVal.clear()
EnvMenu.clear()
EnvValues.clear()
BarValues.clear()
Descriptions.clear()

MenuClick=Um.Print(SetNames,0,0,nil,EnvMenu,1)
parallel.waitForAll(LoopPrint)
--#endregion Main--
