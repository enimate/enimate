---
name: moonbit-agent-guide
description: 编写、重构和测试 MoonBit 项目的指南。适用于处理 MoonBit 模块/包、组织 MoonBit 文件、使用 moon 工具链（build/check/run/test/doc/ide 等），或遵循 MoonBit 特定的布局、文档和测试规范。
---

# 代理工作流程
为实现快速、可靠的任务执行，请遵循以下顺序：

1. **明确目标和约束**
   - 确认预期行为、非目标项以及兼容性约束（目标后端、公共 API 稳定性、性能限制）。

2. **定位模块/包边界**
   - 找到 `moon.mod.json`（模块根目录标识）和相关的 `moon.pkg`/`moon.pkg.json` 文件（包边界和导入配置）。

3. **编码前先调研 API**
   - 优先使用 `moon ide doc` 命令查询现有函数/类型/方法，再考虑新增代码。
   - 使用 `moon ide outline`、`moon ide peek-def` 和 `moon ide find-references` 进行语义化导航。

4. **可靠重构**
   - 使用 `moon ide rename` 进行语义化重命名。若多个符号重名，补充 `--loc 文件名:行号:列号` 参数。
   - 当旧 API 需给出警告并在迁移后移除时，使用 `#deprecated` 标记。
   - 迁移期间需临时向后兼容时，使用 `#alias(old_api, deprecated)`。
   - 待所有调用方完成迁移且警告消除后，移除 `#deprecated` 和 `#alias` 兼容层。

5. **最小化编辑且仅限包内修改**
   - 保持修改在对应包内，使用 `///|` 顶级分隔符，将代码拆分为内聚的文件。

6. **快速循环验证**
   - 编辑后运行 `moon check`。
   - 使用 `moon test [目录名|文件名] --filter '通配符'` 执行定向测试，快照变更时使用 `moon test --update`。

7. **交付前最终确认**
   - 运行 `moon fmt` 格式化代码。
   - 运行 `moon info` 验证公共 API 是否变更（对比 `pkg.generated.mbti` 差异）。
   - 报告变更文件、验证命令及剩余风险点。


## 快速任务执行手册
选择与需求匹配的最小化执行手册：

### Bug 修复（不计划变更 API）
1. 复现或定位失效行为。
2. 使用 `moon ide outline`、`moon ide peek-def`、`moon ide find-references` 定位符号。
3. 在当前包内实现最小化修复。
4. 验证步骤：
   - `moon check`
   - `moon test [目录名|文件名] --filter '通配符'`（或最接近的定向测试范围）
   - `moon fmt`
   - `moon info`（确认 `pkg.generated.mbti` 无变更）

### 重构（保留原有行为）
1. 先确认行为/API 不变量。
2. 优先使用语义化重命名/导航工具：
   - `moon ide rename`
   - `moon ide find-references`
   - `moon ide peek-def`
   - 若多个符号重名，使用 `moon ide rename <符号名> <新名称> --loc 文件名:行号:列号`。
3. 保持修改仅限包内，聚焦文件组织层面调整。
4. 验证步骤：
   - `moon check`
   - `moon test [目录名|文件名]`
   - `moon fmt`
   - `moon info`（除非明确要求，否则 API 应保持不变）

### 新功能或公共 API 开发
1. 先通过 `moon ide doc` 调研现有编程范式，再引入新命名。
2. 按内聚性拆分文件，使用 `///|` 分隔符组织实现代码。
3. 为公共 API 添加/扩展黑盒测试和文档字符串示例。
4. 验证步骤：
   - `moon check`
   - `moon test [目录名|文件名]`（需更新快照时使用 `--update`）
   - `moon fmt`
   - `moon info`（审核并保留预期的 `pkg.generated.mbti` 变更）


# MoonBit 项目布局
MoonBit 源代码文件使用 `.mbt` 扩展名，接口文件使用 `.mbti` 扩展名。
MoonBit 项目根目录下有一个 `moon.mod.json` 文件，用于指定项目的元数据。
项目可包含多个包，每个包都有自己的 `moon.pkg` 或 `moon.pkg.json`（兼容模式）。
子目录也可能包含 `moon.mod.json` 文件，表示该子目录可使用独立的依赖集。

## 示例布局
```
my_module
├── moon.mod.json             # 模块元数据，source 字段（可选）指定模块的源码目录
├── moon.pkg             # 包元数据（每个目录对应一个包，类似 Go 语言）
├── README.mbt.md             # 包含可测试代码块的 Markdown 文件（`test "..." { ... }`）
├── README.md -> README.mbt.md # 软链接到 README.mbt.md
├── cmd                       # 命令行工具目录
│   └── main
│       ├── main.mbt
│       └── moon.pkg     # 可执行包，包含 `options("is-main": true)` 配置
├── liba/                     # 库包
│   └── moon.pkg         # 其他包通过 `@username/my_module/liba` 引用
│   └── libb/                 # 嵌套库包
│       └── moon.pkg     # 其他包通过 `@username/my_module/liba/libb` 引用
├── user_pkg.mbt              # 根包，其他包通过 `@username/my_module` 引用
├── user_pkg_wbtest.mbt       # 白盒测试文件（仅测试内部私有成员时需要，类似 Go 的包内测试）
└── user_pkg_test.mbt         # 黑盒测试文件
└── ...                       # 更多包文件，符号对当前包可见（类似 Go 语言）
```

- **模块（Module）**：由项目根目录下的 `moon.mod.json` 文件标识。
  MoonBit 模块类似 Go 模块，是子目录中多个包的集合，通常对应一个代码仓库或项目。
  模块边界影响依赖管理和导入路径。

