--Github installer--
ProgramName='BIM'
ToDownload={
  {--github raw url base
    'https://raw.githubusercontent.com/DragonVoyageur/BIM/main',
    {--directory of github to install, it will have the same name when istaled
      '/Startup/StartBIM.lua',
      '/BIM/CrafterManager.lua',
      '/BIM/InventoryManager.lua',
      '/BIM/SettingsManager.lua',
      '/BIM/Functions/UiManager.lua',
      '/BIM/Functions/VariableStorage.lua'
    }
  }
}
Run='/Startup/StartBIM.lua'--File to run to start program
--Thanks to Fatboychummy, for showing me his instaler code to help me make mine
-------------------------
Files={}
print('Downloading files')
local error=false
for i,link in ipairs(ToDownload) do
  for j,directory in ipairs(link[2]) do
    local file=http.get(link[1]..directory)
    if file and file.getResponseCode() == 200 then
      table.insert(Files,{directory,file.readAll()})
      file.close()
    else
      error('Failed to download file '..link[1]..directory)
    end
  end
end
--------------
print('Installing files')
for i,file in ipairs(Files) do
  local isntall= fs.open(file[1],'w')
  isntall.write(file[2])
  isntall.close()
end
---------------
Print('Done')
if Run then
  Print('Running program')
 if fs.exists(Run) then
  shell.run(Run)
 else
  printError('Startup file not found, '..Run)
 end
end