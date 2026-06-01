local protobuf_descriptor = require("third_party.protobuf_descriptor")

local FieldType = protobuf_descriptor.FieldDescriptorProto_Type
local FieldLabel = protobuf_descriptor.FieldDescriptorProto_Label

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

---@class gen_bean.OneofInfo
---@field descriptor table oneof 字段描述符
---@field message string 所在消息的全名
---@field name string oneof 字段名
---@field index integer oneof 在消息中的索引，从 1 开始
---@field track_index integer 脏字段编号，使用位运算来标识脏字段，从 1 开始
---@field data_index integer 普通消息数据在消息中的索引，从 1 开始

---@class gen_bean.FieldInfo
---@field descriptor table 字段描述符
---@field message string 所在消息的全名
---@field name string 字段名
---@field index integer 字段在类型中的索引，从 1 开始
---@field type google.protobuf.FieldDescriptorProto.Type | string 字段类型，可能是基本类型，也可能是消息类型的全名
---@field is_repeated boolean 是否是 repeated 字段
---@field is_map boolean 是否是 map 字段
---@field is_oneof boolean 是否是 oneof 字段
---@field oneof_name string oneof 字段名
---@field oneof_index integer oneof 字段在 oneof 中的索引，从 1 开始
---@field oneof_data_index integer 字段在 oneof 中的编号，第一个位表示是否是 message 类型，后面连续的编号表示同一个 oneof 中的字段索引，从 1 开始
---@field map_key_type google.protobuf.FieldDescriptorProto.Type | 0 map 字段 key 的类型
---@field map_value_type google.protobuf.FieldDescriptorProto.Type | string | 0 map 字段 value 的类型，可能是基本类型，也可能是消息类型的全名
---@field track_index integer 脏字段编号，使用位运算来标识脏字段，从 1 开始
---@field data_index integer 普通消息数据在消息中的索引，从 1 开始

---@class gen_bean.MessageInfo
---@field descriptor table 消息描述符
---@field file string 消息所在文件的全名
---@field name string 消息名
---@field full_name string 消息的全名，嵌套消息部分以 "_" 分隔，例如 "package.Message_NestedMessage"
---@field full_name_dot string 消息的全名，嵌套消息部分以 "." 分隔，例如 "package.Message.NestedMessage"
---@field fields gen_bean.FieldInfo[] 字段列表
---@field oneofs gen_bean.OneofInfo[] oneof 字段列表
---@field track_field_count integer 脏字段数量
---@field track_words integer 需要多少个 64 位整数来存储脏字段的位标记，等于 math.ceil(track_field_count / 64)
---@field trackable_state "unknown" | "trackable"|"non-trackable" 消息的可追踪状态

---@class gen_bean.EnumInfo
---@field descriptor table 枚举描述符
---@field file string 枚举所在文件的全名
---@field name string 枚举名
---@field full_name string 枚举的全名，嵌套枚举部分以 "_" 分隔，例如 "package.Enum_NestedEnum"
---@field full_name_dot string 枚举的全名，嵌套枚举部分以 "." 分隔，例如 "package.Enum.NestedEnum"
---@field values { key: string, value: integer }[] 枚举值列表，key 是枚举值名，value 是枚举值编号

---@class gen_bean.FileInfo
---@field descriptor table 文件描述符
---@field name string 文件名
---@field package_name string 包名
---@field messages gen_bean.MessageInfo[] 消息列表
---@field enums gen_bean.EnumInfo[] 枚举列表

---@class gen_bean.DescriptorSetInfo
---@field descriptor_set table 描述符集合
---@field files table<string, gen_bean.FileInfo> 文件列表
---@field messages table<string, gen_bean.MessageInfo> 消息列表，key 是消息的全名
---@field enums table<string, gen_bean.EnumInfo> 枚举列表，key 是枚举的全名

local M = {}

---@param descriptor_set google.protobuf.FileDescriptorSet
---@return gen_bean.DescriptorSetInfo
function M.build_info(descriptor_set)
    local info = {
        descriptor_set = descriptor_set,
        files = {},
        messages = {},
        enums = {}
    } --[[ @as gen_bean.DescriptorSetInfo ]]
    for _, file in ipairs(descriptor_set.file) do
        local package = file.package or ""
        local package_prefix = package ~= "" and (package .. ".") or ""
        local file_info = {
            descriptor = file,
            name = file.name,
            package_name = package,
            messages = {},
            enums = {}
        } --[[ @as gen_bean.FileInfo ]]
        info.files[file.name] = file_info

        for _, enum in ipairs(file.enum_type) do
            M.build_enum_info(info, file_info, enum, package_prefix, package_prefix)
        end
        for _, message in ipairs(file.message_type) do
            M.build_message_info(info, file_info, message, package_prefix, package_prefix)
        end
    end

    M.compute_trackable_states(info)
    M.rebuild_track_indices(info)

    return info
