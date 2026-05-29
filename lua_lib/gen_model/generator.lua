
local template = require("resty.template")
local model_info = require("gen_model.model_info")

local M = {}

function M.gen(descriptor_set, output_dir)
    local info = model_info.build_info(descriptor_set)
    M.gen_files(info, output_dir)
end
---@param info DescriptorSetInfo
---@param output_dir string 输出目录
function M.gen_files(info, output_dir)
    for _, file in ipairs(info.files) do
        M.gen_file(info, file, output_dir)
    end
end

---@param info DescriptorSetInfo
---@param file_info FileInfo
---@param output_dir string 输出目录
function M.gen_file(info, file_info, output_dir)
    local file_descriptor = file_info.descriptor
    local file_name = file_descriptor.name:match("([^/]+)%.proto$")
    if not file_name then
        return
    end
    local output_path = string.format("%s/%s.lua", output_dir, file_name)

    local output_buf = {
        "local M = {}\n",
    }
    for _, enum in ipairs(file_info.enums) do
        M.gen_enum(info, enum, output_buf)
    end
    for _, message in ipairs(file_info.messages) do
        M.gen_message(info, message, output_buf)
    end
    output_buf[#output_buf + 1] = "\n"
    output_buf[#output_buf + 1] = "return M\n"

    local f = assert(io.open(output_path, "w"))
    f:write(table.concat(output_buf))
    f:close()
end

---@param info DescriptorSetInfo
---@param enum_info EnumInfo
---@param output_buf string[]
function M.gen_enum(info, enum_info, output_buf)
    local template_str = [[
---@enum <*enum_info.full_name*>
M.<*enum_info.name*> = {
<* for _, value in ipairs(enum_info.values) do *>
    <*value.key*> = <*value.value*>,
<* end *>
}
]]
    template.render(template_str, { enum_info = enum_info }, function(err, str)
        if err then
            error(err)
        end
        output_buf[#output_buf + 1] = str
    end)
end

---@param info DescriptorSetInfo
---@param message_info MessageInfo
---@param output_buf string[]
function M.gen_message(info, message_info, output_buf)
    local begin_template =[[
M.<*message_info.name*> = {}
M.<*message_info.name*>.__index = M.<*message_info.name*>

function M.<*message_info.name*>.new()
    local self = setmetatable({}, M.<*message_info.name*>)
    return self
end
]]
    template.render(begin_template, { message_info = message_info }, function(err, str)
        if err then
            error(err)
        end
        output_buf[#output_buf + 1] = str
    end)
    M.gen_fields(info, message_info, output_buf)
end

function M.gen_fields(info, message_info, output_buf)
    local oneof_index = 0
    for _, field in ipairs(message_info.fields) do
        if field.is_map then
            M.gen_map(info, message_info, field, output_buf)
        elseif field.is_repeated then
            M.gen_repeated(info, message_info, field, output_buf)
        elseif field.oneof_index > 0 then
            local oneof_info = message_info.oneofs[field.oneof_index]
            if oneof_index ~= field.oneof_index then
                oneof_index = field.oneof_index
                M.gen_oneof(info, message_info, oneof_info, output_buf)
            end
            M.gen_oneof_field(info, message_info, oneof_info, field, output_buf)
        else
            M.gen_field(info, message_info, field, output_buf)
        end
    end
end

---@param info DescriptorSetInfo
---@param message_info MessageInfo
---@param field_info FieldInfo
---@param output_buf string[]
function M.gen_map(info, message_info, field_info, output_buf)
    
end

---@param info DescriptorSetInfo
---@param message_info MessageInfo
---@param field_info FieldInfo
---@param output_buf string[]
function M.gen_message_map(info, message_info, field_info, output_buf)
    
end

---@param info DescriptorSetInfo
---@param message_info MessageInfo
---@param field_info FieldInfo
---@param output_buf string[]
function M.gen_dirty_map(info, message_info, field_info, output_buf)
    
end

---@param info DescriptorSetInfo
---@param message_info MessageInfo
---@param field_info FieldInfo
---@param output_buf string[]
function M.gen_dirty_message_map(info, message_info, field_info, output_buf)
    
end

---@param info DescriptorSetInfo
---@param message_info MessageInfo
---@param field_info FieldInfo
---@param output_buf string[]
function M.gen_repeated(info, message_info, field_info, output_buf)

end

---@param info DescriptorSetInfo
---@param message_info MessageInfo
---@param field_info FieldInfo
---@param output_buf string[]
function M.gen_field(info, message_info, field_info, output_buf)

end

---@param info DescriptorSetInfo
---@param message_info MessageInfo
---@param oneof_info OneofInfo
---@param output_buf string[]
function M.gen_oneof(info, message_info, oneof_info, output_buf)
    
end

---@param info DescriptorSetInfo
---@param message_info MessageInfo
---@param oneof_info OneofInfo
---@param field_info FieldInfo
---@param output_buf string[]
function M.gen_oneof_field(info, message_info, oneof_info, field_info, output_buf)

end


return M