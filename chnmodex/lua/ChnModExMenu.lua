_G.ChnModExMenu = _G.ChnModExMenu or {}
local Languages = {"en", "zh-CHS"}
ChnModExMenu._path = ModPath
ChnModExMenu._data_path = ModPath .. "chnmodex_save_data.txt"
ChnModExMenu._data = {}

function ChnModExMenu:Save()
	local file = io.open( self._data_path, "w+" )
	if file then
		file:write( json.encode( self._data ) )
		file:close()
	end
end

function ChnModExMenu:Load()
	local file = io.open( self._data_path, "r" )
	if file then
		self._data = json.decode( file:read("*all") )
		file:close()
	end
end

Hooks:Add("LocalizationManagerPostInit",
          "LocalizationManagerPostInit_ChnModExMenu", function(loc)
             loc:load_localization_file( ChnModExMenu._path .. "en.txt")
end)

Hooks:Add( "MenuManagerInitialize", "MenuManagerInitialize_JsonMenuExample",
           function( menu_manager )
              MenuCallbackHandler.chnmodex_language_set_default = function(self, item)
                 ChnModExMenu._data.chnmodex_default_lang_value = item:value()
                 ChnModExMenu._data.chnmodex_default_lang = Languages[tonumber(item:value())]
                 translateTo = Languages[tonumber(item:value())]
                 ChnModExMenu:Save()
                 log("Multiple-choice value: " .. item:value())
              end
              ChnModExMenu:Load()
              MenuHelper:LoadFromJsonFile( ChnModExMenu._path ..
                                           "menu.txt",
                                           ChnModExMenu,
                                           ChnModExMenu._data )
end )