end

---@param info gen_bean.DescriptorSetInfo
---@param file_info gen_bean.FileInfo
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
        track_field_count = 0,
        track_words = 0,
        trackable_state = "unknown",
    } --[[ @as gen_bean.MessageInfo ]]
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

---@param info gen_bean.DescriptorSetInfo
---@param file_info gen_bean.FileInfo
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
    } --[[ @as gen_bean.EnumInfo ]]
    info.enums[full_name] = enum_info
    info.enums[full_name_dot] = enum_info
    table.insert(file_info.enums, enum_info)

    for _, value in ipairs(enum.value) do
        table.insert(enum_info.values, { key = value.name, value = value.number })
    end
end

---@param info gen_bean.DescriptorSetInfo
---@param file_info gen_bean.FileInfo
---@param message_info gen_bean.MessageInfo
---@param oneof table oneof 字段描述符
---@param index integer oneof 在消息中的索引，从 1 开始
function M.build_oneof_info(info, file_info, message_info, oneof, index)
    local oneof_info = {
        descriptor = oneof,
        message = message_info.full_name,
        name = oneof.name,
        index = index,
        track_index = 0, -- 初始时没有脏字段
        data_index = 0,
    } --[[ @as gen_bean.OneofInfo ]]
    table.insert(message_info.oneofs, oneof_info)
end

---@param info gen_bean.DescriptorSetInfo
---@param file_info gen_bean.FileInfo
---@param message_info gen_bean.MessageInfo
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
        oneof_data_index = 0,
        map_key_type = 0,
        map_value_type = 0,
        track_index = 0, -- 初始时没有脏字段
        data_index = 0,
    } --[[ @as gen_bean.FieldInfo ]]
    table.insert(message_info.fields, field_info)
end

---@param info gen_bean.DescriptorSetInfo
---@param file_info gen_bean.FileInfo
---@param message_info gen_bean.MessageInfo
function M.process_fields(info, file_info, message_info)
    local message_descriptor = message_info.descriptor
    local is_track_message = not (message_descriptor.options and message_descriptor.options.level == 0)

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
        if is_track_message and not (field_descriptor.options and field_descriptor.options.transient) then
            field.track_index = 1
        end
    end
    -- 调整 track_index
    local track_index = 0
    for _, field in ipairs(message_info.fields) do
        if field.oneof_index > 0 then
            if field.track_index > 0 then
                local oneof_info = message_info.oneofs[field.oneof_index]
                if oneof_info.track_index == 0 then
                    track_index = track_index + 1
                    oneof_info.track_index = track_index
                end
            end
        elseif field.track_index > 0 then
            track_index = track_index + 1
            field.track_index = track_index
        end
    end
    for _, field in ipairs(message_info.fields) do
        if field.oneof_index > 0 then
            local oneof_info = message_info.oneofs[field.oneof_index]
            field.track_index = oneof_info.track_index
        end
    end
    message_info.track_field_count = track_index
    message_info.track_words = math.ceil(track_index / 64)
    -- 如果有脏字段，通过第一个Item来通知父消息有修改
    -- map 需要占用2个数据索引，1个存储 map 的长度，1个存储 map 的数据
    -- oneof 需要占用2个数据索引，1个存储 当前字段，1个存储 当前字段的数据
    local data_index = 0
    local oneof_index = 0
    local oneof_data_index = 0
    for _, field in ipairs(message_info.fields) do
        if field.is_map then
            field.data_index = data_index + 1
            data_index = data_index + 2
        elseif field.is_oneof then
            local oneof_info = message_info.oneofs[field.oneof_index]
            if oneof_index ~= field.oneof_index then
                oneof_index = field.oneof_index
                oneof_data_index = 0
                oneof_info.data_index = data_index + 1
                data_index = data_index + 2
            end
            oneof_data_index = oneof_data_index + 1
            field.oneof_data_index = (oneof_data_index << 1) + (type(field.type) == "string" and 1 or 0)
            field.data_index = oneof_info.data_index
        else
            field.data_index = data_index + 1
            data_index = data_index + 1
        end
    end
