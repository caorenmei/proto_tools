---@enum FieldType
local FieldType = {
    TYPE_DOUBLE = 1,
    TYPE_FLOAT = 2,
    TYPE_INT64 = 3,
    TYPE_UINT64 = 4,
    TYPE_INT32 = 5,
    TYPE_FIXED64 = 6,
    TYPE_FIXED32 = 7,
    TYPE_BOOL = 8,
    TYPE_STRING = 9,
    TYPE_GROUP = 10,
    TYPE_MESSAGE = 11,
    TYPE_BYTES = 12,
    TYPE_UINT32 = 13,
    TYPE_ENUM = 14,
    TYPE_SFIXED32 = 15,
    TYPE_SFIXED64 = 16,
    TYPE_SINT32 = 17,
    TYPE_SINT64 = 18
}
---@enum FieldLabel
local FieldLabel = {
    LABEL_OPTIONAL = 1,
    LABEL_REQUIRED = 2,
    LABEL_REPEATED = 3
}
local IntegerTypes = {
    [FieldType.TYPE_INT32] = true,
    [FieldType.TYPE_INT64] = true,
    [FieldType.TYPE_UINT32] = true,
    [FieldType.TYPE_UINT64] = true,
    [FieldType.TYPE_SINT32] = true,
    [FieldType.TYPE_SINT64] = true,
    [FieldType.TYPE_FIXED32] = true,
    [FieldType.TYPE_FIXED64] = true,
    [FieldType.TYPE_SFIXED32] = true,
    [FieldType.TYPE_SFIXED64] = true
}
local NumberTypes = {
    [FieldType.TYPE_DOUBLE] = true,
    [FieldType.TYPE_FLOAT] = true
}
local StringTypes = {
    [FieldType.TYPE_STRING] = true,
    [FieldType.TYPE_BYTES] = true
}
local EnumTypes = {
    [FieldType.TYPE_ENUM] = true
}

---@package
---@class OneofInfo
---@field descriptor table oneof 字段描述符
---@field message string 所在消息的全名
---@field name string oneof 字段名
---@field index integer oneof 在消息中的索引，从 1 开始
---@field data_index integer 数据在消息中的索引，从 1 开始
---@field dirty_index integer 脏字段编号，使用位运算来标识脏字段，从 1 开始

---@package
---@class FieldInfo
---@field descriptor table 字段描述符
---@field message string 所在消息的全名
---@field name string 字段名
---@field index integer 字段在类型中的索引，从 1 开始
---@field type FieldType | string 字段类型，可能是基本类型，也可能是消息类型的全名
---@field is_repeated boolean 是否是 repeated 字段
---@field is_map boolean 是否是 map 字段
---@field is_oneof boolean 是否是 oneof 字段
---@field oneof_name string oneof 字段名
---@field oneof_index integer oneof 字段在 oneof 中的索引，从 1 开始
---@field map_key_type FieldType | 0 map 字段 key 的类型
---@field map_value_type FieldType | string | 0 map 字段 value 的类型，可能是基本类型，也可能是消息类型的全名
---@field data_index integer 数据在消息中的索引，从 1 开始
---@field dirty_index integer 脏字段编号，使用位运算来标识脏字段，从 1 开始

---@package
---@class MessageInfo
---@field descriptor table 消息描述符
---@field file string 消息所在文件的全名
---@field name string 消息名
---@field full_name string 消息的全名，嵌套消息部分以 "_" 分隔，例如 "package.Message_NestedMessage"
---@field full_name_dot string 消息的全名，嵌套消息部分以 "." 分隔，例如 "package.Message.NestedMessage"
---@field fields FieldInfo[] 字段列表
---@field oneofs OneofInfo[] oneof 字段列表
---@field has_dirty_fields boolean 是否有脏字段

---@package
---@class EnumInfo
---@field descriptor table 枚举描述符
---@field file string 枚举所在文件的全名
---@field name string 枚举名
---@field full_name string 枚举的全名，嵌套枚举部分以 "_" 分隔，例如 "package.Enum_NestedEnum"
---@field full_name_dot string 枚举的全名，嵌套枚举部分以 "." 分隔，例如 "package.Enum.NestedEnum"
---@field values { key: string, value: integer }[] 枚举值列表，key 是枚举值名，value 是枚举值编号

---@package
---@class FileInfo
---@field descriptor table 文件描述符
---@field name string 文件名
---@field package_name string 包名
---@field messages MessageInfo[] 消息列表
---@field enums EnumInfo[] 枚举列表

