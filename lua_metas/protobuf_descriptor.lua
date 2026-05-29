--- google.protobuf.descriptor.proto 的 EmmyLua 类型定义
---@meta

-- ============================================================================
-- Enums
-- ============================================================================

---@enum google.protobuf.FieldDescriptorProto.Type
google.protobuf.FieldDescriptorProto.Type = {
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
google.protobuf.FieldDescriptorProto.Label = {
    LABEL_OPTIONAL = 1,
    LABEL_REQUIRED = 2,
    LABEL_REPEATED = 3,
}

---@enum google.protobuf.FileOptions.OptimizeMode
google.protobuf.FileOptions.OptimizeMode = {
    SPEED = 1,
    CODE_SIZE = 2,
    LITE_RUNTIME = 3,
}

---@enum google.protobuf.FieldOptions.CType
google.protobuf.FieldOptions.CType = {
    STRING = 0,
    CORD = 1,
    STRING_PIECE = 2,
}

---@enum google.protobuf.FieldOptions.JSType
google.protobuf.FieldOptions.JSType = {
    JS_NORMAL = 0,
    JS_STRING = 1,
    JS_NUMBER = 2,
}

---@enum google.protobuf.MethodOptions.IdempotencyLevel
google.protobuf.MethodOptions.IdempotencyLevel = {
    IDEMPOTENCY_UNKNOWN = 0,
    NO_SIDE_EFFECTS = 1,
    IDEMPOTENT = 2,
}

-- ============================================================================
-- Messages
-- ============================================================================

---@class google.protobuf.FileDescriptorSet
---@field file google.protobuf.FileDescriptorProto[]

---@class google.protobuf.FileDescriptorProto
---@field name string
---@field package string?
---@field dependency string[]
---@field public_dependency integer[]
---@field weak_dependency integer[]
---@field message_type google.protobuf.DescriptorProto[]
---@field enum_type google.protobuf.EnumDescriptorProto[]
---@field service google.protobuf.ServiceDescriptorProto[]
---@field extension google.protobuf.FieldDescriptorProto[]
---@field options google.protobuf.FileOptions?
---@field source_code_info google.protobuf.SourceCodeInfo?
---@field syntax string

---@class google.protobuf.DescriptorProto
---@field name string
---@field field google.protobuf.FieldDescriptorProto[]
---@field extension google.protobuf.FieldDescriptorProto[]
---@field nested_type google.protobuf.DescriptorProto[]
---@field enum_type google.protobuf.EnumDescriptorProto[]
---@field extension_range google.protobuf.DescriptorProto.ExtensionRange[]
---@field oneof_decl google.protobuf.OneofDescriptorProto[]
---@field options google.protobuf.MessageOptions?
---@field reserved_range google.protobuf.DescriptorProto.ReservedRange[]
---@field reserved_name string[]

---@class google.protobuf.DescriptorProto.ExtensionRange
---@field start integer?
---@field end integer?
---@field options google.protobuf.ExtensionRangeOptions?

---@class google.protobuf.DescriptorProto.ReservedRange
---@field start integer?
---@field end integer?

---@class google.protobuf.ExtensionRangeOptions
---@field uninterpreted_option google.protobuf.UninterpretedOption[]

---@class google.protobuf.FieldDescriptorProto
---@field name string
---@field number integer
---@field label google.protobuf.FieldDescriptorProto.Label
---@field type google.protobuf.FieldDescriptorProto.Type
---@field type_name string?
---@field extendee string?
---@field default_value string?
---@field oneof_index integer?
---@field json_name string
---@field options google.protobuf.FieldOptions?
---@field proto3_optional boolean?

---@class google.protobuf.OneofDescriptorProto
---@field name string
---@field options google.protobuf.OneofOptions?

---@class google.protobuf.EnumDescriptorProto
---@field name string
---@field value google.protobuf.EnumValueDescriptorProto[]
---@field options google.protobuf.EnumOptions?
---@field reserved_range google.protobuf.EnumDescriptorProto.EnumReservedRange[]
---@field reserved_name string[]

---@class google.protobuf.EnumDescriptorProto.EnumReservedRange
---@field start integer?
---@field end integer?

---@class google.protobuf.EnumValueDescriptorProto
---@field name string
---@field number integer
---@field options google.protobuf.EnumValueOptions?

---@class google.protobuf.ServiceDescriptorProto
---@field name string
---@field method google.protobuf.MethodDescriptorProto[]
---@field options google.protobuf.ServiceOptions?

---@class google.protobuf.MethodDescriptorProto
---@field name string
---@field input_type string
---@field output_type string
---@field options google.protobuf.MethodOptions?
---@field client_streaming boolean
---@field server_streaming boolean

---@class google.protobuf.FileOptions
---@field java_package string?
---@field java_outer_classname string?
---@field java_multiple_files boolean?
---@field java_generate_equals_and_hash boolean?
---@field java_string_check_utf8 boolean?
---@field optimize_for google.protobuf.FileOptions.OptimizeMode?
---@field go_package string?
---@field cc_generic_services boolean?
---@field java_generic_services boolean?
---@field py_generic_services boolean?
---@field php_generic_services boolean?
---@field deprecated boolean?
---@field cc_enable_arenas boolean?
---@field objc_class_prefix string?
---@field csharp_namespace string?
---@field swift_prefix string?
---@field php_class_prefix string?
---@field php_namespace string?
---@field php_metadata_namespace string?
---@field ruby_package string?
---@field uninterpreted_option google.protobuf.UninterpretedOption[]

---@class google.protobuf.MessageOptions
---@field message_set_wire_format boolean?
---@field no_standard_descriptor_accessor boolean?
---@field deprecated boolean?
---@field map_entry boolean?
---@field uninterpreted_option google.protobuf.UninterpretedOption[]

---@class google.protobuf.FieldOptions
---@field ctype google.protobuf.FieldOptions.CType?
---@field packed boolean?
---@field jstype google.protobuf.FieldOptions.JSType?
---@field lazy boolean?
---@field unverified_lazy boolean?
---@field deprecated boolean?
---@field weak boolean?
---@field uninterpreted_option google.protobuf.UninterpretedOption[]

---@class google.protobuf.OneofOptions
---@field uninterpreted_option google.protobuf.UninterpretedOption[]

---@class google.protobuf.EnumOptions
---@field allow_alias boolean?
---@field deprecated boolean?
---@field uninterpreted_option google.protobuf.UninterpretedOption[]

---@class google.protobuf.EnumValueOptions
---@field deprecated boolean?
---@field uninterpreted_option google.protobuf.UninterpretedOption[]

---@class google.protobuf.ServiceOptions
---@field deprecated boolean?
---@field uninterpreted_option google.protobuf.UninterpretedOption[]

---@class google.protobuf.MethodOptions
---@field deprecated boolean?
---@field idempotency_level google.protobuf.MethodOptions.IdempotencyLevel?
---@field uninterpreted_option google.protobuf.UninterpretedOption[]

---@class google.protobuf.UninterpretedOption
---@field name google.protobuf.UninterpretedOption.NamePart[]
---@field identifier_value string?
---@field positive_int_value integer?
---@field negative_int_value integer?
---@field double_value number?
---@field string_value string?
---@field aggregate_value string?

---@class google.protobuf.UninterpretedOption.NamePart
---@field name_part string
---@field is_extension boolean

---@class google.protobuf.SourceCodeInfo
---@field location google.protobuf.SourceCodeInfo.Location[]

---@class google.protobuf.SourceCodeInfo.Location
---@field path integer[]
---@field span integer[]
---@field leading_comments string?
---@field trailing_comments string?
---@field leading_detached_comments string[]

---@class google.protobuf.GeneratedCodeInfo
---@field annotation google.protobuf.GeneratedCodeInfo.Annotation[]

---@class google.protobuf.GeneratedCodeInfo.Annotation
---@field path integer[]
---@field source_file string?
---@field begin integer?
---@field end integer?
