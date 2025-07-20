ProjectName = 'BIM'
Programs = { 'Inventory', 'Crafter', 'Settings' }
local Um = require('/' .. ProjectName .. '/Functions/UiManager')
local Vs = require('/' .. ProjectName .. '/Functions/VariableStorage')
Um.setVs(Vs)

for _, value in ipairs(Programs) do
    multishell.setTitle(
        multishell.launch(
            {
                Um = Um,
                Vs = Vs,
                require = require,
                multishell = multishell
            },
            '/' .. ProjectName .. '/' .. value .. 'Manager.lua'),
        value
    )
end