- **包（Package）**：由每个目录下的 `moon.pkg`（或 `moon.pkg.json`）文件标识。
  `moon` 所有子命令仍在模块目录（`moon.mod.json` 所在目录）执行，而非当前包目录。
  MoonBit 包是实际的编译单元（类似 Go 包）。
  同一包内的所有源码文件会被拼接为一个单元，因此包内所有定义可相互引用。
  包名由 `moon.mod.json` 中的 `name` 字段 + 包源码目录的相对路径组成，与文件名无关。
  导入时仅引用「模块+包路径」，**绝不**引用文件名。

- **文件（Files）**：
  `.mbt` 文件仅作为包内的一段源码。
  文件名不定义模块、包或命名空间。
  可自由地在同一包内的不同文件间拆分/合并/移动声明。
  包内任意声明均可引用同包内其他所有声明，与所在文件无关。


## 必须遵循的编码/布局规则
1. 优先使用多个小而内聚的文件，而非单个大文件。
   - 将相关类型和函数归类到聚焦的文件中（如 http_client.mbt、router.mbt）。
   - 若文件过大或职责不清晰，新建文件并将相关声明迁移进去。

2. 可自由在同一包内的文件间移动声明。
   - 每个代码块用 `///|` 分隔。只要函数/结构体/ trait 的名称和公有性不变，在文件间移动不会改变语义，代码块的顺序也无关紧要。
   - 在包内拆分/合并文件是安全的重构方式。

3. 文件名仅用于组织管理。
   - 不要假设文件名定义模块，也不要在类型路径中使用文件名。
   - 文件名应描述功能或职责，而非严格映射类型名。

4. 添加新代码时：
   - 优先添加到功能匹配的现有文件中。
   - 若无合适文件，在同包下新建一个描述性命名的文件。
   - 避免创建庞大的「impl」「misc」或「util」文件。

5. 测试相关：
   - 将测试放在对应包内的专用测试文件中（如 `*_test.mbt`）。
     对于普通包（非 `*_test.mbt` 文件），`*.mbt.md` 文件既是 Markdown 文档，也是黑盒测试文件。
     其中的代码块（用三个反引号分隔）若标注 `mbt check`，会被当作测试用例执行，兼具文档和测试双重作用。
     可在 `README.mbt.md` 中编写 `mbt check` 代码示例，也可将 `README.mbt.md` 软链接到 `README.md`，
     以更好地适配 GitHub 展示。
   - 鼓励拆分多个小型测试文件。

6. 接口文件（`pkg.generated.mbti`）：
   `pkg.generated.mbti` 文件是编译器生成的包公共 API 摘要，
   它以简洁的形式展示所有导出的类型、函数和 trait，不含实现细节。
   可通过 `moon info` 生成，便于代码评审。若提交未变更公共 API，`pkg.generated.mbti` 文件内容将保持不变，因此建议在开发完成后将其纳入版本控制。

   关于 IDE 导航和符号查询命令，详见下文「`moon ide` 专用章节」。

# 需避免的常见陷阱
- **不要为变量/函数使用大写命名** → 编译错误
- **可变结构体字段不要遗漏 `mut`** → 默认不可变（注意：数组通常无需 `mut`，除非完全重新赋值变量——例如简单的 push 操作不需要 `mut`）
- **不要忽略错误处理** → 错误必须显式处理
- **不要不必要地使用 `return`** → 最后一个表达式即为返回值
- **不要定义无 Type:: 前缀的方法** → 方法需显式指定类型前缀
- **不要忽略数组边界检查** → 使用 `get()` 进行安全访问
- **调用其他包的函数时不要遗漏 @package 前缀**
- **不要使用 ++ 或 --（不支持）** → 使用 `i = i + 1` 或 `i += 1`
- **不要为抛错函数显式添加 `try`** → 错误会自动传播（与 Swift 不同）
- **兼容语法**：旧代码可能使用 `function_name!(...)` 或 `function_name(...)?`——这些已废弃，应使用普通调用 + `try?` 转换 Result
- **优先使用范围 for 循环而非 C 风格循环** → `for i in 0..<(n-1) {...}` 和 `for j in 0..=6 {...}` 是 MoonBit 更惯用的写法
- **异步（Async）**：MoonBit 无 `await` 关键字，不要添加。调用其他异步函数的函数/测试即为异步。
  只需为函数/测试添加 `async` 前缀即可标识为异步（如 `[pub] async fn ...`、`async test ...`）。

# `moon` 核心命令
## 基础命令
- `moon new my_project` - 创建新项目
- `moon run cmd/main` - 运行主包
- `moon build` - 构建项目（`moon run` 和 `moon build` 均支持 `--target` 参数）
- `moon check` - 仅类型检查不构建，需**频繁使用**，速度快（也支持 `--target`）
- `moon info` - 类型检查并生成 `mbti` 文件，用于查看公共接口是否变更（也支持 `--target`）
- `moon check --target all` - 针对所有后端执行类型检查
- `moon add package` - 添加依赖
- `moon remove package` - 移除依赖
- `moon fmt` - 格式化代码——需定期执行，注意文件可能被重写
注：也可使用 `moon -C 目录 check` 在指定目录执行命令。

### 测试命令
- `moon test` - 运行所有测试（支持 `--target`）
- `moon test --update` - 更新测试快照
- `moon test -v` - 输出详细日志（包含测试名）
- `moon test [目录名|文件名]` - 测试指定目录/文件
- `moon coverage analyze` - 分析测试覆盖率
- `moon test [目录名|文件名] --filter '通配符'` - 运行匹配过滤规则的测试
  ```
  moon test float/float_test.mbt --filter "Float::*"
  moon test float -F "Float::*" // 简写语法
  ```

