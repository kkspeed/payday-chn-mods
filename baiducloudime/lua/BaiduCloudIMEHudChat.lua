json = require("json")

function escape (s)
   s = string.gsub(s, "([&=+%c])", function (c)
                      return string.format("%%%02X", string.byte(c))
   end)
   s = string.gsub(s, " ", "+")
   return s
end

function decodeUTF16(msg)
   local num = tonumber(msg, 16)
   local first = math.floor(num/4096)
   num = num - 4096 * first
   return string.char(first+224, math.floor(num/64)+128, num%64+128)
end

function displayMessage(channel_id, name, msg, color, icon)
   local receivers = managers.chat._receivers[channel_id]
   if not receivers then
      return
   end
   for i, receiver in ipairs(receivers) do
      receiver:receive_message(name, msg, color, icon)
   end
end

function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

imeMode = imeMode or "INPUT"
imeCandidates = imeCandidates or {}
imeInputBuffer = imeInputBuffer or ""
imeCandStart = 1

function reset_ime(gui)
   imeMode = "INPUT"
   imeCandidates = {}
   imeInputBuffer = ""
   imeCandStart = 1
   local text = gui._input_panel:child("input_text")
   local display_text = text:text()
   local msg = split(display_text, "|")
   if msg[2] then
      text:set_text(string.sub(msg[1], 1, -2))
   else
      text:set_text(display_text)
   end
end

function show_candidates()
   local candidates = ""
   local cnt = 1
   for i, cand in ipairs(imeCandidates) do
      if cnt >= 7 then
         break
      end
      if i >= imeCandStart then
         candidates = candidates .. " " .. (i % 7) .. "-" .. cand[1]
         cnt = cnt + 1
      end
   end
   local txt = string.gsub(candidates, "u(....)", decodeUTF16)
   managers.chat:_receive_message(
      1, "候选", txt, tweak_data.system_chat_color)
end

function backspace(gui)
   local text = gui._input_panel:child("input_text")
   local s, e = text:selection()
   if s > 0 then
      text:set_selection(s - 1, e)
   end
   text:replace_text("")
end

function get_candidates(gui)
   log("Get candidate...")
   local text = gui._input_panel:child("input_text")
   local query_msg = imeInputBuffer
   imeCandStart = 1
   log("Querying.. imeInputBuffer: " .. imeInputBuffer)
   dohttpreq( "http://olime.baidu.com/py?input=" .. escape(query_msg) ..
              "&inputtype=py&bg=0&ed=20&result=hanzi&" ..
              "resultcoding=unicode&ch_en=0&clientinfo=web&" ..
              "version=1",
              function(data, id)
                 log("IME Received: " .. data)
                 local result = json.decode(string.gsub(data, "%[,", "%["))
                 local text = gui._input_panel:child("input_text")
                 local display_text = text:text()
                 local msg_parts = split(display_text, "|")
                 local msg = msg_parts[1] or ""
                 imeCandidates = {}
                 local candList = result.result[1]
                 local candidates = ""
                 for i, cand in ipairs(candList) do
                    imeCandidates[i] = {cand[1], string.gsub(cand[3].pinyin, "'", "")} or
                       {"[]", ""}
                    log("Candidate.. " .. cand[1])
                 end
--                           text:set_text(msg .. "| " .. txt)
                 show_candidates()
                 imeMode = "SELECT"
              end
   )
end

CloneClass(HUDChat)
Hooks:RegisterHook( "IMEHUDChatEnterText" )
function HUDChat.enter_text(this, o, s)
   log("Enter text.. " .. s)
   result = this.orig.enter_text(this, o, s)
   Hooks:Call("IMEHUDChatEnterText", this, o, s)
   return result
end

Hooks:RegisterHook( "IMEHUDChatEnterKeyCallBack" )
function HUDChat.enter_key_callback(this)
   Hooks:Call("IMEHUDChatEnterKeyCallBack", this)
   return this.orig.enter_key_callback(this)
