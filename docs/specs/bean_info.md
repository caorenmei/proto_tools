# bean_info 模块设计文档

## 1. 模块定位

`bean_info` 是 protobuf 描述符信息构建器，负责从 `google.protobuf.FileDescriptorSet` 中解析并构建结构化的元数据，为后续的 Lua bean 代码生成提供数据基础。

最终目标是通过 proto 文件生成两份 Lua 代码：

- `player.lua` — 普通 bean，包含消息的字段访问、序列化/反序列化等基础功能。
- `player_Track.lua` — 可追踪 bean（track bean），在普通 bean 基础上增加脏字段追踪能力，用于增量同步、变更通知等场景。

模块路径：`lua_lib/gen_bean/bean_info.lua`

---

## 2. 核心数据结构

### 2.1 DescriptorSetInfo（描述符集合信息）

根节点，容纳整个 DescriptorSet 的解析结果。

| 字段 | 类型 | 说明 |
|------|------|------|
| `descriptor_set` | `table` | 原始的 `google.protobuf.FileDescriptorSet` 描述符 |
| `files` | `table<string, FileInfo>` | 文件列表，key 为文件名 |
| `messages` | `table<string, MessageInfo>` | 消息列表，key 为消息全名（支持 `_` 和 `.` 两种分隔符） |
| `enums` | `table<string, EnumInfo>` | 枚举列表，key 为枚举全名（支持 `_` 和 `.` 两种分隔符） |

### 2.2 FileInfo（文件信息）

对应一个 `.proto` 文件。

| 字段 | 类型 | 说明 |
|------|------|------|
| `descriptor` | `table` | 文件描述符（`google.protobuf.FileDescriptorProto`） |
| `name` | `string` | 文件名 |
| `package_name` | `string` | 包名 |
| `messages` | `MessageInfo[]` | 该文件中定义的所有消息（含嵌套消息） |
| `enums` | `EnumInfo[]` | 该文件中定义的所有枚举（含嵌套枚举） |

### 2.3 MessageInfo（消息信息）

对应一个 protobuf message。

| 字段 | 类型 | 说明 |
|------|------|------|
| `descriptor` | `table` | 消息描述符（`google.protobuf.DescriptorProto`） |
| `file` | `string` | 所在文件的全名 |
| `name` | `string` | 消息名（不含包名） |
| `full_name` | `string` | 消息全名，嵌套部分以 `_` 分隔，例如 `package.Message_NestedMessage` |
| `full_name_dot` | `string` | 消息全名，嵌套部分以 `.` 分隔，例如 `package.Message.NestedMessage` |
| `fields` | `FieldInfo[]` | 字段列表 |
| `oneofs` | `OneofInfo[]` | oneof 字段列表 |
| `track_field_count` | `integer` | 脏字段数量（需要追踪变更的字段数） |
| `track_words` | `integer` | 存储脏字段位标记所需的 64 位整数个数，等于 `math.ceil(track_field_count / 64)` |

### 2.4 FieldInfo（字段信息）

对应消息中的一个字段。

| 字段 | 类型 | 说明 |
|------|------|------|
| `descriptor` | `table` | 字段描述符（`google.protobuf.FieldDescriptorProto`） |
| `message` | `string` | 所在消息的全名 |
| `name` | `string` | 字段名 |
| `index` | `integer` | 字段在消息中的原始索引，从 1 开始 |
| `type` | `google.protobuf.FieldDescriptorProto.Type \| string` | 字段类型；基本类型时为枚举值，消息类型时为消息全名 |
| `is_repeated` | `boolean` | 是否是 `repeated` 字段 |
| `is_map` | `boolean` | 是否是 map 字段（在 `process_fields` 阶段识别） |
| `is_oneof` | `boolean` | 是否是 oneof 字段 |
| `oneof_name` | `string` | oneof 字段名 |
| `oneof_index` | `integer` | oneof 在消息 oneofs 数组中的索引，从 1 开始；非 oneof 字段为 0 |
| `oneof_data_index` | `integer` | 字段在 oneof 中的编码编号：第 1 位表示是否是 message 类型，后续位表示 oneof 内字段索引，从 1 开始 |
| `map_key_type` | `google.protobuf.FieldDescriptorProto.Type \| 0` | map 字段 key 的类型；非 map 字段为 0 |
| `map_value_type` | `google.protobuf.FieldDescriptorProto.Type \| string \| 0` | map 字段 value 的类型；非 map 字段为 0 |
| `track_index` | `integer` | 脏字段编号，用于位运算标识脏字段，从 1 开始；不需要追踪的字段为 0 |
| `data_index` | `integer` | 普通消息数据在消息数组中的索引位置，从 1 开始 |

### 2.5 OneofInfo（oneof 信息）

对应消息中的一个 oneof 声明。

| 字段 | 类型 | 说明 |
|------|------|------|
| `descriptor` | `table` | oneof 描述符 |
| `message` | `string` | 所在消息的全名 |
| `name` | `string` | oneof 字段名 |
| `index` | `integer` | oneof 在消息中的索引，从 1 开始 |
| `track_index` | `integer` | 脏字段编号，oneof 内所有字段共享此编号，从 1 开始 |
| `data_index` | `integer` | oneof 数据在消息数组中的起始索引，从 1 开始 |