## `README.mbt.md` 生成指南
- 在包目录下生成 `README.mbt.md`。
  `*.mbt.md` 文件和文档字符串中的 `mbt check` 标记有特殊处理逻辑：
  `mbt check` 代码块会被直接作为代码执行，且会被 `moon check` 和 `moon test` 校验。
  若不希望代码片段被校验，需显式标注 `mbt nocheck`。
  若仅引用当前包内的类型，建议使用 `mbt nocheck`（仅做语法高亮）。
  将 `README.mbt.md` 软链接到 `README.md`，适配期望读取 `README.md` 的系统。

## 测试指南
优先使用快照测试，行为变更时更新快照成本低。

- **快照测试**：`inspect(value, content="...")`。若不确定预期值，先写 `inspect(value)` 并运行 `moon test --update`（或 `moon test -u`）自动生成。
  - 简单值使用普通 `inspect()`（基于 `Show` trait）
  - 复杂嵌套结构使用 `@json.inspect()`（基于 `ToJson` trait，输出更易读）
  - 若函数返回值体积不大，建议对整个返回值执行 `inspect`/`@json.inspect`，简化测试编写。需为自定义类型实现 `impl (Show|ToJson) for YourType` 或 `derive (Show, ToJson)`。
- **更新流程**：代码变更影响输出后，运行 `moon test --update` 重新生成快照，然后评审测试文件中的差异（`content=` 参数会自动更新）。
- **验证顺序**：遵循「代理工作流程」和「快速任务执行手册」中的标准流程。

- 默认使用黑盒测试：仅通过 `@package.fn` 调用公共 API。仅当需测试私有成员时使用白盒测试。
- 分组原则：将相关检查合并到一个 `test "..." { ... }` 块中，提升速度和可读性。
- 恐慌测试：测试名以 `test "panic ..."` 开头；若调用返回值，用 `ignore(...)` 包裹以消除警告。
- 错误测试：函数可能抛错时，使用 `try? f()` 获取 `Result[...]` 并执行 `inspect`。

### 文档字符串测试
公共 API 建议添加文档字符串测试：
````mbt check
///|
/// 获取非空 `Array` 的最大元素。
///
/// # 示例
/// ```mbt check
/// test {
///   inspect(sum_array([1, 2, 3, 4, 5, 6]), content="21")
/// }
/// ```
///
/// # 恐慌场景
/// 若 `xs` 为空则触发恐慌。
pub fn sum_array(xs : Array[Int]) -> Int {
  xs.fold(init=0, (a, b) => a + b)
}
````
文档字符串中的 MoonBit 代码会被自动类型检查和测试（通过 `moon test --update`）。
文档字符串中的 `mbt check` 块仅允许包含 `test` 或 `async test`。

## 规范驱动开发（Spec-driven Development）
- 规范可编写在只读的 `spec.mbt` 文件中（文件名是约定而非强制），其中存根代码标注为声明：

```mbt check
///|
declare pub type Yaml

///|
declare pub fn Yaml::to_string(y : Yaml) -> String raise

///|
declare pub impl Eq for Yaml

///|
declare pub fn parse_yaml(s : String) -> Yaml raise
```

- 添加 `spec_easy_test.mbt`、`spec_difficult_test.mbt` 等文件测试规范中定义的函数；所有代码都会被类型检查（`moon check`）。
- AI 或开发者可在不同文件中实现 `declare` 声明的函数（得益于包组织方式）。
- 运行 `moon test` 验证所有实现是否符合规范。

- `declare` 支持函数、方法和类型的声明。
- `pub type Yaml` 是一个显式的抽象占位符，实现者可自行选择其底层表示。
- 注意：规范文件也可包含普通代码，不局限于声明。

## `moon ide [doc|peek-def|outline|find-references|hover|rename]`：代码导航与重构
针对项目内符号和导航，推荐使用：
- `moon ide doc <查询语句>`：发现 MoonBit 中可用的 API、函数、类型和方法。探索可用 API 时，**优先使用**该命令——它比 `grep_search` 或任何基于正则的搜索工具更强大、准确。
- `moon ide outline .`：扫描当前包的符号概览。
- `moon ide find-references <符号名>`：定位符号的所有引用位置。
- `moon ide peek-def`：查看符号的内联定义上下文，定位顶级符号。
- `moon ide hover 符号名 --loc 文件名:行号:列号`：获取指定位置的类型信息。
- `moon ide rename <符号名> <新名称> [--loc 文件名:行号:列号]`：全项目重命名符号。符号名歧义时，优先使用 `--loc` 参数。
这些工具更节省时间，且比 grep 更精准（grep 会同时显示定义、调用点甚至注释中的匹配结果）。

### `moon ide doc`：API 探索
`moon ide doc` 使用专为符号查询设计的语法：
- **空查询**：`moon ide doc ''`
  - 模块内执行：显示当前模块的所有可用包（含依赖和 moonbitlang/core）
  - 包内执行：显示当前包的所有符号
  - 包外执行：显示所有可用包

- **函数/值查询**：`moon ide doc "[@包名.]值或函数名"`

- **类型查询**：`moon ide doc "[@包名.]类型名"`（内置类型无需包前缀）

- **方法/字段查询**：`moon ide doc "[@包名.]类型名::方法或字段名"`

