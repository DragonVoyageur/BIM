ProjectName = "BIM"
Programs = { "Inventory", "Crafter", "Settings" }
local Um = require('/' .. ProjectName .. "/Functions/UiManager")
local SS = require('/' .. ProjectName .. "/Functions/StorageSystem")
local Vs = require('/' .. ProjectName .. "/Functions/VariableStorage")
SS:init(Vs)
Um.setVs(Vs)

for _, value in ipairs(Programs) do
    multishell.setTitle(
        multishell.launch(
            {
                Um = Um,
                Vs = Vs,
                Storage = SS,
                require = require,
                multishell = multishell
            },
            '/' .. ProjectName .. '/' .. value .. 'Manager.lua'),
        value
    )
end
