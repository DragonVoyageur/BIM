Metric = { ' ', 'k', 'M', 'G', 'T' }
local function thousend(count)
    local c = count
    local i = 1
    while (c / 1000) >= 1 do
        c = math.floor(c / 1000)
        i = i + 1
    end
    if i>5 then i=5 c=999 end
    return  string.format('%03i%s',c,Metric[i])
end
local function tableExplore(tb)
    if type(tb) == 'table' then
        local text=''
        for i, ta in pairs(tb) do
            text=text..tableExplore(ta)
        end
        return text
    elseif type(tb) == 'number' then
        return thousend(tb)..' '
    elseif type(tb) == 'nil' then
        return ' '
    else
        return tostring(tb)..' '
    end       
end

function ValToIndes(list,selections)
    local index={}
    if type(selections)~='table' then selections={selections} end
    for i, l in pairs(list) do
        for j, s in pairs(selections) do
            if l==s then
                table.insert(index,i)
            end
        end
    end
    return index
end
local function ResizeBar(bar,scrollIndex,screen,list,columns)
    local screenSize={screen.getSize()}
    local barSize={bar.getSize()}
    local lenght=math.max(math.min((barSize[2]/(#list/columns))*barSize[2],barSize[2]),1)
    local max=math.ceil(barSize[2]-lenght)
    local percent=(scrollIndex/((#list/columns)-screenSize[2]))
    if percent~=percent then percent=0 end 
    local cal=percent<0.5 and math.ceil or math.floor
    local offset=cal(math.min(math.max(percent*max,0),max))
    for i=1, barSize[2],1 do
        bar.setCursorPos(1,i)
        if i>offset and i<=lenght+offset then
            bar.blit(' ','0','0')
        else
            bar.blit(' ','7','7')
        end
    end
end
function Print(list,selected,scrollIndex,bar,screen,columns)
    
    if bar~=nil then
        ResizeBar(bar,scrollIndex,screen,list,columns)
    end
    
    local screenSize={screen.getSize()}
    local width = math.floor(screenSize[1] / columns)
    local clickList={}
    screen.setCursorPos(1,1)
    local screenPos={screen.getPosition()}
    local indexs=ValToIndes(list,selected)
    local selectlist={}
    for i, sle in pairs(indexs) do
        selectlist[sle]=true
    end
    local pos={1,1}
    table.insert(clickList,screenPos[2]+pos[2]-1,{}) 
    for i=1+scrollIndex*columns, #list,1 do
        pos={screen.getCursorPos()}
        if pos[1]+width-1>screenSize[1] then 
            if pos[2]+1>screenSize[2] then break end 
            screen.setCursorPos(1,pos[2]+1)
            pos={screen.getCursorPos()}
            table.insert(clickList,screenPos[2]+pos[2]-1,{}) 
        end
        local text=string.sub(string.format('%-'..tostring(width)..'s',tableExplore(list[i])),1,width-1)..' '
        for j=screenPos[1]+pos[1]-1,screenPos[1]+pos[1]+width-1,1 do
            table.insert(clickList[screenPos[2]+pos[2]-1],j,i)
        end
        screen.blit(text,string.rep('0', width),string.rep(selectlist[i] and '7' or 'f', width))
    end
    pos={screen.getCursorPos()}
    screen.write(string.rep(' ',1+screenSize[1]-pos[1]))
    for i=pos[2]+1,screenSize[2],1 do
        screen.setCursorPos(1,i)
        screen.clearLine()
    end
    
    return clickList
end

function Clicked(clickList,x, y)
    local value =nil
    if clickList[y]~=nil then  
        value= clickList[y][x]
    end
    if value==nil then value=-1 end
    return value
end

return {Print=Print,Click=Clicked}