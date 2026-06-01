local M = {}

--- 构造 FileDescriptorSet
---@param ... table FileDescriptorProto
---@return table
function M.descriptor_set(...)
    return { file = { ... } }
end

--- 构造 FileDescriptorProto
---@param name string 文件名
---@param package string 包名
---@param messages table[] 消息描述符列表
---@param enums table[] 枚举描述符列表
---@return table
function M.file(name, package, messages, enums)
    return {
        name = name,
        package = package,
        message_type = messages or {},
        enum_type = enums or {},
    }
end

--- 构造 DescriptorProto
---@param name string 消息名
---@param fields table[] 字段描述符列表
---@param oneofs table[] oneof 描述符列表
---@param nested table[] 嵌套消息列表
---@param enums table[] 嵌套枚举列表
---@param options table 消息选项
---@return table
function M.message(name, fields, oneofs, nested, enums, options)
    return {
        name = name,
        field = fields or {},
        oneof_decl = oneofs or {},
        nested_type = nested or {},
        enum_type = enums or {},
        options = options,
    }
end

--- 构造 FieldDescriptorProto
---@param name string 字段名
---@param type integer protobuf 字段类型（如 bean_info.FieldType.TYPE_INT32）
---@param number integer 字段编号
---@param label integer 标签类型（如 bean_info.FieldLabel.LABEL_OPTIONAL）
---@param opts table 可选参数：type_name, oneof_index, options
---@return table
function M.field(name, type, number, label, opts)
    opts = opts or {}
    return {
        name = name,
        type = type,
        number = number,
        label = label,
        type_name = opts.type_name,
        oneof_index = opts.oneof_index,
        options = opts.options,
    }
end

--- 构造 EnumDescriptorProto
---@param name string 枚举名
---@param values table[] 枚举值列表
---@return table
function M.enum(name, values)
    return {
        name = name,
        value = values or {},
    }
end

--- 构造 EnumValueDescriptorProto
---@param name string 枚举值名
---@param number integer 枚举值编号
---@return table
function M.enum_value(name, number)
    return {
        name = name,
        number = number,
    }
end

--- 构造 OneofDescriptorProto
---@param name string oneof 名
---@return table
function M.oneof(name)
    return { name = name }
end

return M
