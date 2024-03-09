ProjectName='BIM'
Programs={'Crafter','Settings'}
for index, value in ipairs(Programs) do
    multishell.setTitle(
    multishell.launch(
        {Um=require('/'..ProjectName..'/Functions/UiManager'),Vs=require('/'..ProjectName..'/Functions/VariableStorage'),require=require,multishell=multishell},
        '/'..ProjectName..'/'..value..'Manager.lua'),
    value
    )
end
os.run({Um=require('/'..ProjectName..'/Functions/UiManager'),Vs=require('/'..ProjectName..'/Functions/VariableStorage'),require=require,multishell=multishell},
'/'..ProjectName..'/'..'Inventory'..'Manager.lua')
