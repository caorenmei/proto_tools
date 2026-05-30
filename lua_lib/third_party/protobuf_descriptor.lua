local M = {}

---@enum google.protobuf.FieldDescriptorProto.Type
M.FieldDescriptorProto_Type = {
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
    TYPE_SINT64 = 18,
}

---@enum google.protobuf.FieldDescriptorProto.Label
M.FieldDescriptorProto_Label = {
    LABEL_OPTIONAL = 1,
    LABEL_REQUIRED = 2,
    LABEL_REPEATED = 3,
}

---@enum google.protobuf.FileOptions.OptimizeMode
M.FileOptions_OptimizeMode = {
    SPEED = 1,
    CODE_SIZE = 2,
    LITE_RUNTIME = 3,
}

---@enum google.protobuf.FieldOptions.CType
M.FieldOptions_CType = {
    STRING = 0,
    CORD = 1,
    STRING_PIECE = 2,
}

---@enum google.protobuf.FieldOptions.JSType
M.FieldOptions_JSType = {
    JS_NORMAL = 0,
    JS_STRING = 1,
    JS_NUMBER = 2,
}

---@enum google.protobuf.MethodOptions.IdempotencyLevel
M.MethodOptions_IdempotencyLevel = {
    IDEMPOTENCY_UNKNOWN = 0,
    NO_SIDE_EFFECTS = 1,
    IDEMPOTENT = 2,
}

return M