# plain.lua 模块设计文档

## 模块定位

`bean_utils.plain` 是普通 bean 的运行时基础操作库，为生成的 plain bean 代码提供字段读写、嵌套消息管理、repeated/map 操作等基础能力。

与 `track.lua` 不同，`plain.lua` **不维护脏字段标记**，也**不向父消息冒泡变更通知**。它只负责纯数据的存取操作，是 track bean 的轻量级替代方案，适用于不需要增量同步和变更追踪的场景。

最终目标是通过 proto 文件生成 `player.lua`，支持：
- 字段访问（getter/setter）
- 序列化/反序列化
- 嵌套消息、repeated、map 等复杂类型的基础操作

---

## 核心机制

### 消息结构

plain bean 实例（`self`）被设计为一个数组（`any[]`），其索引含义如下：

| 索引 | 含义 |
|------|------|
| `self[data_index]` 起 | 实际业务数据字段 |

与 track bean 相比，plain bean 没有 `self[1]` 回调，也没有位图数组。`data_index` 直接从 1 开始，无需偏移。

### 数据索引

`data_index` 定义了字段数据在消息内部数组中的存储位置，由 `bean_info.lua` 在代码生成阶段分配：

| 字段类型 | data_index 占用 | 说明 |
|----------|----------------|------|
| 普通字段 | 1 个 | 直接存储字段值 |
| map 字段 | 2 个 | 第 1 个存储 map 长度，第 2 个存储 map 数据 |
| oneof 字段 | 2 个（整个 oneof 共享） | 第 1 个存储当前激活的字段标识，第 2 个存储字段数据 |

---

## 公共 API 分类

### 类型断言

| 函数 | 校验内容 |
|------|----------|
| `assert_int32(value)` | `integer`，范围 `[-0x80000000, 0x7FFFFFFF]` |
| `assert_uint32(value)` | `integer`，范围 `[0, 0xFFFFFFFF]` |
| `assert_string(value)` | `string` |
| `assert_boolean(value)` | `boolean` |
| `assert_float(value)` | `number` |

### 普通字段

| 函数 | 说明 |
|------|------|
| `set_field(self, data_index, value, assertion)` | 设置标量字段，值变化时返回 `true` |
| `get_message(self, data_index, constructor)` | 获取或懒创建子消息 |

### oneof 字段

| 函数 | 说明 |
|------|------|
| `set_oneof_field(self, data_index, oneof_index, value, assertion)` | 设置 oneof 字段 |
| `add_oneof_message(self, data_index, oneof_index, constructor)` | 添加 oneof 子消息，复用 `set_oneof_field` |
| `clear_oneof_field(self, data_index)` | 清除 oneof 字段 |

oneof 字段在 `data_index` 处存储 `oneof_index`，在 `data_index + 1` 处存储值。

### repeated 字段

| 函数 | 说明 |
|------|------|
| `add_repeated_value(self, data_index, value, assertion)` | 在列表末尾追加值 |
| `set_repeated_value(self, data_index, value_index, value, assertion)` | 修改指定索引的值 |
| `pop_repeated_value(self, data_index)` | 弹出末尾元素 |
| `clear_repeated_value(self, data_index)` | 清空整个列表 |
| `add_repeated_message(self, data_index, constructor)` | 追加子消息 |
| `pop_repeated_message(self, data_index)` | 弹出子消息 |
| `clear_repeated_message(self, data_index)` | 清空子消息列表 |

### map 字段

| 函数 | 说明 |
|------|------|
| `set_map_value(self, data_index, key, value, assertion)` | 设置 map 键值对 |
| `remove_map_key(self, data_index, key)` | 删除 map 中的 key |
| `clear_map(self, data_index)` | 清空整个 map |
| `add_map_message(self, data_index, key, constructor)` | 添加 map 子消息 |
| `remove_map_message(self, data_index, key)` | 删除 map 子消息 |
| `clear_map_message(self, data_index)` | 清空 map 子消息 |

map 字段在 `data_index` 处存储长度计数，在 `data_index + 1` 处存储实际 map 表。

---

## 与 track.lua 的差异

| 对比项 | plain.lua | track.lua |
|--------|-----------|-----------|
| 脏字段追踪 | ❌ 不支持 | ✅ 支持 |
| 父消息回调 | ❌ 无 `self[1]` | ✅ 有 `self[1]` 回调 |
| 位图数组 | ❌ 无 | ✅ `self[2]` ~ `self[1+track_words]` |
| `track_words` 参数 | ❌ 不需要 | ✅ 需要 |
| `track_index` 参数 | ❌ 不需要 | ✅ 需要 |
| `track_maps` 参数 | ❌ 不需要 | ✅ 需要 |
| `TrackState` | ❌ 无 | ✅ 有 |
| 增量数据生成 | ❌ 不支持 | ✅ 支持 |
| 适用场景 | 纯数据 bean | 需要增量同步的 bean |

### 函数签名差异示例

**普通字段设置：**
- plain: `set_field(self, data_index, value, assertion)`
- track: `set_field(self, track_words, track_index, data_index, value, assertion)`

**子消息获取：**
- plain: `get_message(self, data_index, constructor)` — 仅创建并存储子消息
- track: `get_message(self, track_words, track_index, data_index, constructor)` — 额外绑定回调 `new_value[1] = create_track_message(...)`，设置脏标记

**map 设置：**
- plain: `set_map_value(self, data_index, key, value, assertion)` — 直接更新 map，维护长度计数
- track: `set_map_value(self, track_words, track_index, data_index, track_maps, key, value, assertion)` — 额外维护 `track_maps` 和 `TrackState`，设置脏标记

---

## 与代码生成的关系

`bean_info.lua` 构建的元数据结构同样为 plain bean 的代码生成提供输入。plain bean 生成时：

- 使用 `MessageInfo` 中的字段列表生成字段访问器。
- 使用 `FieldInfo.type`、`is_repeated`、`is_map` 等信息生成正确的序列化/反序列化代码。
- 使用 `EnumInfo` 生成 Lua 枚举表。
- 使用 `data_index` 确定字段在内部数据数组中的存储位置。
- **不使用** `track_field_count`、`track_words`、`track_index` 等与追踪相关的字段。