- **包探索**：`moon ide doc "@包名"`
  - 展示指定包，并列出其所有导出符号
  - 示例：`moon ide doc "@json"` - 探索整个 `@json` 包
  - 示例：`moon ide doc "@encoding/utf8"` - 探索嵌套包

- **通配符匹配**：使用 `*` 通配符进行部分匹配，例如 `moon ide doc "String::*rev*"` 查找所有名称含「rev」的 String 方法

#### `moon ide doc` 示例
````bash
# 搜索标准库中的 String 方法：
$ moon ide doc "String"

type String

  pub fn String::add(String, String) -> String
  # ... 省略更多方法 ...

$ moon ide doc "@buffer" # 列出 buffer 包的所有符号：
moonbitlang/core/buffer

fn from_array(ArrayView[Byte]) -> Buffer
# ... 省略 ...

$ moon ide doc "@buffer.new" # 列出包中指定函数：
package "moonbitlang/core/buffer"

pub fn new(size_hint? : Int) -> Buffer
  Creates ... 省略 ...


$ moon ide doc "String::*rev*"  # 通配符匹配
package "moonbitlang/core/string"

pub fn String::rev(String) -> String
  Returns ... 省略 ...
  # ... 更多结果

pub fn String::rev_find(String, StringView) -> Int?
  Returns ... 省略 ...
````

**最佳实践**：将本节作为命令参考；执行顺序遵循「代理工作流程」。

### `moon ide rename 符号名 新名称 [--loc 文件名:行号:列号]` 示例
用户提问：「能否将函数 `compute_sum` 重命名为 `calculate_sum`？」

```
$ moon ide rename compute_sum calculate_sum --loc math_utils.mbt:2

*** Begin Patch
*** Update File: cmd/main/main.mbt
@@
 ///|
 fn main {
-  println(@math_utils.compute_sum(1, 2))
+  println(@math_utils.calculate_sum(1, 2))
 }
*** Update File: math_utils.mbt
@@
 ///|
-pub fn compute_sum(a: Int, b: Int) -> Int {
+pub fn calculate_sum(a: Int, b: Int) -> Int {
   a + b
 }
*** Update File: math_utils_test.mbt
@@
 ///|
 test {
-  inspect(@math_utils.compute_sum(1, 2))
+  inspect(@math_utils.calculate_sum(1, 2))
 }
*** End Patch
```

### `moon ide hover 符号名 --loc 文件名:行号:列号` 示例
用户提问：「hover.mbt 文件第14行的 `filter` 函数签名和文档字符串是什么？」

```
$ moon ide hover  filter --loc hover.mbt:14
test {
  let a: Array[Int] = [1]
  inspect(a.filter((x) => {x > 1}))
            ^^^^^^
            ```moonbit
            fn[T] Array::filter(self : Array[T], f : (T) -> Bool raise?) -> Array[T] raise?
            ```
            ---

             Creates a new array containing all elements from the input array that satisfy
             ... 省略 ...
}
```

### `moon ide peek-def 符号名 [--loc 文件名:行号:列号]` 示例
用户提问：「能否检查 `Parser::read_u32_leb128` 的实现是否正确？」
可运行 `moon ide peek-def Parser::read_u32_leb128` 获取定义上下文
（比 grep 更优，因为它基于语义搜索整个项目）：

``` file src/parse.mbt
L45:|///|
L46:|fn Parser::read_u32_leb128(self : Parser) -> UInt raise ParseError {
L47:|  ...
...:| }
```

若想查看 `Parser` 结构体的定义，可运行：

```bash
$ moon ide peek-def Parser --loc src/parse.mbt:46:4
Definition found at file src/parse.mbt
  | ///|
2 | priv struct Parser {
  |             ^^^^^^
  |   bytes : Bytes
  |   mut pos : Int
  | }
  |
```

`--loc` 参数中，行号必须精准，列号可近似（因为位置参数 `Parser` 会辅助定位）。

若符号是顶级符号，可省略位置参数：

````bash
$ moon ide peek-def String::rev
Found 1 symbols matching 'String::rev':

`pub fn String::rev` in package moonbitlang/core/builtin at /Users/usrname/.moon/lib/core/builtin/string_methods.mbt:1039-1044
1039 | ///|
     | /// Returns a new string with the characters in reverse order. It respects
     | /// Unicode characters and surrogate pairs but not grapheme clusters.
     | pub fn String::rev(self : String) -> String {
     |   self[:].rev()
     | }
````

### `moon ide outline [目录|文件]` 和 `moon ide find-references <符号名>`：包符号管理
使用 `moon ide outline` 扫描包/文件的顶级符号，无需 grep 即可定位引用：

- `moon ide outline 目录`：列出当前包目录的符号概览（按文件分组）
- `moon ide outline parser.mbt`：列出单个文件的符号
  适用于快速了解包的内容，或在跳转定义前找到目标文件。
- `moon ide find-references TranslationUnit`：查找当前模块中该符号的所有引用

```bash
$ moon ide outline .
spec.mbt:
 L003 | pub(all) enum CStandard {
        ...
 L013 | pub(all) struct Position {
        ...
```

```bash
$ moon ide find-references TranslationUnit
```

## 包管理
### 添加依赖
```sh
moon add moonbitlang/x        # 添加最新版本
moon add moonbitlang/x@0.4.6  # 添加指定版本
```

### 更新依赖
```sh
moon update                   # 更新包索引
```

### 典型模块配置（`moon.mod.json`）
```json
{
  "name": "username/hello", // 发布模块的必填格式
  "version": "0.1.0",
  "source": ".", // 源码目录（可选，默认："."）
  "repository": "", // Git 仓库地址
  "keywords": [], // 搜索关键词
  "description": "...", // 模块描述
  "deps": {
    // 来自 mooncakes.io 的依赖，使用 `moon add` 添加
    "moonbitlang/x": "0.4.6"
  }
}
```

