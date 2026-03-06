---
name: moonbit-spec-test-development
description: 基于规范驱动的方式创建正式的 MoonBit API 及测试套件。当被要求搭建 spec.mbt 文件、规范驱动的测试，或采用“契约优先”的标准化工作流程时（例如：“为 MoonBit 中的 Yaml 搭建一套正式的规范和测试套件”），需包含 moon.mod.json/moon.pkg.json 的脚手架搭建，以及指导在独立文件中完成实现的相关内容。
---

# MoonBit 规范与测试开发

## 概述
在 `<pkg>_spec.mbt` 文件中定义正式的 API 契约，基于该契约编写类型校验的测试，并搭建最小化的 MoonBit 模块，确保在开始实现工作前 `moon check` 命令能执行通过。

## 工作流程

### 确认 API 接口范围（如有需要）
- 从上下文信息中推导包名；仅当信息不明确时才询问用户。
- 确认 API 接口范围：核心类型、入口点、错误类型，以及任何版本控制需求。

### 使用 `moon new` 搭建模块（新项目优先推荐）
- 若未使用 `moon new` 命令，则退而使用 `moon.mod.json` 和 `moon.pkg.json` 模板。

### 编写正式规范（`<pkg>_spec.mbt`）
- 为所有后续待实现的类型/函数添加 `#declaration_only` 标识。
- 带有 `#declaration_only` 标识的函数仍需包含函数体：`{ ... }`。
- 将规范作为契约对待：创建后视为只读文件；实现代码需放在同一包下的新文件中。
- 对于需要在测试中构造的类型，使用 `pub(all)` 修饰；对于不透明类型，保留 `pub` 修饰。

### 编写规范驱动的测试
- 在同一包下创建 `<pkg>_easy_test.mbt`、`<pkg>_mid_test.mbt` 和 `<pkg>_difficult_test.mbt`（或类似命名）的测试文件。
- 优先使用公共 API 编写黑盒测试；对于复杂值，使用 `@json.inspect(...)` 辅助校验。
- 尽可能让测试覆盖足够多的场景，以验证规范定义的接口范围。

### 验证
- 运行 `moon check` 命令，确认规范和测试通过类型校验。
- 仅当部分实现代码完成后，再运行 `moon test` 命令执行测试。

## 模板
- 可参考 `references/templates.md` 获取脚手架和文件模板。
