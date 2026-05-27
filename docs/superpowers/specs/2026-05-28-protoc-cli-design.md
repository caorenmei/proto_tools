# protoc CLI 设计

## 背景

需要基于 `lua-protobuf` 提供一个最小可用的 `protoc` 风格命令行工具，用于把一个或多个 `.proto` 文件编译为 descriptor set 输出文件。当前范围严格限定为：

- 入口文件为 `tools/protoc_cli.lua`
- 代码放在 `src/protoc_cli/`
- 支持 `--proto_path`
- 支持 `--descriptor_set_out`
- 支持一个或多个位置参数形式的 `.proto` 输入文件
- 测试目标为 **proto3 全特性**，且不能遗漏 `service` 与 `option`

不在本次范围内的内容：

- 安装为全局命令或 `luarocks` 可执行脚本
- proto2 语义覆盖
- 兼容官方 `protoc` 的全部参数矩阵

## 设计目标

1. 提供与 `protoc` 相似的最小调用方式，便于直接替换基础编译场景。
2. 将 CLI 行为与编译逻辑解耦，保证核心能力可以脱离命令行独立测试。
3. 让 import 搜索、descriptor 输出和错误传播行为稳定且可预期。
4. 通过真实 fixture 验证生成的 descriptor set 不只是“能生成”，而且“能被 `pb` 正确加载和使用”。

## 模块划分

### `tools/protoc_cli.lua`

命令行入口。负责：

- 调用参数解析模块
- 调用编译协调模块
- 调用 descriptor 写出模块
- 将错误打印到 stderr
- 设置退出码

该文件不承载编译细节，避免入口文件演化为巨石。

### `src/protoc_cli/args.lua`

负责解析并标准化命令行参数：

- 收集一个或多个 `--proto_path`
- 读取 `--descriptor_set_out`
- 收集位置参数形式的输入 `.proto` 文件
- 对缺参或非法参数生成明确错误

输出统一配置表，供后续模块消费。

### `src/protoc_cli/path_search.lua`

负责文件定位与 import 搜索：

- 按 `--proto_path` 顺序搜索输入文件
- 按相同规则处理 import 目标
- 统一返回解析后的绝对路径、逻辑 proto 名称和文件内容来源
- 当文件缺失时生成包含目标名和搜索路径的错误

该模块不做编译，只负责把“用户给的路径”转成“编译器可消费的输入”。

### `src/protoc_cli/compiler.lua`

负责驱动 `lua-protobuf` 的 `protoc` 编译器：

- 创建编译器实例
- 配置 import 解析回调或等价机制，使其能通过 `path_search` 解析依赖
- 逐个编译位置参数指定的目标文件
- 汇总最终 `FileDescriptorSet` 二进制结果

该模块是实现核心，重点保证多文件输入和 import 图下的行为稳定。

### `src/protoc_cli/write_descriptor.lua`

负责把最终生成的 descriptor set 写入 `--descriptor_set_out` 指定位置：

- 以二进制方式写出
- 对打开失败、写入失败、关闭失败等情况保留原始错误上下文

## 数据流

整体数据流如下：

1. `tools/protoc_cli.lua` 读取 argv。
2. `args.lua` 产出标准化配置。
3. `path_search.lua` 建立输入文件与 import 搜索规则。
4. `compiler.lua` 创建并驱动 `protoc` 编译器，生成 descriptor set。
5. `write_descriptor.lua` 将 descriptor set 写出到目标文件。
6. CLI 以 0 / 非 0 退出码结束。

测试会同时覆盖两条路径：

- 直接调用 `compiler.lua`，验证核心编译逻辑
- 调用 `tools/protoc_cli.lua`，验证最终命令行行为

## 错误处理

本工具采用显式失败策略，不做静默回退：

- 缺少 `--descriptor_set_out`
- 没有输入文件
- 输入文件不存在
- import 文件不存在
- `.proto` 语法错误
- 重复定义或非法引用
- option / service 相关编译错误
- 输出文件无法写入

以上任一情况都应：

- 返回非 0 退出码
- 向 stderr 输出错误
- 保留足够的文件名、参数名或底层错误信息，方便定位

## 测试设计

测试分为两类。

### 1. 编译与描述文件结构测试

准备一组真实 `.proto` fixture，覆盖 proto3 全特性，至少包括：

- `syntax = "proto3"`
- `package`
- 多文件 `import`
- message
- nested message
- enum
- repeated
- map
- oneof
- proto3 optional
- reserved
- service
- 文件级 option
- 消息级 option
- 字段级 option

验证点：

- 能成功生成 descriptor set
- descriptor set 可被 `pb.load()` 正确加载
- 关键类型、字段、枚举和服务信息可被查询到

### 2. 数据可用性测试

选择若干代表性 message：

- 包含标量字段
- 包含 repeated / map / oneof / optional
- 至少跨一个 import 文件

对这些消息执行 encode/decode 往返，验证生成的 descriptor set 可以实际驱动 `pb` 工作，而不是仅仅产出一个形式上存在的二进制文件。

## 目录规划

预计新增内容如下：

- `tools/protoc_cli.lua`
- `src/protoc_cli/args.lua`
- `src/protoc_cli/path_search.lua`
- `src/protoc_cli/compiler.lua`
- `src/protoc_cli/write_descriptor.lua`
- `tests/...` 下的 fixture 与测试文件

## 决策摘要

- 采用“薄 CLI + 可测试核心模块”的结构
- 编译仍以 `lua-protobuf` 的 `protoc` 为核心，而不是自研 descriptor 拼装
- import 搜索统一由独立模块处理
- 以 proto3 全特性为测试边界，不扩展到 proto2
