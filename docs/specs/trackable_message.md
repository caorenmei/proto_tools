# 不可追踪消息的递归排除方案

## 1. 问题背景

在 `bean_info` 模块中，`track_index` 用于标识需要追踪变更的字段。当前逻辑仅根据消息级别的 `options.level` 和字段级别的 `options.transient` 来决定是否分配 `track_index`。

然而存在一种情况：某个消息类型（记为 `Inner`）本身没有任何可追踪的字段（`track_field_count == 0`）。当另一个消息（记为 `Outer`）将 `Inner` 作为普通字段、`repeated` 字段或 `map` 的 `value` 类型时，追踪这个字段没有意义——因为 `Inner` 内部的任何修改都不会产生脏标记（它自身没有 `track_index`），只有整体替换时才会触发父消息的脏标记，而这种场景的增量同步价值极低。

此外，如果 `Inner` 的不可追踪性是由其嵌套消息导致的（例如 `Inner` 只包含一个 `DeepInner`，而 `DeepInner` 也没有可追踪字段），则需要**递归地**判断这种不可追踪性。

## 2. 方案目标

1. **自动排除**：在生成 `track_index` 时，自动排除类型为不可追踪消息的普通字段、`repeated` 字段、以及 `map` 的 `value` 字段。
2. **oneof 清空语义**：在 oneof 中，若某个可选分支是不可追踪的消息字段，则设置该字段时等价于"清空 oneof"（不触发脏标记）。
3. **递归传播**：不可追踪性的判断是递归的，需要沿消息嵌套层级向上传播。

## 3. 核心概念

### 3.1 可追踪消息（Trackable Message）

一个消息 `M` 是**可追踪的**，当且仅当满足以下条件之一：

- `M` 至少有一个标量类型（`int32`、`string`、`bool` 等）或枚举类型的字段被追踪（即该字段的 `track_index > 0`，基于现有 `options.level` 和 `options.transient` 规则）。
- `M` 至少有一个 message 类型字段，且该字段引用的消息是**可追踪的**。

### 3.2 不可追踪消息（Non-trackable Message）

不满足可追踪条件的消息。即：

- 该消息的所有标量/枚举字段要么是 `transient`，要么所属消息为 `level = 0`（非追踪消息）。
- 该消息的所有 message 类型字段引用的消息都是**不可追踪的**。

### 3.3 关键观察

- 一个消息是否可追踪，取决于它引用的其他消息的可追踪性，这形成了**消息引用图**。
- 该图可能存在环（protobuf 允许消息间循环引用），因此需要用**迭代收敛**的方式计算，而非简单递归。
- `track_field_count == 0` 是一个消息的不可追踪性的**表现结果**，而非**判断条件**。我们需要先判断可追踪性，再决定是否分配 `track_index`。

## 4. 实现方案

### 4.1 整体流程调整

在现有 `build_info` 流程的基础上，增加两个后处理阶段：

```
build_info(descriptor_set)
    ├── 阶段 A：现有逻辑 — 遍历所有 file，构建 MessageInfo / FieldInfo / OneofInfo
    │       └── process_fields() — 初始分配 track_index（基于现有 level/transient 规则）
    ├── 阶段 B：新增 — 计算每个消息的可追踪性（迭代收敛）
    └── 阶段 C：新增 — 基于可追踪性重新调整 track_index
```

### 4.2 阶段 B：计算消息可追踪性

#### 4.2.1 算法

```
-- 状态定义：trackable / non-trackable / unknown
for each message M in info.messages:
    M.trackable_state = "unknown"

changed = true
while changed:
    changed = false
    for each message M in info.messages:
        if M.trackable_state ~= "unknown":
            continue

        has_trackable_field = false
        for each field F in M.fields:
            if F.track_index == 0:
                -- 字段本身不被追踪（transient 或 level=0）
                continue

            if F.type is not a message type:
                -- 标量或枚举字段被追踪
                has_trackable_field = true
                break
            else:
                -- message 类型字段，检查引用消息的可追踪性
                local ref_msg = info.messages[F.type]
                if ref_msg.trackable_state == "trackable":
                    has_trackable_field = true
                    break
                elseif ref_msg.trackable_state == "non-trackable":
                    -- 引用消息不可追踪，该字段不计入
                    continue
                else:
                    -- 引用消息状态未知，暂时无法判断
                    has_trackable_field = nil  -- 标记为不确定
                    break

        if has_trackable_field == true:
            M.trackable_state = "trackable"
            changed = true
        elseif has_trackable_field == false:
            -- 所有字段要么不追踪，要么引用不可追踪消息
            M.trackable_state = "non-trackable"
            changed = true
        -- has_trackable_field == nil 时保持 unknown，下一轮再尝试

-- 循环结束后仍为 unknown 的消息（通常是因为循环引用导致无法确定）
-- 保守策略：标记为 non-trackable（因为无法证明它们有可追踪字段）
for each message M in info.messages:
    if M.trackable_state == "unknown":
        M.trackable_state = "non-trackable"
```

