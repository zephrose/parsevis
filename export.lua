local export = {}

local files = require('files')
package.path = package.path .. ';' .. windower.addon_path .. 'libs/?.lua'
local json = require('dkjson')

function export.save(data, silent, custom_filename, append_mode)
    local json_combat = json.encode(data.combat)
    local json_timeline = json.encode(data.timeline)
    local json_jobs = json.encode(data.jobs)

    if not json_combat or not json_timeline then
        if not silent then windower.add_to_chat(123, '[ParseVis] Failed to encode data to JSON.') end
        return
    end

    local js_content = ''
    if append_mode then
        js_content = js_content .. 'if (typeof parseData !== "undefined") {\n'
        js_content = js_content .. '    parseData.combat.push.apply(parseData.combat, ' .. json_combat .. ');\n'
        js_content = js_content .. '    parseData.timeline.push.apply(parseData.timeline, ' .. json_timeline .. ');\n'
        js_content = js_content .. '    Object.assign(parseData.jobs, ' .. json_jobs .. ');\n'
        js_content = js_content .. '}\n'
    else
        js_content = 'var parseData = { combat: ' .. json_combat .. ', timeline: ' .. json_timeline .. ', jobs: ' .. json_jobs .. ' };\n'
    end
    
    local filename = custom_filename or 'data.js'
    local path = windower.addon_path .. 'html/' .. filename
    local mode = append_mode and 'a' or 'w'
    local f = io.open(path, mode)
    if f then
        f:write(js_content)
        f:close()
        if not silent then windower.add_to_chat(207, '[ParseVis] Data exported to html/' .. filename) end
    else
        if not silent then windower.add_to_chat(123, '[ParseVis] Failed to write ' .. filename) end
    end
end

return export