### 2.6 EnumInfo（枚举信息）

对应一个 protobuf enum。

| 字段 | 类型 | 说明 |
|------|------|------|
| `descriptor` | `table` | 枚举描述符（`google.protobuf.EnumDescriptorProto`） |
| `file` | `string` | 所在文件的全名 |
| `name` | `string` | 枚举名（不含包名） |
| `full_name` | `string` | 枚举全名，嵌套部分以 `_` 分隔 |
| `full_name_dot` | `string` | 枚举全名，嵌套部分以 `.` 分隔 |
| `values` | `{ key: string, value: integer }[]` | 枚举值列表，`key` 为枚举值名，`value` 为编号 |

---

## 3. 构建流程

构建过程采用深度优先遍历，整体流程如下：

```
build_info(descriptor_set)
    ├── 遍历 file（每个 .proto 文件）
    │       ├── 遍历 enum_type → build_enum_info()
    │       └── 遍历 message_type → build_message_info()
    │               ├── 遍历 field → build_field_info()
    │               ├── 遍历 oneof_decl → build_oneof_info()
    │               ├── process_fields() — 后处理：识别 map、分配索引
    │               ├── 遍历 enum_type（嵌套枚举）→ build_enum_info()
    │               └── 遍历 nested_type（嵌套消息）→ build_message_info()（递归）
    │
    └── 返回 DescriptorSetInfo
```

### 3.1 build_info

入口函数，接收 `google.protobuf.FileDescriptorSet`，初始化 `DescriptorSetInfo`，遍历所有文件分别构建 `FileInfo`，并将文件中的枚举和消息递归解析。

### 3.2 build_message_info

为单个消息构建 `MessageInfo`，同时：

- 生成 `full_name`（`_` 分隔）和 `full_name_dot`（`.` 分隔），两种格式均注册到 `info.messages` 中。
- 递归处理嵌套枚举和嵌套消息。

### 3.3 build_enum_info

为单个枚举构建 `EnumInfo`，同样注册两种全名格式，并收集所有枚举值。

### 3.4 build_field_info

为单个字段构建 `FieldInfo` 基础信息：

- 若字段类型为 `TYPE_MESSAGE`，将 `type` 解析为消息全名（去掉前导 `.`）。
- 判断 `is_repeated`（`label == LABEL_REPEATED`）。
- 判断 `is_oneof`（`oneof_index ~= nil`），并记录 `oneof_index`（protobuf 内部从 0 开始，此处转换为从 1 开始）。

### 3.5 build_oneof_info

为单个 oneof 声明构建 `OneofInfo`，此时 `track_index` 和 `data_index` 尚未分配，在 `process_fields` 中统一处理。

### 3.6 process_fields

后处理阶段，完成以下工作：

1. **Map 字段识别**：检查 `repeated` 的 message 类型字段，若其对应的消息描述符带有 `map_entry` 选项，则标记为 map，并提取 `key` 和 `value` 子字段的类型。
2. **脏字段标记**：根据消息级别的 `options.level` 和字段级别的 `options.transient` 决定哪些字段需要追踪。
3. **track_index 分配**：为需要追踪的字段和 oneof 分配连续的脏字段编号。
4. **data_index 分配**：为所有字段分配在消息数据数组中的位置索引。

---

## 4. track_index 分配逻辑

track_index 用于标识哪些字段发生了变更，通过位运算实现。分配规则如下：

### 4.1 追踪条件

一个字段需要被追踪（分配非零 `track_index`）当且仅当：

- 消息不是非追踪消息（即 `message_descriptor.options.level ~= 0`，`level` 未设置或不为 0 时默认追踪）。
- 字段不是 `transient` 字段（即 `field_descriptor.options.transient` 未设置或不为 true）。

### 4.2 oneof 分组共享

oneof 内的所有字段共享同一个 `track_index`。具体逻辑：

1. 第一轮遍历：将符合条件的字段标记 `track_index = 1`（临时标记）。
2. 第二轮遍历：按顺序分配实际编号。
   - 若字段属于 oneof（`oneof_index > 0`）且需要追踪：
     - 若该 oneof 尚未分配编号，则分配一个新的连续编号给 `oneof_info.track_index`。
     - 字段自身的 `track_index` 暂时保持临时值。
   - 若字段不属于 oneof 且需要追踪：直接分配一个新的连续编号。
3. 第三轮遍历：将 oneof 内所有字段的 `track_index` 统一设为所属 `oneof_info.track_index`。

### 4.3 示例

假设消息有字段：A（普通）、B（oneof1）、C（oneof1）、D（普通，transient）、E（oneof2）

| 字段 | track_index |
|------|-------------|
| A | 1 |
| B | 2（与 oneof1 共享） |
| C | 2（与 oneof1 共享） |
| D | 0（transient，不追踪） |
| E | 3（与 oneof2 共享） |