---@package
---@class DescriptorSetInfo
---@field descriptor_set table 描述符集合
---@field files table<string, FileInfo> 文件列表
---@field messages table<string, MessageInfo> 消息列表，key 是消息的全名
---@field enums table<string, EnumInfo> 枚举列表，key 是枚举的全名

local M = {}

---@param descriptor_set google.protobuf.FileDescriptorSet
---@return DescriptorSetInfo
function M.build_info(descriptor_set)
    local info = {
        descriptor_set = descriptor_set,
        files = {},
        messages = {},
        enums = {}
    } --[[ @as DescriptorSetInfo ]]
    for _, file in ipairs(descriptor_set.file) do
        local package_prefix = file.package ~= "" and (file.package .. ".") or ""
        local file_info = {
            descriptor = file,
            name = file.name,
            package_name = file.package,
            messages = {},
            enums = {}
        } --[[ @as FileInfo ]]
        info.files[file.name] = file_info

        for _, enum in ipairs(file.enum_type) do
            M.build_enum_info(info, file_info, enum, package_prefix, package_prefix)
        end
        for _, message in ipairs(file.message_type) do
            M.build_message_info(info, file_info, message, package_prefix, package_prefix)
        end
    end

    return info
end

---@param info DescriptorSetInfo
---@param file_info FileInfo
---@param message table 消息描述符
---@param name_prefix string 父消息的全名，顶层消息为包名
---@param name_prefix_dot string 父消息的全名，顶层消息为包名，使用 "." 分隔
function M.build_message_info(info, file_info, message, name_prefix, name_prefix_dot)
    local full_name = string.format("%s%s", name_prefix, message.name)
    local full_name_dot = string.format("%s%s", name_prefix_dot, message.name)
    local message_info = {
        descriptor = message,
        file = file_info.name,
        name = message.name,
        full_name = full_name,
        full_name_dot = full_name_dot,
        fields = {},
        oneofs = {},
        has_dirty_fields = false,
    } --[[ @as MessageInfo ]]
    info.messages[full_name] = message_info
    info.messages[full_name_dot] = message_info
    table.insert(file_info.messages, message_info)

    for i, field in ipairs(message.field) do
        M.build_field_info(info, file_info, message_info, field, i)
    end
    for i, oneof in ipairs(message.oneof_decl) do
        M.build_oneof_info(info, file_info, message_info, oneof, i)
    end
    M.process_fields(info, file_info, message_info)

    for _, nested_enum in ipairs(message.enum_type) do
        M.build_enum_info(info, file_info, nested_enum, full_name .. "_", full_name_dot .. ".")
    end
    for _, nested_message in ipairs(message.nested_type) do
        M.build_message_info(info, file_info, nested_message, full_name .. "_", full_name_dot .. ".")
    end
end

---@param info DescriptorSetInfo
---@param file_info FileInfo
---@param enum table 枚举描述符
---@param name_prefix string 父消息的全名，顶层消息为包名
---@param name_prefix_dot string 父消息的全名，顶层消息为包名，使用 "." 分隔
function M.build_enum_info(info, file_info, enum, name_prefix, name_prefix_dot)
    local full_name = string.format("%s%s", name_prefix, enum.name)
    local full_name_dot = string.format("%s%s", name_prefix_dot or name_prefix, enum.name)
    local enum_info = {
        descriptor = enum,
        file = file_info.name,
        name = enum.name,
        full_name = full_name,
        full_name_dot = full_name_dot,
        values = {}
    } --[[ @as EnumInfo ]]
    info.enums[full_name] = enum_info
    info.enums[full_name_dot] = enum_info
    table.insert(file_info.enums, enum_info)

    for _, value in ipairs(enum.value) do
        table.insert(enum_info.values, { key = value.name, value = value.number })
    end
end

---@param info DescriptorSetInfo
---@param file_info FileInfo
---@param message_info MessageInfo
---@param oneof table oneof 字段描述符
---@param index integer oneof 在消息中的索引，从 1 开始
function M.build_oneof_info(info, file_info, message_info, oneof, index)
    local oneof_info = {
        descriptor = oneof,
        message = message_info.full_name,
        name = oneof.name,
        index = index,
        data_index = 0,
        dirty_index = 0 -- 初始时没有脏字段
    } --[[ @as OneofInfo ]]
    table.insert(message_info.oneofs, oneof_info)
end

