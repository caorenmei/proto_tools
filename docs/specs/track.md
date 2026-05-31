# track.lua 模块设计文档

## 模块定位

`bean_utils.track` 是可追踪 bean 的运行时修改追踪引擎。

最终目标是通过 proto 文件生成 `player_Track.lua`，支持：
- 追踪 bean 字段的修改
- 生成增量数据（patch）
- 合并增量数据

该模块为生成的 bean 代码提供底层追踪能力，不直接面向业务层。

---

## 核心机制 — 位标记追踪

### 消息结构

bean 实例（`self`）被设计为一个数组（`any[]`），其索引含义如下：

| 索引 | 含义 |
|------|------|
| `self[1]` | 回调函数 `fun(has_bit: boolean)`，用于通知父消息自身脏标记变化 |
| `self[2]` ~ `self[1 + track_words]` | 64 位位图数组，每个元素是一个 `integer`，共 `track_words` 个 64 位字 |
| `self[data_index]` 起 | 实际业务数据字段 |

`track_words` 由 proto 中需要追踪的字段数量决定，计算公式为 `ceil(max_track_index / 64)`。

### set_track_bit

根据 `track_index` 设置或清除对应位，同时触发回调通知父消息。

```
track_index ──→ words_index = ((track_index + 63) // 64) + 1
           ──→ bit_index   = (track_index - 1) % 64
```

- 若位状态未变化，直接返回 `false`
- 若位状态变化，更新位图后：
  - 若从"无脏字段"变为"有脏字段"，调用 `self[1](true)`
  - 若从"有脏字段"变为"无脏字段"，调用 `self[1](false)`

### is_tracked_bean

遍历 `self[2]` ~ `self[1 + track_words]`，检查是否有任何位被置位。用于判断 bean 是否存在脏字段。

---

## 回调机制

`self[1]` 是子消息向父消息传递脏标记变化的回调函数：

- `self[1](true)`：通知父消息"本消息变为有脏字段"
- `self[1](false)`：通知父消息"本消息变为无脏字段"

父消息收到回调后，通过 `set_track_bit` 设置自身的对应位，从而将脏标记逐层向上冒泡。这形成了一个树状的脏标记传播机制：叶子节点的修改会沿着消息嵌套层级向上传递，直到根节点。

---

## TrackState 枚举

用于记录 `map` / `repeated` 中每个元素的变更状态：

| 状态值 | 名称 | 含义 |
|--------|------|------|
| `1` | `Added` | 新增的元素 |
| `2` | `Updated` | 已存在但被修改的元素 |
| `3` | `Removed` | 已删除的元素 |
| `4` | `RemovedAdded` | 先删除后重新添加的元素（oneof 切换场景） |

`TrackState` 与位标记配合使用：位标记用于快速判断字段是否有变更，`TrackState` 用于记录细粒度的变更内容，二者结合可生成完整的增量 patch。

---

## Map 细粒度追踪

对于 `map` 和 `repeated` 类型字段，除了位标记外，还需要一个 `track_maps` 表来记录每个元素的变更状态。

`track_maps` 的结构为：`{ [map_or_list]: { [key]: TrackState } }`

### track_map_add

记录新增操作：
- 若 key 无状态 → 标记为 `Added`
- 若 key 状态为 `Removed` → 升级为 `RemovedAdded`

### track_map_update

记录修改操作：
- 若 key 无状态且 `has_bit` 为 true → 标记为 `Updated`
- 若 key 状态为 `Updated` 且 `has_bit` 为 false → 清除该 key 的追踪状态；若 map 为空则清除整个 map 的追踪

### track_map_remove

记录删除操作：
- 若 key 状态为 `Added` → 直接清除（相当于从未添加）
- 其他情况 → 标记为 `Removed`

### track_map_remove_add

用于 oneof 字段切换场景：
- 若 key 无状态 → 标记为 `Added`
- 若 key 状态为 `Updated` → 升级为 `RemovedAdded`

