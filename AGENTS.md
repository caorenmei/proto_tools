# AGENTS.md

## 项目概述

`proto_tools` 是一个基于 Lua 的 protobuf 代码生成工具，从 protobuf DescriptorSet 中解析描述符信息，生成对应的 Lua 代码。

## 目录结构

```
proto_tools/
├── docs/                    # 项目文档
│   ├── books/               # 第三方库中文文档
│   └── specs/               # 功能规格说明
├── lua_lib/                 # 核心库代码，按功能模块划分子目录
├── lua_metas/               # 预留：LuaCATS 类型定义
├── lua_tests/               # 测试代码，测试文件以 `*_spec.lua` 命名
├── lua_tools/               # Lua 工具脚本
├── AGENTS.md                # 项目开发规范
├── CLAUDE.md                # Claude 开发指令
├── proto_tools-dev-1.rockspec
├── .luarc.json
├── lua                      # 便利脚本：Lua REPL
└── luarocks                 # 便利脚本：LuaRocks 本地管理
```

## 开发环境

- **Lua 5.4** — 解释执行，无需编译
- **LuaRocks** — 本地依赖管理（`lua_modules/`），rockspec: `proto_tools-dev-1.rockspec`
- **busted** — 单元测试框架
- **LuaLs** — Lua 语言服务器（`.luarc.json`），提供代码补全、诊断、格式化、类型注释等功能，类型注释参考 @docs/books/luals-annotations.md
- **便利脚本**：`./lua`（带本地路径的 REPL）、`./luarocks`（本地依赖管理）

## 开发工作流

- **Git Worktree**：@git-worktree-manager 使用 `git worktree` 管理多分支并行开发，避免切换分支导致的全量重建。
  - 主工作区保持 `main` 分支。
  - 各 worktree 独立构建，互不干扰。
  - 详细流程（目录路径、命名规范、分支处理、环境文件拷贝等）见 skill。

## 测试环境

- **busted** — 测试框架，测试文件以 `*_spec.lua` 命名
- **目录**：`lua_tests/`，`lua_tests/support/env.lua` 负责环境初始化
- **运行**：`busted lua_tests/`

## 语言规范

- 用户交互、文档、注释：简体中文
- 代码、配置：英文（注释可用中文）
- 技术术语、缩写、约定俗成表达：可保留英文

## 强制交互协议

- **分工**：主 Agent **仅负责**规划与派遣（理解用户意图、拆分子任务、汇总结论并做最终决策）；子 Agent **负责**执行。**严禁**主 Agent 亲自执行任何文件操作、代码探索、需求分析、方案设计等具体工作，**必须**交由子 Agent 完成。
- **原子任务**：复杂任务必须拆分为单一职责的子任务，由独立子 Agent 并行或串行执行。
- **结论优先**：子 Agent 必须返回结构化结论；主 Agent 上下文严禁保留冗余信息，仅保留决策所需的关键信息。
