ChnModTranslation = not ChnModTranslation
local msg = ""
if ChnModTranslation then
   log("Translation Enabled!")
   msg = "翻译已激活"
else
   log("Translation Disabled!")
   msg = "翻译已关闭"
end

if managers.chat then
   managers.chat:_receive_message(1, "玩家对话翻译", msg,  tweak_data.system_chat_color)
end