### track_map_clear_repeated / track_map_clear_map

批量清除操作：
- 遍历所有元素，状态为 `Added` 的直接清除，其余标记为 `Removed`
- 若清除后 map 为空，则移除整个 map 的追踪记录

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
| `set_field(self, track_words, track_index, data_index, value, assertion)` | 设置标量字段，值变化时置位 |
| `get_message(self, track_words, track_index, data_index, constructor)` | 获取或懒创建子消息，自动绑定回调 |

### oneof 字段

| 函数 | 说明 |
|------|------|
| `set_oneof_field(self, track_words, track_index, data_index, track_maps, oneof_index, value, assertion)` | 设置 oneof 字段，处理旧值解绑和新值绑定 |
| `add_oneof_message(self, track_words, track_index, data_index, track_maps, oneof_index, constructor)` | 添加 oneof 子消息，复用 `set_oneof_field` |
| `clear_oneof_field(self, track_words, track_index, data_index, track_maps)` | 清除 oneof 字段，解绑旧值回调 |

oneof 字段在 `data_index` 处存储 `oneof_index`，在 `data_index + 1` 处存储值。`oneof_index & 1 == 1` 表示值为消息类型，需要管理回调。

### repeated 字段

| 函数 | 说明 |
|------|------|
| `add_repeated_value(self, ..., value, assertion)` | 在列表末尾追加值 |
| `set_repeated_value(self, ..., value_index, value, assertion)` | 修改指定索引的值 |
| `pop_repeated_value(self, ...)` | 弹出末尾元素 |
| `clear_repeated_value(self, ...)` | 清空整个列表 |
| `add_repeated_message(self, ..., constructor)` | 追加子消息，自动绑定回调 |
| `pop_repeated_message(self, ...)` | 弹出子消息，解绑回调 |
| `clear_repeated_message(self, ...)` | 清空子消息列表，解绑所有回调 |

### map 字段

| 函数 | 说明 |
|------|------|
| `set_map_value(self, ..., key, value, assertion)` | 设置 map 键值对，新 key 走 `track_map_add`，已存在走 `track_map_update` |
| `remove_map_key(self, ..., key)` | 删除 map 中的 key |
| `clear_map(self, ...)` | 清空整个 map |
| `add_map_message(self, ..., key, constructor)` | 添加 map 子消息，自动绑定回调 |
| `remove_map_message(self, ..., key)` | 删除 map 子消息，解绑回调 |
| `clear_map_message(self, ...)` | 清空 map 子消息，解绑所有回调 |

map 字段在 `data_index` 处存储长度计数，在 `data_index + 1` 处存储实际 map 表。

---

## 与增量数据的关系

位标记和 `TrackState` 共同支撑增量数据的生成：

1. **位标记**用于快速判断哪些字段发生了变更。在生成 patch 时，只需遍历被置位的字段，无需扫描全部字段。

2. **`TrackState`** 记录了 `map` 和 `repeated` 中每个元素的精确变更类型（Added/Updated/Removed/RemovedAdded），可直接转换为增量操作指令。

3. **回调冒泡**确保嵌套消息的变更能被父消息感知。当子消息的脏标记变化时，通过回调逐层向上传播，最终根节点的位标记反映整棵树的变更状态。

生成增量 patch 的流程：
- 从根 bean 开始，检查位标记
- 对被置位的字段，根据字段类型：
  - 标量/普通消息：直接取当前值作为 patch
  - `repeated`：结合 `track_maps` 中的 `TrackState`，生成 add/update/remove 指令
  - `map`：同理，生成 key 级别的增量操作
- 递归处理子消息

合并增量数据的流程（反向操作）：
- 解析 patch 中的字段变更
- 对普通字段直接覆盖
- 对 `repeated`/`map` 按 `TrackState` 语义应用变更
- 更新位标记和 `track_maps` 以反映合并后的状态