end

--- Compute whether each message is trackable by iterative convergence.
--- A message is trackable if it has at least one field whose track_index > 0
--- and that field is either a scalar/enum type or references a trackable message.
---@param info gen_bean.DescriptorSetInfo
function M.compute_trackable_states(info)
    -- Initialize all messages to "unknown"
    for _, file_info in pairs(info.files) do
        for _, message_info in ipairs(file_info.messages) do
            message_info.trackable_state = "unknown"
        end
    end

    local changed = true
    while changed do
        changed = false
        for _, file_info in pairs(info.files) do
            for _, message_info in ipairs(file_info.messages) do
                if message_info.trackable_state ~= "unknown" then
                    goto continue_message
                end

                local has_trackable_field = false
                local undetermined = false

                for _, field in ipairs(message_info.fields) do
                    if field.track_index == 0 then
                        -- Field itself is not tracked (transient or level=0)
                        goto continue_field
                    end

                    if type(field.type) ~= "string" then
                        -- Scalar or enum field is tracked
                        has_trackable_field = true
                        break
                    else
                        -- Message type field, check referenced message's trackable state
                        local ref_msg = info.messages[field.type]
                        if ref_msg.trackable_state == "trackable" then
                            has_trackable_field = true
                            break
                        elseif ref_msg.trackable_state == "non-trackable" then
                            -- Referenced message is non-trackable, this field doesn't count
                            goto continue_field
                        else
                            -- Referenced message state is unknown, cannot determine yet
                            undetermined = true
                            break
                        end
                    end

                    ::continue_field::
                end

                if has_trackable_field then
                    message_info.trackable_state = "trackable"
                    changed = true
                elseif not undetermined then
                    -- All fields are either not tracked or reference non-trackable messages
                    message_info.trackable_state = "non-trackable"
                    changed = true
                end

                ::continue_message::
            end
        end
    end

    -- After loop, mark remaining unknown messages as non-trackable (conservative strategy)
    for _, file_info in pairs(info.files) do
        for _, message_info in ipairs(file_info.messages) do
            if message_info.trackable_state == "unknown" then
                message_info.trackable_state = "non-trackable"
            end
        end
    end
end

--- Rebuild track_index for all messages based on trackable_state.
--- Fields referencing non-trackable messages have their track_index set to 0.
---@param info gen_bean.DescriptorSetInfo
function M.rebuild_track_indices(info)
    for _, file_info in pairs(info.files) do
        for _, message_info in ipairs(file_info.messages) do
            -- Step 1: Clear track_index for fields referencing non-trackable messages
            for _, field in ipairs(message_info.fields) do
                if field.track_index > 0 then
                    if type(field.type) == "string" then
                        local ref_msg = info.messages[field.type]
                        if ref_msg and ref_msg.trackable_state == "non-trackable" then
                            field.track_index = 0
                        end
                    end
                    if field.is_map and type(field.map_value_type) == "string" then
                        local ref_msg = info.messages[field.map_value_type]
                        if ref_msg and ref_msg.trackable_state == "non-trackable" then
                            field.track_index = 0
                        end
                    end
                end
            end

            -- Step 2: Reassign continuous track_index numbers
            -- Reset all oneof track_index first
            for _, oneof_info in ipairs(message_info.oneofs) do
                oneof_info.track_index = 0
            end

            local track_index = 0
            for _, field in ipairs(message_info.fields) do
                if field.oneof_index > 0 then
                    if field.track_index > 0 then
                        local oneof_info = message_info.oneofs[field.oneof_index]
                        if oneof_info.track_index == 0 then
                            track_index = track_index + 1
                            oneof_info.track_index = track_index
                        end
                    end
                elseif field.track_index > 0 then
                    track_index = track_index + 1
                    field.track_index = track_index
                end
            end

            -- Sync oneof fields' track_index to their oneof_info's track_index
            for _, field in ipairs(message_info.fields) do
                if field.oneof_index > 0 then
                    local oneof_info = message_info.oneofs[field.oneof_index]
                    field.track_index = oneof_info.track_index
                end
            end

            message_info.track_field_count = track_index
            message_info.track_words = math.ceil(track_index / 64)
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
