_addon.name = 'ParseVis'
_addon.author = 'gnovi'
_addon.version = '1.0'
_addon.commands = {'parsevis', 'pv'}

require('chat')
require('logger')

local action_parse = require('action_parse')
local export = require('export')

local is_running = true
local autoexport_interval = 20 -- Export every 10 seconds
local is_silent = false

local function print_help()
    windower.add_to_chat(207, '[ParseVis] == ParseVis Help ==')
    windower.add_to_chat(207, ' ** Launch the dashboard from the ParseVis\html\index.html **')
    windower.add_to_chat(207, ' - //pv report   : Manually export data to the dashboard immediately.')
    windower.add_to_chat(207, ' - //pv snapshot : Save a timestamped snapshot of current data.')
    windower.add_to_chat(207, ' - //pv reset    : Clear all combat data from the current session.')
    windower.add_to_chat(207, ' - //pv silent   : Toggle the chat message when data auto-exports.')
    windower.add_to_chat(207, ' - //pv debug  : Toggle debug mode to print debug data to chat.')
    windower.add_to_chat(207, ' - //pv help   : Show this help menu.')
end

local function export_loop()
    while is_running do
        local data = action_parse.get_data()
        local has_data = false
        if data.combat then
            has_data = (#data.combat > 0 or #data.timeline > 0)
        else
            has_data = (#data > 0)
        end
        
        if has_data then
            export.save(data, is_silent)
        end
        coroutine.sleep(autoexport_interval)
    end
end
coroutine.schedule(export_loop, autoexport_interval)

windower.register_event('load', function()
    print_help()
end)

windower.register_event('addon command', function(...)
    local args = {...}
    if #args == 0 then
        print_help()
        return
    end

    local cmd = args[1]:lower()

    if cmd == 'reset' then
        action_parse.reset()
        export.save({combat={}, timeline={}}, is_silent)
        windower.add_to_chat(207, '[ParseVis] Data reset.')
    elseif cmd == 'report' then
        export.save(action_parse.get_data(), is_silent)
        windower.add_to_chat(207, '[ParseVis] Data manually exported.')
    elseif cmd == 'snapshot' then
        local timestamp = os.date("%Y-%m-%d-%H%M%S")
        local filename = 'data_snapshot-' .. timestamp .. '.js'
        export.save(action_parse.get_data(), false, filename)
    elseif cmd == 'silent' then
        is_silent = not is_silent
        windower.add_to_chat(207, '[ParseVis] Silent mode: ' .. tostring(is_silent))
    elseif cmd == 'debug' then
        action_parse.debug_mode = not action_parse.debug_mode
        windower.add_to_chat(207, '[ParseVis] Debug mode: ' .. tostring(action_parse.debug_mode))
    elseif cmd == 'help' or cmd == '-help' or cmd == '--help' then
        print_help()
    else
        windower.add_to_chat(123, '[ParseVis] Unknown command.')
        print_help()
    end
end)

windower.register_event('unload', function()
    is_running = false
end)
