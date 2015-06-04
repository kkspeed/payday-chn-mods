IMEEnable = not IMEEnable
local msg = ""
if IMEEnable then
   log("IME Enabled!")
   msg = "输入法已激活"
else
   log("IME Disabled!")
   msg = "输入法已关闭"
end

if managers.chat then
   managers.chat:_receive_message(1, "云输入法", msg,  tweak_data.system_chat_color)
end

imeMode = "INPUT"
imeCandidates = {}
imeInputBuffer = ""
imeCandStart = 1