#### 4.2.2 收敛性说明

- 每次迭代至少会将一个 `unknown` 消息变为确定状态（`trackable` 或 `non-trackable`）。
- 消息总数有限，因此最多 `N` 轮迭代后收敛（`N` 为消息总数）。
- 实际中通常 2~3 轮即可收敛。

#### 4.2.3 示例

**示例 1：简单层级**

```protobuf
message DeepInner {
    int32 id = 1;  // trackable
}

message Inner {
    DeepInner deep = 1;  // DeepInner 可追踪 → Inner 可追踪
}

message Outer {
    Inner inner = 1;  // Inner 可追踪 → Outer 可追踪
}
```

- 第 1 轮：`DeepInner` 有标量字段 `id` → `trackable`
- 第 2 轮：`Inner` 引用 `DeepInner`（已确定 trackable）→ `trackable`
- 第 3 轮：`Outer` 引用 `Inner`（已确定 trackable）→ `trackable`

**示例 2：递归不可追踪**

```protobuf
message DeepInner {
    // 无字段（或所有字段 transient / level=0）
}

message Inner {
    DeepInner deep = 1;  // DeepInner 不可追踪
    // 无其他可追踪字段
}

message Outer {
    Inner inner = 1;  // Inner 不可追踪
    int32 count = 2;  // 可追踪
}
```

- 第 1 轮：`DeepInner` 无标量/枚举追踪字段，无 message 字段 → `non-trackable`
- 第 2 轮：`Inner` 的 `deep` 引用 `non-trackable`，无其他追踪字段 → `non-trackable`
- 第 3 轮：`Outer` 的 `inner` 引用 `non-trackable`，但 `count` 是标量且可追踪 → `trackable`

**示例 3：循环引用**

```protobuf
message A {
    B b = 1;  // 循环引用
}

message B {
    A a = 1;  // 循环引用
}
```

- 第 1 轮：`A` 和 `B` 均无标量/枚举追踪字段，互相引用且对方为 `unknown` → 均保持 `unknown`
- 循环结束：均标记为 `non-trackable`

### 4.3 阶段 C：重新调整 track_index

基于阶段 B 的计算结果，对所有消息重新执行 `track_index` 的分配。

#### 4.3.1 字段级别的调整规则

对于消息 `M` 中的每个字段 `F`：

| 字段类型 | 现有条件 | 新增排除条件 |
|----------|----------|--------------|
| 普通 message 字段 | `F.track_index > 0`（基于 level/transient） | 若 `info.messages[F.type]` 为 `non-trackable`，则 `F.track_index = 0` |
| `repeated` message 字段 | `F.track_index > 0` | 若元素消息为 `non-trackable`，则 `F.track_index = 0` |
| `map` 的 value 为 message | `F.track_index > 0` | 若 `map_value_type` 对应的消息为 `non-trackable`，则 `F.track_index = 0` |
| oneof 中的 message 字段 | `F.track_index > 0` | 若对应消息为 `non-trackable`，则 `F.track_index = 0`，且该 oneof 分支使用"清空 oneof"语义 |

#### 4.3.2 重新分配 track_index 的算法

与现有 `process_fields` 中的逻辑相同，但基于调整后的 `track_index` 标记重新编号：

```
-- 步骤 1：先将所有需要排除的字段的 track_index 清零
for each field F in M.fields:
    if F.type is a message type and info.messages[F.type].trackable_state == "non-trackable":
        F.track_index = 0
    if F.is_map and F.map_value_type is a message type
       and info.messages[F.map_value_type].trackable_state == "non-trackable":
        F.track_index = 0

-- 步骤 2：按现有逻辑重新分配连续编号
local track_index = 0
for each field F in M.fields:
    if F.oneof_index > 0:
        if F.track_index > 0:
            local oneof_info = M.oneofs[F.oneof_index]
            if oneof_info.track_index == 0:
                track_index = track_index + 1
                oneof_info.track_index = track_index
    elseif F.track_index > 0:
        track_index = track_index + 1
        F.track_index = track_index

for each field F in M.fields:
    if F.oneof_index > 0:
        local oneof_info = M.oneofs[F.oneof_index]
        F.track_index = oneof_info.track_index

M.track_field_count = track_index
M.track_words = math.ceil(track_index / 64)
```