### 典型包配置（`moon.pkg`）
简洁版 moon.pkg：
```
import {
  "username/hello/liba",
  "moonbitlang/x/encoding" @libb
}
import {...} for "test"
import {...} for "wbtest"
options("is-main" : true) // 其他配置项
```
或兼容模式 moon.pkg.json：
```json
{
  "is_main": true,                 // 为 true 时生成可执行文件
  "import": [                      // 包依赖
    "username/hello/liba",         // 简单导入，使用 @liba.foo() 调用函数
    {
      "path": "moonbitlang/x/encoding",
      "alias": "libb"              // 自定义别名，使用 @libb.encode() 调用函数
    }
  ],
  "test-import": [...],            // 黑盒测试专用导入，用法同 import
  "wbtest-import": [...]           // 白盒测试专用导入，用法同 import（极少使用）
}
```

每个目录对应一个包，无 `moon.pkg`/`moon.pkg.json` 文件的目录不被识别为包。

### 包导入（用于 moon.pkg）
- **导入格式**：`"模块名/包路径"`
- **使用方式**：`@别名.函数名()` 调用导入的函数
- **默认别名**：路径最后一段（如 `username/hello/liba` 的默认别名是 `liba`）
- **包引用**：测试文件中使用 `@包名` 引用被测包

**包别名规则**：
- 导入 `"username/hello/liba"` → 使用 `@liba.function()`（默认别名是路径最后一段）
- 自定义别名导入 `import { "moonbitlang/x/encoding" @enc}` → 使用 `@enc.function()`
  （若路径最后一段与别名相同，则无需自定义）
- `_test.mbt` 或 `_wbtest.mbt` 文件中，被测包会被自动导入

示例：
```mbt
///|
/// 在 main.mbt 中（已在 `moon.pkg` 导入 "username/hello/liba"）
fn main {
  println(@liba.hello()) // 调用 liba 包中的 hello() 函数
}
```

### 使用标准库（moonbitlang/core）
**MoonBit 标准库（moonbitlang/core）的包会被自动导入**。MoonBit 正逐步迁移到显式导入——若使用未显式导入的标准库包，会收到警告，提示需将 `moonbitlang/core/strconv` 等添加到 `moon.pkg` 中。
标准库模块无需添加到依赖即可使用。

### 创建包
在当前目录下新建 `fib` 包的步骤：
1. 创建目录：`./fib/`
2. 添加 `./fib/moon.pkg` 文件
3. 添加 `.mbt` 源码文件
4. 在依赖包的 `moon.pkg` 中导入：
   ```
     import {
      "username/hello/fib",
     }
   ```

更多高级主题（如条件编译、链接配置、警告控制、预构建命令）详见 `references/advanced-moonbit-build.md`。

# MoonBit 语言速览
## 核心特性
- **表达式优先**：`if`、`match`、循环均返回值；最后一个表达式即为返回值。
- **默认引用语义**：数组/映射/结构体通过引用可变；基本类型可变需使用 `Ref[T]`。
- **代码块**：使用 `///|` 分隔顶级项。按块生成代码。
  若需在花括号包裹的代码块内留空行，需在空行后添加注释行（可含/不含注释内容）。
- **可见性**：`fn` 默认私有；`pub` 暴露只读/构造权限；`pub(all)` 允许外部构造。
- **命名规范**：值/函数用小写蛇形（lower_snake）；类型/枚举用大驼峰（UpperCamel）；枚举变体以大驼峰开头。
- **包机制**：源码文件中无 `import` 语句；通过 `@别名.函数名` 调用其他包函数。导入配置在 `moon.pkg` 中。
- **占位符**：`...` 是合法的占位符，用于未完成的实现。
- **全局值**：默认不可变，通常需显式类型注解。
- **垃圾回收**：MoonBit 内置 GC，无需生命周期注解，无所有权系统。
  与 Rust 不同（类似 F#）：`let mut` 仅在需重新赋值变量时使用，结构体字段/数组/映射元素可变时无需 `mut`。

## MoonBit 错误处理（受控错误）
MoonBit 使用受控抛错函数，而非未受控异常。所有错误均为 `Error` 的子类型，可通过 `suberror` 声明自定义错误类型。
函数签名中用 `raise` 声明可能抛出的错误类型，错误默认自动传播。
测试中可用 `try?` 转换为 `Result[...]`，或用 `try { } catch { }` 显式处理错误。
使用 `try!` 会在抛错时直接终止程序。

