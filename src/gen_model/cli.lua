
local template = require("resty.template")

local M = {}

function M.render_model(descriptor_set, out_put_dir)
    for _, file in ipairs(descriptor_set.file) do
        local model_name = file.name:match("([^/]+)%.proto$")
        if model_name then
            local output_path = out_put_dir .. "/" .. model_name .. ".lua"
            local f = assert(io.open(output_path, "w"))
            template.render("model_template.lua", { descriptor_set = descriptor_set, file = file }, function(err, str)
                if err then
                    error(err)
                end
                f:write(str)
                f:close()
            end)
        end
    end
end

return M