注意：`data_index` 的分配**不受影响**，保持现有逻辑。因为即使字段不可追踪，它的数据仍然需要存储（只是不追踪变更）。

#### 4.3.3 oneof 的特殊处理

如果一个 oneof 内的所有可选字段调整后 `track_index` 均为 0，则该 oneof 的 `track_index` 也为 0。这意味着：

- 该 oneof 整体不分配脏字段编号。
- 在代码生成阶段，生成该 oneof 的 setter 时：
  - 对于不可追踪的 message 分支，设置该字段等价于调用 `clear_oneof_field`（不触发脏标记，不设置 `track_bit`）。
  - 这是因为：设置一个不可追踪的消息字段，不会导致任何子消息级别的脏标记传播，因此父消息无需追踪这个 oneof 的变化。

**示例：**

```protobuf
message Inner {
    // 无追踪字段
}

message Outer {
    oneof choice {
        int32 id = 1;       // trackable
        Inner inner = 2;    // non-trackable
        string name = 3;    // trackable
    }
}
```

- `choice` oneof 有 2 个可追踪分支（`id` 和 `name`），所以 `choice` 分配 `track_index`。
- 但设置 `inner` 分支时，在生成的代码中应该：
  1. 清除旧的 oneof 值（与正常 oneof setter 相同）。
  2. 不设置 `track_bit`（因为 `inner` 不可追踪）。
  3. 存储 `inner` 值（`data_index` 仍然有效）。

实际上，更简洁的实现是：**在代码生成阶段，对于不可追踪的 oneof 分支，直接生成 `clear_oneof_field` 调用，然后单独设置数据值（不经过 track 机制）**。

或者更精确地说：不可追踪的 oneof message 分支在 setter 中不应该调用 `set_oneof_field`（该函数会设置 `track_bit`），而应该直接清除旧值并设置新值，跳过 `track_bit` 的设置。

### 4.4 递归传播

不可追踪性的传播是自然的递归过程：

```
A.trackable = f(B.trackable, C.trackable, ...)
  B.trackable = f(D.trackable, E.trackable, ...)
    D.trackable = true  -- 有标量追踪字段
    E.trackable = false -- 无可追踪字段
  C.trackable = f(F.trackable, ...)
    ...
```

阶段 B 的迭代收敛算法自动处理了这种递归传播。阶段 C 的重新调整则确保了一个消息被判定为不可追踪后，所有引用它的字段的 `track_index` 都被清零，进而可能导致引用它的父消息也变为不可追踪（如果父消息没有其他可追踪字段的话）。

## 5. 数据结构变更

### 5.1 MessageInfo 新增字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `trackable_state` | `string` | `"trackable"` 或 `"non-trackable"` |

### 5.2 无需变更的数据结构

- `FieldInfo`：无需新增字段，通过将 `track_index` 置 0 来表示排除。
- `OneofInfo`：同样通过 `track_index` 置 0 来表示排除。
- `data_index`：保持现有分配，不可追踪字段的数据仍然需要存储。

## 6. 与代码生成的关系

### 6.1 普通 bean（player.lua）

无影响。普通 bean 不追踪脏字段，不涉及 `track_index`。

### 6.2 可追踪 bean（player_Track.lua）

#### 6.2.1 普通字段 setter

对于不可追踪的 message 字段，生成的 setter 应该：
- **不调用** `set_track_bit`。
- 直接存储值（使用 `data_index`）。
- 如果旧值存在，需要解绑回调（与现有逻辑相同）。
- 不绑定新值的回调（因为新值是不可追踪消息，不会有脏标记回调）。

#### 6.2.2 oneof 字段 setter

对于不可追踪的 message 分支：
- 生成的代码等同于 `clear_oneof_field` + 直接存储值。
- 不设置 `track_bit`。
- 因为该 oneof 可能还有其他可追踪分支，所以 oneof 整体仍然分配 `track_index`，只是设置不可追踪分支时跳过 `track_bit`。

#### 6.2.3 repeated / map 字段

对于元素为不可追踪消息的 `repeated` 或 `map`：
- 字段本身的 `track_index = 0`，不追踪整体变更。
- 但 `data_index` 仍然有效，可以正常增删改查。
- `track_maps` 机制不启用（因为没有 `track_index`）。

## 7. 边界情况处理