end

function applySelection(gui, i)
   i = imeCandStart - 1 + i
   local text = gui._input_panel:child("input_text")
   local display_text = text:text()
   local msg = split(display_text, "|")[1] or ""
   local candidate = imeCandidates[i][1] or ""
   text:set_text(string.sub(msg, 1, -2))

   local s, e = text:selection()
   log("IME Buffer Length: " .. #imeInputBuffer)

   for i = 0, #imeInputBuffer do
      backspace(gui)
      log("clear: " .. i .. " " .. s)
   end
   gui:update_caret()

   gui.orig.enter_text(gui, nil, candidate)
   local txt = text:text()
   log("prepared to show " .. txt)
   local to_show = string.gsub(txt, "u(....)", decodeUTF16)
   log(to_show)
   text:set_text(to_show .. " ")
   gui:update_caret()
   local candiPy = imeCandidates[i][2] or ""
   if candidate then
      log("Candipy length: " .. #candiPy .. " " .. candiPy)
      if #candiPy >= #imeInputBuffer then
         reset_ime(gui)
      else
         new_start = #candiPy + 1
         log("Start from.. " .. new_start)
         imeInputBuffer = string.sub(imeInputBuffer, new_start, -1)
         gui.orig.enter_text(gui, nil, imeInputBuffer .. " ")

         get_candidates(gui)
      end
   else
      reset_ime(gui)
   end
end

Hooks:Add("IMEHUDChatEnterText", "HUDChatEnterTextIME",
          function(gui, o, s)
             if not IMEEnable then
                return
             end
             if s == " " then
                if imeMode == "SELECT" then
                   backspace(gui)
                   applySelection(gui, 1)
                   return
                end
                get_candidates(gui)
             elseif s >= "1" and s <= "9" then
                if imeMode == "SELECT" then
                   backspace(gui)
                   applySelection(gui, tonumber(s))
                else
                   reset_ime(gui)
                end
             elseif s == "0" and imeMode == "SELECT" then
                backspace(gui)
                reset_ime(gui)
             elseif s == "=" and imeMode == "SELECT" then
                backspace(gui)
                imeCandStart = imeCandStart + 7
                if imeCandStart >= #imeCandidates then
                   imeCandStart = 1
                end
                show_candidates()
             elseif s == "-" and imeMode == "SELECT" then
                backspace(gui)
                imeCandStart = imeCandStart - 7
                if imeCandStart < 1 then
                   imeCandStart = 1
                end
                show_candidates()
             elseif imeMode == "SELECT" then
                applySelection(gui, 1)
             elseif s >= "a" and s <= "z" then
                imeInputBuffer = imeInputBuffer .. s
             elseif s >= "A" and s <= "Z" then
                reset_ime(gui)
             end
          end
)

Hooks:Add("IMEHUDChatEnterKeyCallBack", "HUDChatEnterKeyCallBackIME",
          function(gui)
             if not IMEEnable then
                return
             end
             reset_ime(gui)
          end
)

Hooks:RegisterHook("IMEHUDChatKeyPressed")
function HUDChat.update_key_down(this, o, k)
   log("Update key down hook")
   Hooks:Call("IMEHUDChatKeyPressed", this, o, k)
   return this.orig.update_key_down(this, o, k)
end

Hooks:Add("IMEHUDChatKeyPressed", "HUDChatKeyPressedIME",
          function (gui, o, k)
             if not IMEEnable then
                return
             end
             if k == Idstring("backspace") then
                imeInputBuffer = string.sub(imeInputBuffer, 1, -2)
                imeMode = "INPUT"
                imeCandidates = {}
--                reset_ime(gui)
                log("shrinked .. " .. imeInputBuffer)
             end
             if k == Idstring("delete") or
                k == Idstring("left") or
                k == Idstring("right") or
                k == Idstring("escape") then
                reset_ime(gui)
             end
          end
)
