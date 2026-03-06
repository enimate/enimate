## 使用包管理项目

在进行大规模项目开发时，通常需要将项目拆分为多个相互依赖的较小模块化单元。
多数情况下，这还会涉及使用他人开发的代码：其中最具代表性的是 MoonBit 的标准库——[core](https://github.com/moonbitlang/core)。

### 包与模块

在 MoonBit 中，代码组织的核心单元是包（package），一个包由若干源代码文件和唯一的 `moon.pkg.json` 配置文件组成。
包分为两种类型：一种是包含 `main` 函数的 `main` 包，另一种是作为库使用的包，可通过 [`is-main`](../toolchain/moon/package.md#is-main) 字段标识。

一个项目对应一个模块（module），模块由多个包和唯一的 `moon.mod.json` 配置文件构成。

模块通过 [`name`](../toolchain/moon/module.md#name) 字段标识，其命名通常包含两部分，以 `/` 分隔：`用户名/项目名`。
包则通过相对于 [`source`](../toolchain/moon/module.md#source-directory) 字段定义的源码根目录的路径来标识。包的完整标识符格式为 `用户名/项目名/包的路径`。

当需要使用其他包中的内容时，首先要在 `moon.mod.json` 的 [`deps`](../toolchain/moon/module.md#dependency-management) 字段中声明模块间的依赖关系。
随后，还需在 `moon.pkg.json` 的 [`import`](../toolchain/moon/package.md#import) 字段中声明包之间的依赖关系。

<a id="default-alias"></a>

包的**默认别名**是其标识符按 `/` 分割后的最后一部分。
开发者可通过 `@包别名` 访问导入的实体，这里的“包别名”可以是包的完整标识符，也可以是默认别名。
同时，也可通过 [`import`](../toolchain/moon/package.md#import) 字段自定义别名。

```json
{
    "import": [
        "moonbit-community/language/packages/pkgA",
        {
            "path": "moonbit-community/language/packages/pkgC",
            "alias": "c"
        }
    ]
}
```

```moonbit
///|
pub fn add1(x : Int) -> Int {
  @moonbitlang/core/builtin.Add::add(0, @c.incr(@pkgA.incr(x)))
}
```

#### 内部包

你可以定义仅对特定包可见的内部包。

位于 `a/b/c/internal/x/y/z` 路径下的代码，仅对 `a/b/c` 包及其子包（`a/b/c/**`）可见。

#### Using 语法

可通过 `using` 语法导入其他包中定义的符号。

```moonbit
///|
pub using @pkgA {incr, trait Trait, type Type}
```

添加 `pub` 修饰符后，该操作会被视为重新导出（reexportation）。

### 访问控制

MoonBit 提供了完善的访问控制系统，用于管控代码中哪些部分可被其他包访问。
该系统有助于维护封装性、信息隐藏特性，并清晰界定 API 边界。
可见性修饰符适用于函数、变量、类型和 trait，支持对代码的外部使用方式进行细粒度控制。

#### 函数

默认情况下，所有函数定义和变量绑定对其他包均**不可见**。
可在顶层 `let`/`fn` 前添加 `pub` 修饰符，将其设为公共可见。

#### 别名

默认情况下，[函数别名](fundamentals.md#function-alias) 和
[方法别名](methods.md#alias-methods-as-functions) 会继承
原定义的可见性；而 [类型别名](fundamentals.md#type-alias)、
[trait 别名](methods.md#trait-alias)、`using` 语法定义的内容，对其他包均**不可见**。

可在别名定义前添加 `pub` 修饰符，或在注解的 `visibility` 字段中配置可见性。

#### 类型

MoonBit 中的类型有四种不同的可见性：

- 私有类型（Private type）：使用 `priv` 声明，对外完全不可见。
- 抽象类型（Abstract type）：类型的默认可见性。

  抽象类型仅对外暴露名称，其内部实现细节被隐藏。将抽象类型设为默认值是一项设计选择，旨在鼓励封装和信息隐藏。
- 只读类型（Readonly types）：使用 `pub` 声明。

  只读类型的内部实现对外可见，但外部仅能读取该类型的值，无法构造或修改。
- 完全公共类型（Fully public types）：使用 `pub(all)` 声明。

  外部可自由构造、读取该类型的值，若类型支持修改，也可对其进行修改。

除类型本身的可见性外，公共 `struct` 的字段可添加 `priv` 注解，使其对外完全隐藏。
注意：包含私有字段的 `struct` 无法在外部直接构造，但可通过函数式结构体更新语法修改其公共字段。

只读类型是一项非常实用的特性，灵感源自 OCaml 中的 [私有类型](https://ocaml.org/manual/5.3/privatetypes.html)。
简而言之，`pub` 类型的值可通过模式匹配和点语法解构，但无法在其他包中构造或修改。

##### 注意
在定义 `pub` 类型的同一个包内，不存在上述限制。

<!-- 需人工核对 -->
```moonbit
// 包 A
pub struct RO {
  field: Int
}
test {
  let r = { field: 4 }       // 合法
  let r = { ..r, field: 8 }  // 合法
}

// 包 B
fn println(r : RO) -> Unit {
  println("{ field: ")
  println(r.field)  // 合法
  println(" }")
}
test {
  let r : RO = { field: 4 }  // 错误：无法创建公共只读类型 RO 的值！
  let r = { ..r, field: 8 }  // 错误：无法修改公共只读字段！
}
```

MoonBit 的访问控制遵循一项原则：`pub` 类型、函数或变量，不能基于私有类型定义。
这是因为私有类型可能无法在所有使用该 `pub` 实体的场景中访问。MoonBit 内置了合法性检查，以避免出现违反该原则的使用场景。

<!-- 需人工核对 -->
```moonbit
pub(all) type T1
pub(all) type T2
priv type T3

pub(all) struct S {
  x: T1  // 合法
  y: T2  // 合法
  z: T3  // 错误：公共字段使用了私有类型 `T3`！
}

// 错误：公共函数的参数使用了私有类型 `T3`！
pub fn f1(_x: T3) -> T1 { ... }
// 错误：公共函数的返回值使用了私有类型 `T3`！
pub fn f2(_x: T1) -> T3 { ... }
// 合法
pub fn f3(_x: T1) -> T1 { ... }

pub let a: T3 = { ... } // 错误：公共变量使用了私有类型 `T3`！
```

#### Trait

Trait 的可见性同样分为四种，与 `struct` 和 `enum` 一致：私有、抽象、只读、完全公共。

- 私有 trait：使用 `priv trait` 声明，对外完全不可见。
- 抽象 trait：默认可见性。仅对外暴露 trait 名称，其内部方法不对外公开。
- 只读 trait：使用 `pub trait` 声明，外部可调用其方法，但仅当前包可为该 trait 添加新实现。
- 完全公共 trait：使用 `pub(open) trait` 声明，外部可自由为其添加新实现，且其方法可被任意使用。

抽象 trait 和只读 trait 是“密封”的（sealed），因为仅定义该 trait 的包可实现它。
在定义包外实现密封 trait 会触发编译器错误。

##### Trait 实现

Trait 实现的可见性独立于 trait 本身，与函数的可见性规则一致。
除非实现被标记为 `pub`，否则外部包不会认为该类型实现了对应的 trait。

为保证 trait 系统的一致性（即对于每个 `类型: Trait` 组合，全局仅有唯一实现），
并防止第三方包意外修改已有程序的行为，
MoonBit 对谁可以为类型定义方法/实现 trait 做出了如下限制：

- *仅定义类型的包可为该类型定义方法*。因此，无法为内置类型和外部类型定义新方法或覆盖原有方法。
  - 该规则有一个例外：[本地方法](methods.md#local-method)。但本地方法始终是私有的，因此不会破坏 MoonBit 类型系统的一致性。
- *仅类型所属的包或 trait 所属的包可定义 trait 实现*。
  例如，仅 `@pkg1` 和 `@pkg2` 有权编写 `impl @pkg1.Trait for @pkg2.Type`。

上述第二条规则允许开发者通过定义新 trait 并为外部类型实现该 trait，从而为外部类型添加新功能。
这让 MoonBit 的 trait 和方法系统兼具灵活性与良好的一致性。

##### 注意
目前，空 trait 会被自动实现。

以下是抽象 trait 的示例：

<!-- 需人工核对 -->
```moonbit
trait Number {
 op_add(Self, Self) -> Self
 op_sub(Self, Self) -> Self
}

fn[N : Number] add(x : N, y: N) -> N {
  Number::op_add(x, y)
}

fn[N : Number] sub(x : N, y: N) -> N {
  Number::op_sub(x, y)
}

impl Number for Int with op_add(x, y) { x + y }
impl Number for Int with op_sub(x, y) { x - y }

impl Number for Double with op_add(x, y) { x + y }
impl Number for Double with op_sub(x, y) { x - y }
```

从外部包视角，仅能看到以下内容：

```moonbit
trait Number

fn[N : Number] op_add(x : N, y : N) -> N
fn[N : Number] op_sub(x : N, y : N) -> N

impl Number for Int
impl Number for Double
```

`Number` 的开发者可利用“仅 `Int` 和 `Double` 可实现 `Number`”这一特性（因为外部无法添加新实现），灵活设计逻辑。

### 虚拟包

##### 注意
虚拟包是实验性特性，可能存在 bug 和未定义行为。

可定义虚拟包作为接口使用，其具体实现可在构建时替换。目前，虚拟包仅支持包含普通函数。

虚拟包可用于在不修改代码的前提下切换不同实现，非常实用。

#### 定义虚拟包

需先声明该包为虚拟包，并在 MoonBit 接口文件中定义其接口。

在 `moon.pkg.json` 中，需添加 [`virtual`](../toolchain/moon/package.md#declarations) 字段：

```json
{
  "virtual": {
    "has-default": true
  }
}
```

`has-default` 标识该虚拟包是否有默认实现。

在包内，需添加接口文件 `pkg.mbti`：

```moonbit
package "moonbit-community/language/packages/virtual"

fn log(String) -> Unit
```

接口文件的第一行必须是 `package "完整包名"`，后续为接口声明。
[访问控制]() 相关的 `pub` 关键字，以及函数参数名均需省略。

#### 实现虚拟包

虚拟包可提供默认实现。将 [`virtual.has-default`](../toolchain/moon/package.md#declarations) 设为 `true` 后，即可在同一个包内按常规方式编写实现代码。

```moonbit
///|
pub fn log(s : String) -> Unit {
  println(s)
}
```

虚拟包也可由第三方实现。将 [`implements`](../toolchain/moon/package.md#implementations) 字段设为目标包的完整名称后，编译器会对缺失的实现或不匹配的实现给出警告。

```json
{
  "implement": "moonbit-community/language/packages/virtual"
}
```

```moonbit
///|
pub fn log(string : String) -> Unit {
  ignore(string)
}
```

#### 使用虚拟包

使用虚拟包的方式与普通包一致：在要使用该虚拟包的包的配置中，定义 [`import`](../toolchain/moon/package.md#import) 字段即可。

#### 覆盖虚拟包实现

若虚拟包有默认实现且你希望使用该默认实现，无需额外配置。

否则，可通过定义 [`overrides`](../toolchain/moon/package.md#overriding-implementations) 字段，传入希望使用的实现包数组。

```json
{
  "overrides": ["moonbit-community/language/packages/implement"],
  "import": [
    "moonbit-community/language/packages/virtual"
  ],
  "is-main": true
}
```

使用虚拟包中的实体时，需引用该虚拟包的标识符：

```moonbit
///|
fn main {
  @virtual.log("Hello")
}
```