| 场景 | 处理 |
|------|------|
| 消息自引用 | 迭代收敛算法可处理，自引用无标量字段的消息标记为 `non-trackable` |
| 循环引用 | 同上，最多 `N` 轮收敛 |
| `map` 的 key 为不可追踪消息 | `map` 的 key 只能是标量类型（protobuf 限制），无需处理 |
| oneof 全部分支不可追踪 | oneof 的 `track_index = 0`，代码生成时所有分支均跳过 `track_bit` |
| 顶层消息（无父消息）不可追踪 | 该消息生成 `Track` 代码时 `track_field_count = 0`，`track_words = 0`，位图数组为空 |
| 运行时传入不可追踪消息 | 无需特殊处理，因为不可追踪消息本身没有回调机制 |

## 8. 实施步骤

1. **阶段 B 实现**：在 `bean_info.lua` 中新增 `compute_trackable_states(info)` 函数，实现迭代收敛算法。
2. **阶段 C 实现**：在 `bean_info.lua` 中新增 `rebuild_track_indices(info)` 函数，基于可追踪性重新分配 `track_index`。
3. **build_info 调用调整**：在 `build_info` 末尾调用上述两个函数。
4. **代码生成调整**：在 `gen_bean` 的代码生成模块中，根据字段的 `track_index` 和消息类型的 `trackable_state` 生成对应的 setter 逻辑（不可追踪分支跳过 `track_bit`）。
5. **测试**：构造包含不可追踪消息嵌套场景的 proto 文件，验证 `track_index` 分配和代码生成行为。

## 9. 示例验证

### 9.1 Proto 定义

```protobuf
syntax = "proto3";

message EmptyInner {
    // 无任何字段
}

message ScalarOnly {
    int32 id = 1;
}

message NestedA {
    EmptyInner empty = 1;
    // empty 不可追踪，NestedA 无其他追踪字段
}

message NestedB {
    ScalarOnly scalar = 1;
    // scalar 可追踪 → NestedB 可追踪
}

message Root {
    EmptyInner empty_field = 1;      // 应排除 track_index
    ScalarOnly scalar_field = 2;     // 应分配 track_index
    NestedA nested_a = 3;            // 应排除 track_index（NestedA 不可追踪）
    NestedB nested_b = 4;            // 应分配 track_index（NestedB 可追踪）
    repeated EmptyInner empty_list = 5;    // 应排除 track_index
    repeated ScalarOnly scalar_list = 6;   // 应分配 track_index
    map<string, EmptyInner> empty_map = 7;   // 应排除 track_index
    map<string, ScalarOnly> scalar_map = 8;  // 应分配 track_index

    oneof choice {
        int32 choice_id = 9;         // trackable
        EmptyInner choice_empty = 10; // 不可追踪分支，设置时清空 oneof
        ScalarOnly choice_scalar = 11; // trackable
    }
}
```

### 9.2 预期 track_index 分配结果

| 字段 | track_index | 原因 |
|------|-------------|------|
| `empty_field` | 0 | `EmptyInner` 不可追踪 |
| `scalar_field` | 1 | `ScalarOnly` 可追踪 |
| `nested_a` | 0 | `NestedA` 不可追踪 |
| `nested_b` | 2 | `NestedB` 可追踪 |
| `empty_list` | 0 | 元素 `EmptyInner` 不可追踪 |
| `scalar_list` | 3 | 元素 `ScalarOnly` 可追踪 |
| `empty_map` | 0 | value `EmptyInner` 不可追踪 |
| `scalar_map` | 4 | value `ScalarOnly` 可追踪 |
| `choice` (oneof) | 5 | `choice_id` 和 `choice_scalar` 可追踪 |
| `choice_id` | 5 | 共享 oneof track_index |
| `choice_empty` | 5 | 共享 oneof track_index，但 setter 跳过 track_bit |
| `choice_scalar` | 5 | 共享 oneof track_index |

`Root.track_field_count = 5`，`Root.track_words = 1`。

### 9.3 各消息的可追踪状态

| 消息 | trackable_state | 原因 |
|------|-----------------|------|
| `EmptyInner` | `non-trackable` | 无字段 |
| `ScalarOnly` | `trackable` | 有标量字段 `id` |
| `NestedA` | `non-trackable` | `empty` 引用 `EmptyInner`（不可追踪），无其他追踪字段 |
| `NestedB` | `trackable` | `scalar` 引用 `ScalarOnly`（可追踪） |
| `Root` | `trackable` | 有多个直接可追踪字段 |