```mbt check
///|
/// 用 'suberror' 声明错误类型
suberror ValueError {
  ValueError(String)
}

///|
/// 存储位置信息的元组结构体
struct Position(Int, Int) derive(ToJson, Show, Eq)

///|
/// ParseError 是 Error 的子类型
pub(all) suberror ParseError {
  InvalidChar(pos~ : Position, Char) // pos 是带标签的字段
  InvalidEof(pos~ : Position)
  InvalidNumber(pos~ : Position, String)
  InvalidIdentEscape(pos~ : Position)
} derive(Eq, ToJson, Show)

///|
/// 函数声明可能抛出的错误类型
fn parse_int(s : String, position~ : Position) -> Int raise ParseError {
  // 'raise' 抛出错误
  if s is "" {
    raise ParseError::InvalidEof(pos=position)
  }
  ... // 解析逻辑
}

///|
/// 仅声明 `raise` 表示可能抛错，但不指定具体错误类型
fn div(x : Int, y : Int) -> Int raise {
  if y is 0 {
    fail("Division by zero")
  }
  x / y
}

///|
test "inspect raise function" {
  let result : Result[Int, Error] = try? div(1, 0)
  guard result is Err(Failure(msg)) && msg.contains("Division by zero") else {
    fail("Expected error")
  }
}

// 三种错误处理方式：

///|
/// 自动传播错误
fn use_parse(position~ : Position) -> Int raise ParseError {
  let x = parse_int("123", position~) // 标签简写（position=position）
  // 错误默认自动传播。
  // 与 Swift 不同：无需为抛错函数添加 `try` 标记；编译器会自动推断。
  // 兼顾错误处理的显式性和简洁性。
  x * 2
}

///|
/// 声明 `raise` 覆盖所有可能的错误，不关心具体类型。
/// 快速原型开发时，仅写 `raise` 是可接受的。
fn use_parse2(position~ : Position) -> Int raise {
  let x = parse_int("123", position~) // 标签简写
  x * 2
}

///|
/// 用 try? 转换为 Result
fn safe_parse(s : String, position~ : Position) -> Result[Int, ParseError] {
  let val1 : Result[_] = try? parse_int(s, position~) // 返回 Result[Int, ParseError]
  // try! 极少使用——抛错时触发恐慌，类似 Rust 的 unwrap()
  // let val2 : Int = try! parse_int(s) // 正常返回 Int，否则崩溃

  // 显式处理的替代写法：
  let val3 = try parse_int(s, position~) catch {
    err => Err(err)
  } noraise { // noraise 块可选——处理成功场景
    v => Ok(v)
  }
  ...
}

///|
/// 用 try-catch 处理错误
fn handle_parse(s : String, position~ : Position) -> Int {
  try parse_int(s, position~) catch {
    ParseError::InvalidEof => {
      println("Parse failed: InvalidEof")
      -1 // 默认值
    }
    _ => 2
  }
}
```

重要：调用可能抛错的函数时，若仅需传播错误，无需添加任何标记；编译器会自动推断。
注意：所有 `async` 函数默认可抛错，无需显式声明。

## 整数、字符（Integers, Char）
MoonBit 支持 `Byte`、`Int16`、`Int`、`UInt16`、`UInt`、`Int64`、`UInt64` 等类型。
类型明确时，字面量支持重载：

```mbt check
///|
test "integer and char literal overloading disambiguation via type in the current context" {
  let a0 = 1 // 默认类型为 Int
  let (int, uint, uint16, int64, byte) : (Int, UInt, UInt16, Int64, Byte) = (
    1, 1, 1, 1, 1,
  )
  assert_eq(int, uint16.to_int())
  let a1 : Int = 'b' // 合法，a5 为对应的 Unicode 值
  let a2 : Char = 'b'

}
```

## 字节（Bytes，不可变）
```mbt check
///|
test "bytes literals overloading and indexing" {
  let b0 : Bytes = b"abcd"
  let b1 : Bytes = "abcd" // 类型明确时，b" 前缀可选
  let b2 : Bytes = [0xff, 0x00, 0x01] // 数组字面量重载
  guard b0 is [b'a', ..] && b0[1] is b'b' else {
    // Bytes 可按 BytesView 模式匹配和索引
    fail("unexpected bytes content")
  }
}
```

## 数组（Array，可调整大小）
```mbt check
///|
test "array literals overloading: disambiguation via type in the current context" {
  let a0 : Array[Int] = [1, 2, 3] // 可调整大小
  let a1 : FixedArray[Int] = [1, 2, 3] // 固定大小
  let a2 : ReadOnlyArray[Int] = [1, 2, 3]
  let a3 : ArrayView[Int] = [1, 2, 3]

}
```

## 字符串（String，不可变 UTF-16）
`s[i]` 返回代码单元（UInt16），`s.get_char(i)` 返回 `Char?`。
MoonBit 支持字符字面量重载，可编写如下代码：

```mbt check
///|
test "string indexing and utf8 encode/decode" {
  let s = "hello world"
  let b0 : UInt16 = s[0]
  guard b0 is ('\n' | 'h' | 'b' | 'a'..='z') && s is [.. "hello", .. rest] else {
    fail("unexpected string content")
  }
  guard rest is " world"  // 无 else 时，条件不满足会崩溃

  // 类型明确的场景下，('\n' : UInt16) 是合法的。

  // 使用 get_char 处理 Option 类型
  let b1 : Char? = s.get_char(0)
  assert_true(b1 is Some('a'..='z'))

  // 重要：变量不能直接用于索引对比
  let eq_char : Char = '='
  // s[0] == eq_char // 编译失败——eq_char 不是字面量，左值是 UInt，右值是 Char
  // 正确写法：s[0] == '=' 或 s.get_char(0) == Some(eq_char)
  let bytes = @utf8.encode("中文") // utf8 编码包在标准库中
  assert_true(bytes is [0xe4, 0xb8, 0xad, 0xe6, 0x96, 0x87])
  let s2 : String = @utf8.decode(bytes) // 将 utf8 字节解码回字符串
  assert_true(s2 is "中文")
  for c in "中文" {
    let _ : Char = c // 按 Unicode 安全迭代
    println("char: \{c}") // 遍历字符
  }
}
```

### 字符串插值 && 字符串构建器（StringBuilder）
MoonBit 使用 `\{}` 进行字符串插值，自定义类型需实现 `Show` trait 才能插值。

