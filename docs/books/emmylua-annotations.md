# EmmyLua 注解格式参考

EmmyLua 注解以 `---@annotation` 格式写在 Lua 注释中，用于类型声明、代码补全和类型检查。配合 VS Code 的 EmmyLua 插件或 `.luarc.json` 配置，可以在编写 Lua 代码时获得静态类型分析能力。

---

## 目录

- [类型声明](#类型声明)
- [函数注解](#函数注解)
- [变量注解](#变量注解)
- [高级特性](#高级特性)
- [类型语法](#类型语法)
- [在 proto_tools 中的使用](#在-proto_tools-中的使用)

---

## 类型声明

### `@class` — 类/结构声明

用于声明一个类或数据结构，可指定父类实现继承关系。

```lua
---@class CLASS_NAME [: PARENT_NAME] [@comment]
```

`@field` 注解必须紧跟在 `@class` 之后，用于声明类的字段。

**示例：**

```lua
---@class Vector3
---@field x number
---@field y number
---@field z number

---@class Car : Transport @Car extends Transport
---@field public horsepower number
```

### `@field` — 字段声明

声明类或结构的字段，可指定访问修饰符。

```lua
---@field [public|protected|private] field_name TYPE[|OTHER_TYPE] [@comment]
```

**示例：**

```lua
---@class Person
---@field public name string
---@field private age number
---@field protected friends Person[]
```

### `@enum` — 枚举定义

用于定义一组具名常量。

```lua
---@enum [(attribute)] NAME
```

**示例：**

```lua
---@enum Color
Color = {
    Red = 1,
    Green = 2,
    Blue = 3,
}
```

---

## 函数注解

### `@param` — 参数类型

声明函数参数的类型。

```lua
---@param param_name TYPE[|OTHER_TYPE] [@comment]
```

**示例：**

```lua
---@param name string
---@param age number
---@param tags string[]
function createPerson(name, age, tags)
end
```

### `@return` — 返回类型

声明函数的返回值类型。

```lua
---@return TYPE [name] [@comment]
```

**示例：**

```lua
---@return string name @用户名称
---@return number age @用户年龄
function getUserInfo()
    return "Alice", 30
end
```

### `@overload` — 函数重载

声明函数的多个重载签名，适用于参数或返回值类型随调用方式变化的情况。

```lua
---@overload fun(param: TYPE): RETURN_TYPE
```

**示例：**

```lua
---@overload fun(type_name: string, data: table): string
---@overload fun(type_name: string, data: table, b: pb.Buffer): pb.Buffer
function pb.encode(type_name, data, b) end
```

---

## 变量注解

### `@type` — 变量类型声明

为变量显式指定类型，常用于局部变量或表字面量。

```lua
---@type TYPE[|OTHER_TYPE] [@comment]
```

**示例：**

```lua
---@type Car
local myCar = { name = "Speedster", horsepower = 250 }

---@type string | number
local id = "user_123"
```

---

## 高级特性

### `@generic` — 泛型

声明泛型类型参数，用于实现类型安全的通用函数或类。

```lua
---@generic T
---@param list T[]
---@return T
function first(list)
    return list[1]
end
```

### `@meta` — 元文件标记

标记当前文件为类型定义元文件（meta file）。元文件只包含类型声明，不包含实际可执行代码，通常用于为第三方库提供类型定义。

```lua
---@meta
```

**示例：**

```lua
--- lua-protobuf 库的 EmmyLua 类型定义
---@meta

---@class pb
local pb = {}

---@param data string
---@return boolean success, integer bytes_read
function pb.load(data) end
```

### 访问修饰符

控制字段或函数的可见性，用于代码提示和类型检查的访问控制。

| 修饰符 | 说明 |
| ------ | ---- |
| `@public` | 公开访问（默认） |
| `@private` | 仅当前类内部可访问 |
| `@protected` | 当前类及子类可访问 |
| `@package` | 同包/同模块内可访问 |

**示例：**

```lua
---@class BankAccount
---@field public owner string
---@field private balance number
---@field protected transaction_log table

---@private
function BankAccount:logTransaction(amount) end
```

---

## 类型语法

### 联合类型

一个值可以是多种类型之一：

```lua
---@param value string | number
---@return Car | Ship
```

### 数组类型

```lua
---@param names string[]
---@return number[]
```

### 字典/映射类型

```lua
---@param players table<string, Player>
---@field config table<string, any>
```

### 函数类型

```lua
---@param callback fun(name: string): boolean
---@field comparator fun(a: number, b: number): number
```

### 可选类型

在文档中用 `[value]` 表示可选值；在类型注解中，函数参数的可选性通过 `@overload` 或联合 `nil` 来表示：

```lua
---@param filename string?
---@overload fun(): string
---@overload fun(filename: string): string
function io_module.read(filename) end
```

### 字面量类型

使用具体的字面量作为类型：

```lua
---@param kind "map" | "enum" | "message"
---@return "packed" | "repeated" | "optional"
```

---

## 完整示例

```lua
---@class Transport @Base transport class
---@field public name string
local Transport = {}

function Transport:move() end

---@class Car : Transport
---@field public horsepower number
local Car = {}

---@param typeId number
---@return Car | Ship
local function createVehicle(typeId)
    ---@type Car
    return { name = "Speedster", horsepower = 250 }
end
```

---

## 在 proto_tools 中的使用

本项目广泛使用 EmmyLua 注解来提升代码的可维护性和 IDE 支持，主要体现在以下两个方面：

### 1. 第三方库类型定义（`lua_metas/`）

项目为依赖的 C 库和 protobuf 描述符提供了 EmmyLua 元文件，包括：

- **C 库类型封装** — 使用 `@class`、`@overload` 等注解为 `lua-protobuf` 等 C 库的模块、函数及 userdata 类型提供类型签名。
- **Protobuf 描述符映射** — 将 `google.protobuf.descriptor.proto` 中定义的消息类型和枚举映射为 Lua 类型，使解码后的表具备类型推断和字段补全能力。

### 2. 项目内部代码（`lua_lib/`）

核心库各模块均使用 EmmyLua 注解提升可维护性：

- **内部数据结构** — 使用 `@class` 定义描述符、消息、字段、枚举等模型类型，配合 `@package` 控制可见范围。
- **函数签名** — 使用 `@param`、`@return` 为构建函数、生成函数、参数解析函数等提供完整类型签名。
- **类型引用** — 模块间通过类型注解建立引用关系，确保 IDE 能正确追踪跨模块的类型依赖。

### 3. 配置支持（`.luarc.json`）

项目根目录的 `.luarc.json` 配置了 EmmyLua 类型检查，IDE 会自动识别 `lua_metas/` 目录下的 `.lua` 文件作为全局类型定义，从而为项目代码和第三方库调用提供智能补全和静态类型检查。

---