`track_field_count = 3`，`track_words = 1`（仅需 1 个 64 位整数）。

---

## 5. data_index 分配逻辑

data_index 定义了字段数据在消息内部数组中的存储位置，用于运行时的数据存取。

### 5.1 分配规则

| 字段类型 | data_index 占用 | 说明 |
|----------|----------------|------|
| 普通字段 | 1 个 | 直接存储字段值 |
| map 字段 | 2 个 | 第 1 个存储 map 长度，第 2 个存储 map 数据 |
| oneof 字段 | 2 个（整个 oneof 共享） | 第 1 个存储当前激活的字段标识，第 2 个存储字段数据 |

### 5.2 oneof_data_index 编码规则

`oneof_data_index` 是一个整数，编码规则如下：

- 第 1 位（最低位）：表示字段类型是否是 message 类型（`string` 类型为 1，基本类型为 0）。
- 后续位：表示该字段在 oneof 内的顺序索引，从 1 开始。

公式：`oneof_data_index = (oneof内字段索引 << 1) + (type == "string" ? 1 : 0)`

例如，oneof 内有三个字段：

- `int32 id` → `oneof_data_index = (1 << 1) + 0 = 2`（二进制 `10`）
- `string name` → `oneof_data_index = (2 << 1) + 1 = 5`（二进制 `101`）
- `PlayerInfo info` → `oneof_data_index = (3 << 1) + 1 = 7`（二进制 `111`）

编码后的 `oneof_data_index` 可用于运行时快速判断当前激活的是哪个 oneof 字段，以及其类型信息。

---

## 6. 类型分类

模块预定义了四组类型集合，用于代码生成时的类型判断：

| 集合名 | 包含类型 | 用途 |
|--------|---------|------|
| `IntegerTypes` | `TYPE_INT32`, `TYPE_INT64`, `TYPE_UINT32`, `TYPE_UINT64`, `TYPE_SINT32`, `TYPE_SINT64`, `TYPE_FIXED32`, `TYPE_FIXED64`, `TYPE_SFIXED32`, `TYPE_SFIXED64` | 整数类型判断 |
| `NumberTypes` | `TYPE_DOUBLE`, `TYPE_FLOAT` | 浮点数类型判断 |
| `StringTypes` | `TYPE_STRING`, `TYPE_BYTES` | 字符串/字节类型判断 |
| `EnumTypes` | `TYPE_ENUM` | 枚举类型判断 |

这些集合通过 `FieldType`（`google.protobuf.FieldDescriptorProto.Type` 枚举）作为 key 构建为查找表（`{ [FieldType] = true }`），便于 O(1) 时间复杂度判断字段所属类型类别。

---

## 7. Map 字段识别

Map 字段在 protobuf 中被编译为 `repeated` 的嵌套消息，该嵌套消息带有 `map_entry = true` 选项。识别逻辑：

1. 检查字段是否为 `repeated` 且类型为 `TYPE_MESSAGE`。
2. 通过 `field.type`（消息全名）从 `info.messages` 中获取对应的消息信息。
3. 检查该消息描述符的 `options.map_entry` 是否为 true。
4. 若满足条件，标记 `field.is_map = true`。
5. 遍历该 entry 消息的 `field` 数组：
   - `name == "key"` 的字段类型赋给 `field.map_key_type`。
   - `name == "value"` 的字段类型赋给 `field.map_value_type`；若 value 为 message 类型，同样解析为全名。

---

## 8. 与代码生成的关系

`bean_info` 模块构建的元数据结构是代码生成器的输入，后续代码生成阶段（如 `gen_bean` 的其他子模块）将基于这些信息生成 Lua bean 代码。

### 8.1 生成普通 bean（player.lua）

- 使用 `MessageInfo` 中的字段列表生成字段访问器（getter/setter）。
- 使用 `FieldInfo.type`、`is_repeated`、`is_map` 等信息生成正确的序列化/反序列化代码。
- 使用 `EnumInfo` 生成 Lua 枚举表。
- 使用 `data_index` 确定字段在内部数据数组中的存储位置。

### 8.2 生成可追踪 bean（player_Track.lua）

在普通 bean 的基础上，增加脏字段追踪能力：

- 使用 `track_field_count` 和 `track_words` 声明脏字段位标记数组。
- 使用 `track_index` 在字段 setter 中设置对应的脏标记位。
- 使用 `data_index` 存储追踪后的字段值。
- oneof 字段通过共享的 `track_index` 实现整体变更追踪，通过 `oneof_data_index` 在运行时识别当前激活的 oneof 分支。
- map 字段通过额外的数据索引位置存储长度信息，支持增量同步时传输 map 的变更大小。

### 8.3 全名双格式注册的意义

`messages` 和 `enums` 表同时以 `_` 分隔和 `.` 分隔的全名作为 key，指向同一个对象。这使得代码生成器在处理不同来源的类型引用时（protobuf 内部使用 `.` 分隔，而生成代码的命名约定可能使用 `_` 分隔），都能快速定位到对应的元数据，无需额外的字符串转换。