```mbt check
///|
test "string interpolation basics" {
  let name : String = "Moon"
  let config = { "cache": 123 }
  let version = 1.0
  println("Hello \{name} v\{version}") // 输出："Hello Moon v1.0"
  // 错误——插值内不允许引号：
  // println("  - Checking if 'cache' section exists: \{config["cache"]}")

  // 正确——先提取到变量：
  let has_key = config["cache"] // 插值内不允许出现 `"`
  println("  - Checking if 'cache' section exists: \{has_key}")
  let sb = StringBuilder::new()
  sb
  ..write_char('[') // dotdot 语法用于命令式方法链
  ..write_view([1, 2, 3].map(x => "\{x}").join(","))
  ..write_char(']')
  inspect(sb.to_string(), content="[1,2,3]")
}
```

`\{}` 内的表达式仅支持**基础表达式**（无引号、换行或嵌套插值）。字符串字面量不允许出现在插值中（会增加词法分析难度）。

### 多行字符串
```mbt check
///|
test "multi-line string literals" {
  let multi_line_string : String =
    #|Hello "world"
    #|World
    #|
  let multi_line_string_with_interp : String =
    $|Line 1 ""
    $|Line 2 \{1+2}
    $|
  // `#|` 内无转义，
  // `$|` 内仅转义 '\{..}`
  assert_eq(multi_line_string, "Hello \"world\"\nWorld\n")
  assert_eq(multi_line_string_with_interp, "Line 1 \"\"\nLine 2 3\n")
}
```

## 映射（Map，可变，保留插入顺序）
```mbt check
///|
test "map literals and common operations" {
  // 映射字面量语法
  let map : Map[String, Int] = { "a": 1, "b": 2, "c": 3 }
  let empty : Map[String, Int] = {} // 空映射（推荐写法）
  let also_empty : Map[String, Int] = Map::new()
  // 从键值对数组创建
  let from_pairs : Map[String, Int] = Map::from_array([("x", 1), ("y", 2)])

  // 设置/更新值
  map["new-key"] = 3
  map["a"] = 10 // 更新已有键

  // 获取值——返回 Option[T]
  guard map is { "new-key": 3, "missing"? : None, .. } else {
    fail("unexpected map contents")
  }

  // 直接访问（键不存在时触发恐慌）
  let value : Int = map["a"] // value = 10

  // 迭代保留插入顺序
  for k, v in map {
    println("\{k}: \{v}") // 输出：a: 10, b: 2, c: 3, new-key: 3
  }

  // 其他常用操作
  map.remove("b")
  guard map is { "a": 10, "c": 3, "new-key": 3, .. } && map.length() == 3 else {
    // "b" 已移除，仅剩 3 个元素
    fail("unexpected map contents after removal")
  }
}
```

## 视图类型（View Types）
**核心概念**：视图类型（`StringView`、`BytesView`、`ArrayView[T]`）是零拷贝、非所有权的只读切片，通过 `[:]` 语法创建。
视图不分配内存，适合传递子序列而无需拷贝数据；接收 `String`/`Bytes`/`Array` 的函数也可接收对应的 `*View` 类型（隐式转换）。

- `String` → `StringView`：`s[:]` / `s[start:end]` / `s[start:]` / `s[:end]`
- `Bytes` → `BytesView`：`b[:]` / `b[start:end]` 等
- `Array[T]`/`FixedArray[T]`/`ReadOnlyArray[T]` → `ArrayView[T]`：`a[:]` / `a[start:end]` 等

**重要**：StringView 切片因 Unicode 安全性略有特殊：
`s[a:b]` 可能在代理对（UTF-16 编码边界情况）处抛错。有两种处理方式：
- 确定边界合法时，使用 `try! s[a:b]`（边界非法时崩溃）
- 让错误传播到调用方，由调用方妥善处理

**视图使用场景**：
- 带剩余模式的模式匹配（`[first, .. rest]`）
- 传递切片给函数，无分配开销
- 避免大序列的不必要拷贝

需要所有权时，通过 `.to_string()` / `.to_bytes()` / `.to_array()` 转换回原类型（可通过 `moon ide doc StringView` 查看更多）。

## 自定义类型（`enum`、`struct`）
```mbt check
///|
enum Tree[T] {
  Leaf(T) // 与 Rust 不同，此处无逗号
  Node(left~ : Tree[T], T, right~ : Tree[T]) // 枚举可使用标签
} derive(Show, ToJson) // 为 Tree 派生 trait

///|
pub fn Tree::sum(tree : Tree[Int]) -> Int {
  match tree {
    Leaf(x) => x
    // 已知 tree 类型时，无需写 Tree::Leaf
    Node(left~, x, right~) => left.sum() + x + right.sum() // 方法通过点语法调用
  }
}

///|
struct Point {
  x : Int
  y : Int
} derive(Show, ToJson) // 为 Point 派生 trait