---@param info DescriptorSetInfo
---@param file_info FileInfo
---@param message_info MessageInfo
---@param field table 字段描述符
---@param index integer 字段在消息中的索引，从 1 开始
function M.build_field_info(info, file_info, message_info, field, index)
    local field_type = field.type
    if field_type == FieldType.TYPE_MESSAGE then
        field_type = field.type_name:sub(2) -- 去掉前面的 '.'
    end
    local field_info = {
        descriptor = field,
        message = message_info.full_name,
        name = field.name,
        index = index,
        type = field_type,
        is_repeated = field.label == FieldLabel.LABEL_REPEATED,
        is_map = false,
        is_oneof = field.oneof_index ~= nil,
        oneof_name = "",
        oneof_index = field.oneof_index and (field.oneof_index + 1) or 0,
        map_key_type = 0,
        map_value_type = 0,
        data_index = 0,
        dirty_index = 0 -- 初始时没有脏字段
    } --[[ @as FieldInfo ]]
    table.insert(message_info.fields, field_info)
end

---@param info DescriptorSetInfo
---@param file_info FileInfo
---@param message_info MessageInfo
function M.process_fields(info, file_info, message_info)
    local message_descriptor = message_info.descriptor
    local is_dirty_message = not (message_descriptor.options and message_descriptor.options.level == 0)

    for _, field in ipairs(message_info.fields) do
        local field_descriptor = field.descriptor
        -- 处理 map 字段
        if field.is_repeated and field.descriptor.type == FieldType.TYPE_MESSAGE then
            local entry_message = info.messages[field.type]
            local entry_descriptor = entry_message.descriptor
            if entry_descriptor.options and entry_descriptor.options.map_entry then
                field.is_map = true
                for _, map_field in ipairs(entry_descriptor.field) do
                    if map_field.name == "key" then
                        field.map_key_type = map_field.type
                    elseif map_field.name == "value" then
                        if map_field.type == FieldType.TYPE_MESSAGE then
                            field.map_value_type = map_field.type_name:sub(2)
                        else
                            field.map_value_type = map_field.type
                        end
                    end
                end
            end
        end
        -- 处理脏字段
        if is_dirty_message and not (field_descriptor.options and field_descriptor.options.transient) then
            field.dirty_index = 1
        end
    end
    -- 调整 dirty_index
    local dirty_index = 0
    for _, field in ipairs(message_info.fields) do
        if field.oneof_index > 0 then
            if field.dirty_index > 0 then
                local oneof_info = message_info.oneofs[field.oneof_index]
                if oneof_info.dirty_index == 0 then
                    dirty_index = dirty_index + 1
                    oneof_info.dirty_index = dirty_index
                end
            end
        elseif field.dirty_index > 0 then
            dirty_index = dirty_index + 1
            field.dirty_index = dirty_index
        end
    end
    for _, field in ipairs(message_info.fields) do
        if field.oneof_index > 0 then
            local oneof_info = message_info.oneofs[field.oneof_index]
            field.dirty_index = oneof_info.dirty_index
        end
    end
    message_info.has_dirty_fields = dirty_index > 0
    -- 计算数据索引
    -- 如果有脏字段，第一个Item为父消息，第二个Item为父消息Key，第三个Item的前16为父消息脏字段,后48为本消息的部分脏字段
    local data_index = 0
    if dirty_index > 0 then
        data_index = 3 + (dirty_index > 48 and math.floor((dirty_index - 48) / 64) or 0)
    end
    -- map 需要占用2个数据索引，1个存储 map 的长度，1个存储 map 的数据
    -- oneof 需要占用2个数据索引，1个存储 当前字段，1个存储 当前字段的数据
    local oneof_index = 0
    for _, field in ipairs(message_info.fields) do
        if field.is_map then
            field.data_index = data_index + 1
            data_index = data_index + 2
        elseif field.is_oneof then
            local oneof_info = message_info.oneofs[field.oneof_index]
            if oneof_index ~= field.oneof_index then
                oneof_index = field.oneof_index
                oneof_info.data_index = data_index + 1
                data_index = data_index + 2
            end
            field.data_index = oneof_info.data_index
        else
            field.data_index = data_index + 1
            data_index = data_index + 1
        end
    end
end

M.FieldType = FieldType
M.FieldLabel = FieldLabel
M.IntegerTypes = IntegerTypes
M.NumberTypes = NumberTypes
M.StringTypes = StringTypes
M.EnumTypes = EnumTypes

return M
