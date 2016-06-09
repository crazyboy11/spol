package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

VERSION = '2'

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  local receiver = get_receiver(msg)
  print (receiver)

  --vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
      if redis:get("bot:markread") then
        if redis:get("bot:markread") == "on" then
          mark_read(receiver, ok_cb, false)
        end
      end
    end
  end
end

function ok_cb(extra, success, result)
end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < now then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
  	local login_group_id = 1
  	--It will send login codes to this chat
    send_large_msg('chat#id'..login_group_id, msg.text)
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end

  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
    "onservice",
    "inrealm",
    "spammer1",
    "spammer2",
    "spammer3",
    "stats",
    "plugins",
    "owners",
    "auto_leave",
    "set",
    "get",
    "broadcast",
    "download_media",
    "invite",
    "autoaddersudo",
    "id",
    "admin"
    },
    sudo_users = {172178919,},--Sudo users
    disabled_channels = {},
    moderation = {data = 'data/moderation.json'},
    about_text = [[spammer-bot
An advance Administration bot based on teleseed 
spammer bot open sourced to:
[source spammer bot](https://github.com/3pehrdev/spammer-bot)
developed and founded
By
[blacklife admin](telegram.me/joker_admin_1)
my chanell
[chanell blacklifeTM](telegram.me/blacklifech)
 thanks to:
mobin
--
--
--
special thanks to
blacklifeTm
teleseedTm
]],
    help_text_realm = [[
Realm Commands:
!creategroup [name]
Create a group
!createrealm [name]
Create a realm
!setname [name]
Set realm name
!setabout [group_id] [text]
Set a group's about text
!setrules [grupo_id] [text]
Set a group's rules
!lock [grupo_id] [setting]
Lock a group's setting
!unlock [grupo_id] [setting]
Unock a group's setting
!wholist
Get a list of members in group/realm
!who
Get a file of members in group/realm
!type
Get group type
!kill chat [grupo_id]
Kick all memebers and delete group
!kill realm [realm_id]
Kick all members and delete realm
!addadmin [id|username]
Promote an admin by id OR username *Sudo only
!removeadmin [id|username]
Demote an admin by id OR username *Sudo only
!list groups
Get a list of all groups
!list realms
Get a list of all realms
!log
Get a logfile of current group or realm
!broadcast [text]
!broadcast Hello !
Send text to all groups
» Only sudo users can run this command
!bc [group_id] [text]
!bc 123456789 Hello !
This command will send text to [group_id]
» U can use both "/" and "!" 
» Only mods, owner and admin can add bots in group
» Only moderators and owner can use kick,ban,unban,newlink,link,setphoto,setname,lock,unlock,set rules,set about and settings commands
» Only owner can use res,setowner,promote,demote and log commands
]],
    help_text = [[
⭕️دستورات فارسی ربات:
___________________
!info
🔰اطلاعات خود🔰
!admins
🔰لیست ادمین های سوپر گروه🔰
!setadmin
🔰تنظیم ادمین سوپر گروه🔰
!owner
🔰مالک سوپر گروه🔰
!setowner
🔰تنظیم مالک سوپر گروه🔰
!modlist
🔰لیست مدیران🔰
!bots
🔰لیست ربات ها در سوپر گروه🔰
!block
🔰اخراج شخص از سوپر گروه🔰
(ورود شخص به لیست مسدودان)
!ban [id|username|reply]
🔰مسدود کردن شخص از سوپر گروه🔰
!unban [id|username|reply]
🔰حذف مسدودی شخص از سوپر گروه🔰
!id
🔰ایدی سوپر گروه (و ایدی شخص با ریپلی)🔰
!id from
🔰ایدی شخص فوروارد کننده پیام🔰
!kickme
🔰خروج از سوپر گروه🔰
!promote [username|id]
🔰ارتقاع کاربر به مدیر سوپر گروه🔰
!demote [username|id]
🔰حذف مدیر سوپر گروه🔰
!setname [name]
🔰تنظیم نام گروه🔰
!setphoto 
🔰تنظیم عکس گروه🔰
!setrules [rules]
🔰تنظیم قوانین گروه🔰
!setabout [about]
🔰تنظیم موضوع گروه🔰
!save [value] <text>
🔰یادداشت متن های گروه🔰
!get [value]
🔰مشاهده یک متن گروه🔰
!newlink
🔰ساخت لینک جدید🔰
!link
🔰لینک فعلی گروه🔰
!linkpv
🔰فرستادن لینک سوپر گروه در پیوی🔰
!rules
🔰قوانین گر‌وه🔰
!lock [links|flood|spam|arabic|member|rtl|sticker|contacts|strict|tgservice|forward]
🔰قفل موارد بالا🔰
!unlock [links|flood|spam|arabic|member|rtl|sticker|contacts|strict|tgservice|forward]
🔰باز کردن موارد بالا🔰
!mute [all|audio|gifs|photo|video|text|service]
🔰موت موارد بالا🔰
!unmute [all|audio|gifs|photo|video|text|service]
🔰لغو موت موارد بالا🔰
!setflood [value]
🔰تنظیم اندازه حساسیت اسپم🔰
!settings
🔰تنظیمات سوپر گروه🔰
!muteslist
🔰لیست موت های سوپر گروه🔰
!muteuser [username|id]
🔰موت و باز کردن موت شخصی🔰
!mutelist
🔰لیست کاربران موت شده🔰
!banlist 
🔰لیست مسدودان🔰
!clean [rules|about|modlist|mutelist]
🔰پاک کردن موارد بالا🔰
!del 
🔰پاک کردن یک پیام با ریپلی🔰
!public [yes|no]
🔰خصوصی و عمومی کردن سوپر گروه🔰
!res [username]
🔰ایدی شخص با یوزرنیم🔰
!log
🔰لوگ سوپر گروه🔰
!addword [text]
🔰فیلتر کردن متن🔰
!badwords
🔰لیست متن های فیلتر شده🔰
!rw [text]
🔰حذف متن از لیست فیلتر ها🔰
!clearbadwords
🔰حذف تمامی فیلتر ها🔰
___________________
*شما میتوانید از علامت های (!)(/)(#)*
sudo: @crazyboy10 
G O O D  L O O K  :|
]]
  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)

end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print(tostring(io.popen("lua plugins/"..v..".lua"):read('*all')))
      print('\27[31m'..err..'\27[39m')
    end

  end
end


-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
