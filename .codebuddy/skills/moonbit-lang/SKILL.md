---
name: moonbit-lang
description: MoonBit 语言参考及编码规范。编写 MoonBit 代码、询问语法问题或遇到 MoonBit 特有错误时使用。涵盖错误处理、FFI、异步操作以及常见陷阱。
---

# MoonBit 语言参考

@reference/index.md
@reference/introduction.md
@reference/fundamentals.md
@reference/methods.md
@reference/derive.md
@reference/error-handling.md
@reference/packages.md
@reference/tests.md
@reference/benchmarks.md
@reference/docs.md
@reference/attributes.md
@reference/ffi.md
@reference/async-experimental.md
@reference/error_codes/index.md
@reference/toml-parser-parser.mbt

## 官方包

MoonBit 拥有由核心团队维护的官方包：

- **moonbitlang/x**：工具类库，包含文件 I/O（`moonbitlang/x/fs`）
- **moonbitlang/async**：异步运行时，提供 TCP、HTTP、异步队列、异步测试及异步主函数功能

使用这些包的步骤：
1. 添加依赖：`moon add moonbitlang/x` 或 `moon add moonbitlang/async`
2. 在 `moon.pkg.json` 中导入特定的子包：
   ```json
   {"import": ["moonbitlang/x/fs"]}
   ```

## 常见陷阱

- 错误类型使用 `suberror` 定义，抛出错误用 `raise`，忽略错误使用 `try! func() |> ignore`
- 忽略函数返回值使用 `func() |> ignore`，而非 `let _ = func()`
- 使用 `inspect(value, content=expected_string)` 时，不要单独声明 `let expected = ...` 变量——这会触发未使用变量警告。直接将预期字符串写入 `content=` 参数中
- 取反操作使用 `!condition`，而非 `not(condition)`
- 调用函数使用 `f(value)`，而非 `f!(value)`（该写法已废弃）
- 循环使用 `for i in 0..<n`，而非 C 风格的 `for i = 0; i < n; i = i + 1`
- 单分支匹配使用 `if opt is Pattern(v) { ... }`，而非 `match opt {}`
- 清空数组使用 `arr.clear()`，而非 `while arr.length() > 0 { arr.pop() }`
- 访问字符串字符使用 `s.code_unit_at(i)` 或 `for c in s`，而非 `s[i]`（该写法已废弃）
- 结构体/枚举的可见性等级：`priv`（完全隐藏） < 无修饰符/abstract（仅暴露类型） < `pub`（只读） < `pub(all)`（完全公开）
- 内部类型默认使用 abstract（无修饰符）；外部代码需要读取字段时使用 `pub struct`
- 外部代码需要进行模式匹配的枚举，使用 `pub(all) enum`
- 仅在需要重新赋值时使用 `let mut`，可变容器（如 Array）无需添加
- 无符号运算使用 `reinterpret_as_uint()`，数值转换使用 `to_int()`
- 获取数组长度使用 `Array::length()`，而非 `Array::size()`
- 在 moon.pkg.json 中，分别使用 "import"、"test-import" 和 "wbtest-import" 管理 `.mbt`、`_test.mbt` 和 `_wbtest.mbt` 文件的包导入
- 可选值取值使用 `Option::unwrap_or`，而非 `Option::or`

## 解析器风格参考

编写手写解析器时，遵循 `reference/toml-parser-parser.mbt` 中的风格（同步自 `moonbit-community/toml-parser`）。

- 优先使用 `Parser::parse_*` 方法来推进令牌视图（`view`/`update_view`）
- 集中处理错误上报（例如 `Parser::error`），并包含令牌位置信息
- 保持函数短小（如 `parse_value`、`parse_array` 等），使用 `///|` 分隔代码块
