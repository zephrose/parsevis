local export = {}

local files = require('files')
package.path = package.path .. ';' .. windower.addon_path .. 'libs/?.lua'
local json = require('dkjson')

function export.save(data, silent, custom_filename)
    local json_str = json.encode(data, { indent = true })
    if not json_str then
        if not silent then windower.add_to_chat(123, '[ParseVis] Failed to encode data to JSON.') end
        return
    end

    local js_content = 'const parseData = ' .. json_str .. ';'
    
    local filename = custom_filename or 'data.js'
    local path = windower.addon_path .. 'html/' .. filename
    local f = io.open(path, 'w')
    if f then
        f:write(js_content)
        f:close()
        if not silent then windower.add_to_chat(207, '[ParseVis] Data exported to html/' .. filename) end
    else
        if not silent then windower.add_to_chat(123, '[ParseVis] Failed to write ' .. filename) end
    end
end

return export
