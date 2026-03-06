---
name: moonbit-extract-spec-test
description: 从现有的 MoonBit 实现中提取正式规范和完整的测试套件。适用于“从实现中提取规范”、“从代码生成测试”或“为现有包创建规范驱动的测试”等情况。分析现有代码，生成包含 `declare` 关键字存根的 spec.mbt 文件以及组织有序的测试文件（有效/无效）。
---

# MoonBit 提取规范与测试

## 概述
从现有的 MoonBit 实现中反向工程化生成正式的 API 契约（`<pkg>_spec.mbt`）和全面的测试套件。这能够为已编写的代码启用基于规范的测试。

## 适用场景
- 用户要求“从现有实现中提取规范”
- 用户希望“为某个包生成基于规范的测试”
- 用户请求“从代码创建正式的 API 规范”
- 将遗留代码转换为基于规范的开发工作流
- 需要记录并测试现有的公共 API 接口

## 工作流程

### 1. 分析现有实现

**识别公共 API 接口：**
- 列出所有 `pub` 和 `pub(all)` 类型、函数、特征
- 记录错误类型（子错误）及其变体
- 记录方法签名和特征实现
- 识别关键入口点和核心功能

**检查测试模式（若存在测试）：**
- 查找现有的测试文件（`*_test.mbt`、`*_wbtest.mbt`）
- 识别测试覆盖缺口
- 记录常见的测试场景

### 2. 生成规范文件（`<pkg>_spec.mbt`）

**创建正式的 API 契约：**
- 对所有公共函数/类型使用 `declare` 关键字
- 保留实现中完全一致的类型签名
- 包含带有 `derive(Show, Eq, ToJson)` 的错误类型以支持可测试性
- 从原始代码中保留文档注释
- 使用 `declare` 声明的内容无需编写函数体
- 对测试中需要构造的类型使用 `pub(all)`
- 对不透明类型使用 `pub`

**规范文件结构示例：**
```mbt
///|
/// 解析操作的错误类型
pub(all) suberror ParseError {
  InvalidFormat(String)
  UnexpectedEof
} derive(Show, Eq, ToJson)

///|
/// 主要数据类型
declare pub(all) type Toml

///|
/// 转换为测试用 JSON 格式
declare pub fn Toml::to_test_json(self : Toml) -> Json

///|
/// 从字符串解析 TOML
declare pub fn parse(input : StringView) -> Result[Toml, ParseError]
```

### 3. 提取并整理测试用例

**按有效性分类测试（正常流程 vs 异常流程）：**

**有效测试**（`<pkg>_valid_test.mbt`）：
- 正常流程：能覆盖核心功能的有效输入
- 边界情况：边界大小、空输入、最大嵌套层级
- 兼容性：与真实世界数据或主流实现行为一致的场景
- 回归测试：针对先前修复的 bug 或已知陷阱的测试

**无效测试**（`<pkg>_invalid_test.mbt`）：
- 异常流程：无效输入及预期的错误行为
- 歧义场景：规范允许多种解释的输入（测试用于确定选定的解释）
- 格式错误的输入：语法错误、类型不匹配、约束违规

### 4. 编写基于规范的测试

**有效输入测试示例：**
```mbt
///|
test "valid/category/test-name" {
  let toml_text =
    #|key = "value"
    #|
  let toml = match @pkg.parse(toml_text) {
    Ok(toml) => toml
    Err(error) => fail("解析失败: " + error.to_string())
  }
  json_inspect(toml.to_test_json(), content={
    "key": { "type": "string", "value": "value" }
  })
}
```

**无效输入测试示例：**
```mbt
///|
test "invalid/category/test-name" {
  let toml_text =
    #|invalid syntax here
    #|
  match @pkg.parse(toml_text) {
    Ok(toml) => {
      let json = toml.to_test_json()
      fail("预期解析失败，但得到 \{json.stringify(indent=2)}")
    }
    Err(_) => ()
  }
}
```

### 5. 验证

**类型检查规范：**
```bash
moon check
```

**运行测试：**
```bash
moon test          # 运行所有测试
moon test -u       # 更新快照测试
```

**验证覆盖率：**
- 确保所有公共 API 函数都有对应的测试
- 检查是否有未测试的错误分支
- 确认边界情况已覆盖

## 核心原则

### 规范文件规则
1. **仅声明存根**：所有公共 API 使用 `declare` 关键字（无需函数体）
2. **精确签名**：与实现的类型签名完全匹配
3. **错误处理**：包含所有错误类型并添加适当的 derive 宏
4. **文档说明**：保留或补充文档注释以提升可读性
5. **测试辅助函数**：包含如 `to_test_json()` 之类的转换函数用于检查

### 测试组织规则
1. **黑盒测试**：测试仅使用公共 API（通过 `@pkg.function` 调用）
2. **快照测试**：对于复杂值优先使用 `json_inspect()`
3. **清晰命名**：使用描述性的测试名称，如 "valid/arrays/nested" 或 "invalid/keys/empty"
4. **分类管理**：按有效性分类（`<pkg>_valid_test.mbt` 用于正常流程，`<pkg>_invalid_test.mbt` 用于异常流程）
5. **块分隔**：使用 `///|` 分隔测试块

### 测试覆盖率目标
- **正向用例**：有效输入产生预期输出
- **反向用例**：无效输入产生相应的错误
- **边界用例**：边界值、空输入、特殊值
- **集成测试**：验证功能间协同工作
- **目标覆盖率**：API 覆盖率达到 80-90%

## 提取示例

### 从实现代码提取
```mbt
pub type Config

pub fn Config::parse(text : String) -> Result[Config, String] {
  // 实现逻辑
}

pub fn Config::get_value(self : Config, key : String) -> String? {
  // 实现逻辑
}
```

### 生成规范文件
```mbt
///|
declare pub type Config

///|
declare pub fn Config::parse(text : String) -> Result[Config, String]

///|
declare pub fn Config::get_value(self : Config, key : String) -> String?
```

### 生成测试文件
```mbt
///|
test "parse valid config" {
  let result = try? Config::parse("key=value")
  match result {
    Ok(cfg) => {
      inspect(cfg.get_value("key"), content="Some(\"value\")")
    }
    Err(e) => fail("解析失败: \{e}")
  }
}

///|
test "parse invalid config returns error" {
  let result = try? Config::parse("invalid")
  match result {
    Ok(_) => fail("解析本应失败但未失败")
    Err(_) => ()
  }
}
```

## 提示

- **从简入手**：先实现核心功能的规范和测试，再逐步增加复杂度
- **复用现有测试**：若已有测试，迁移并增强这些测试
- **迭代开发**：频繁运行 `moon check` 及早发现类型错误
- **更新快照**：当输出格式变化时使用 `moon test -u`
- **记录设计思路**：为非显而易见的测试用例添加注释说明原因

## 通用模式

### 测试 Result 类型
```mbt
let result : Result[T, Error] = try? function_call(...)
match result {
  Ok(value) => inspect(value, content="...")
  Err(e) => fail("意外错误: \{e}")
}
```

### 测试预期失败的场景
```mbt
match try? function_call(...) {
  Ok(v) => fail("预期出错，但得到 \{v}")
  Err(_) => ()  // 成功 - 预期的错误已触发
}
```

### 使用测试用 JSON 格式
```mbt
json_inspect(value.to_test_json(), content={
  "field": { "type": "integer", "value": "42" }
})
```
