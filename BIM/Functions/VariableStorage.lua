ProjectName='BIM'
Chests={}
Env=nil
Itemlist={}

function SetKeyEnv(value,key)
    if key~=nil then
        Env[key]=value
    end
end

function SetEnv(value)
    Env=value
end

function GetEnv(key)
    if key==nil then
        return Env
    else
        return Env[key]
    end
end

return {chests=Chests,list=Itemlist,name=ProjectName,setEnv=SetEnv,getEnv=GetEnv,setKeyEnv=SetKeyEnv}