///|
test "user defined types: enum and struct" {
  @json.inspect(Point::{ x: 10, y: 20 }, content={ "x": 10, "y": 20 })
}
```

## 函数式 `for` 循环


```mbt check
///|
pub fn binary_search(arr : ArrayView[Int], value : Int) -> Result[Int, Int] {
  let len = arr.length()
  // functional for loop:
  // initial state ; [predicate] ; [post-update] {
  // loop body with `continue` to update state
  //} else { // exit block
  // }
  // predicate and post-update are optional
  for i = 0, j = len; i < j; {
    // post-update is omitted, we use `continue` to update state
    let h = i + (j - i) / 2
    if arr[h] < value {
      continue h + 1, j // functional update of loop state
    } else {
      continue i, h // functional update of loop state
    }
  } else { // exit of for loop
    if i < len && arr[i] == value {
      Ok(i)
    } else {
      Err(i)
    }
  } where {
    invariant: 0 <= i && i <= j && j <= len,
    invariant: i == 0 || arr[i - 1] < value,
    invariant: j == len || arr[j] >= value,
    reasoning: (
      #|For a sorted array, the boundary invariants are witnesses:
      #|  - `arr[i-1] < value` implies all arr[0..i) < value (by sortedness)
      #|  - `arr[j] >= value` implies all arr[j..len) >= value (by sortedness)
      #|
      #|Preservation proof:
      #|  - When arr[h] < value: new_i = h+1, and arr[new_i - 1] = arr[h] < value ✓
      #|  - When arr[h] >= value: new_j = h, and arr[new_j] = arr[h] >= value ✓
      #|
      #|Termination: j - i decreases each iteration (h is strictly between i and j)
      #|
      #|Correctness at exit (i == j):
      #|  - By invariants: arr[0..i) < value and arr[i..len) >= value
      #|  - So if value exists, it can only be at index i
      #|  - If arr[i] != value, then value is absent and i is the insertion point
      #|
    ),
  }
}

///|
test "functional for loop control flow" {
  let arr : Array[Int] = [1, 3, 5, 7, 9]
  inspect(binary_search(arr, 5), content="Ok(2)") // Array to ArrayView implicit conversion when passing as arguments
  inspect(binary_search(arr, 6), content="Err(3)")
  // for iteration is supported too
  for i, v in arr {
    println("\{i}: \{v}") // `i` is index, `v` is value
  }
}
```

强烈建议您尽可能使用函数式 `for` 循环，而不是命令式循环，因为函数式循环更易于阅读和理解。

### 使用 `where` 子句实现循环不变式

`where` 子句为函数式 `for` 循环添加**机器可验证的不变式**和**人类可读的推理**。这使得在保持代码可执行性的同时，也能进行形式化验证。注意，对于简单的循环，建议您将其转换为 `for .. in` 循环，这样就不需要推理了。
**Syntax:**
```mbt nocheck
for ... {
  ...
} where {
  invariant : <boolean_expr>,   // checked at runtime in debug builds
  invariant : <boolean_expr>,   // multiple invariants allowed
  reasoning : <string>         // documentation for proof sketch
}
```

**编写优秀的常量：**

1. **使常量可检查**：常量必须是有效的 MoonBit 布尔表达式，使用循环变量和捕获的值。

2. **使用边界见证**：对于范围属性（例如，“arr[0..i] 中的所有元素都满足 P”），仅检查边界元素。对于已排序数组，`arr[i-1] < value` 意味着所有 `arr[0..i] < value`。

3. **使用 `||` 处理边界情况**：使用类似 `i == 0 || arr[i-1] < value` 的模式来处理检查超出范围的边界情况。

4. **推理应涵盖三个方面**：
  - **保持性**：每个 `continue` 语句为何都能保持不变性
  - **终止性**：循环最终为何会终止（例如，递减的度量）
  - **正确性**：终止时的不变性为何能蕴含所需的后置条件

## 带标签的参数和可选参数

一个很好的例子：使用带标签的参数和可选参数

```mbt check
///|
fn g(
  positional : Int,
  required~ : Int,
  optional? : Int, // no default => Option
  optional_with_default? : Int = 42, // default => plain Int
) -> String {
  // These are the inferred types inside the function body.
  let _ : Int = positional
  let _ : Int = required
  let _ : Int? = optional
  let _ : Int = optional_with_default
  "\{positional},\{required},\{optional},\{optional_with_default}"
}

///|
test {
  inspect(g(1, required=2), content="1,2,None,42")
  inspect(g(1, required=2, optional=3), content="1,2,Some(3),42")
  inspect(g(1, required=4, optional_with_default=100), content="1,4,None,100")
}
```

误用：`arg : Type?` 不是可选参数。
调用者仍然必须传递它（作为 `None`/`Some(...)`）。

```mbt check
///|
fn with_config(a : Int?, b : Int?, c : Int) -> String {
  "\{a},\{b},\{c}"
}

///|
test {
  inspect(with_config(None, None, 1), content="None,None,1")
  inspect(with_config(Some(5), Some(5), 1), content="Some(5),Some(5),1")
}
```

反模式：`arg? : Type?`（没有默认值 => 双重 Option）。
如果您想要一个带默认值的可选参数，请写成 `b? : Int = 1`，而不是 `b? : Int? = Some(1)`。

```mbt check
///|
fn f_misuse(a? : Int?, b? : Int = 1) -> Unit {
  let _ : Int?? = a // rarely intended
  let _ : Int = b

}
// How to fix: declare `(a? : Int, b? : Int = 1)` directly.

///|
fn f_correct(a? : Int, b? : Int = 1) -> Unit {
  let _ : Int? = a
  let _ : Int = b

}

///|
test {
  f_misuse(b=3)
  f_misuse(a=Some(5), b=2) // works but confusing
  f_correct(b=2)
  f_correct(a=5)
}
```

错误示例：`arg : APIOptions`（请改用带标签的可选参数）

```mbt check
///|
/// Do not use struct to group options.
struct APIOptions {
  width : Int?
  height : Int?
}

///|
fn not_idiomatic(opts : APIOptions, arg : Int) -> Unit {

}

///|
test {
  // Hard to use in call site
  not_idiomatic({ width: Some(5), height: None }, 10)
  not_idiomatic({ width: None, height: None }, 10)
}
```

## 更多详情

如需了解更深入的语法、类型和示例，请阅读 `references/moonbit-language-fundamentals.mbt.md`。
