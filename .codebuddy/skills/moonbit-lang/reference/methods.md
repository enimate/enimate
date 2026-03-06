## 方法与特征（Trait）

### 方法系统
MoonBit 对方法的支持方式与传统面向对象语言不同。MoonBit 中的方法只是与类型构造函数关联的顶层函数。
要定义一个方法，需在函数名前添加 `SelfTypeName::` 前缀，例如 `fn SelfTypeName::method_name(...)`，该方法便归属于 `SelfTypeName`。
在方法声明的签名中，你可以使用 `Self` 来指代 `SelfTypeName`。

##### 警告
目前存在一种定义方法的简写语法。
当第一个参数的名称为 `self` 时，函数声明会被视为该 `self` 类型的方法。
此语法未来可能被弃用，我们不建议在新代码中使用。

```moonbit
fn method_name(self : SelfType) -> Unit { ... }
```

```moonbit
enum List[X] {
  Nil
  Cons(X, List[X])
}

///|
fn[X] List::length(xs : List[X]) -> Int {
  ...
}
```

调用方法时，你既可以使用限定语法 `T::method_name(..)`，也可以使用点语法（此时第一个参数的类型为 `T`）：

```moonbit
let l : List[Int] = Nil
println(l.length())
println(List::length(l))
```

当方法的第一个参数同时也是其所属的类型时，可通过点语法 `x.method(...)` 调用方法。MoonBit 会根据 `x` 的类型自动找到对应的方法，无需编写方法的类型名甚至包名：

```moonbit
pub(all) enum List[X] {
  Nil
  Cons(X, List[X])
}

pub fn[X] List::concat(list : List[List[X]]) -> List[X] {
  ...
}
```

```moonbit
// 假设 `xs` 是一个列表的列表，以下两行代码等价
let _ = xs.concat()
let _ = @list.List::concat(xs)
```

与普通函数不同，使用 `TypeName::method_name` 语法定义的方法支持重载：
不同类型可以定义同名方法，因为每个方法都处于不同的命名空间中：

```moonbit
struct T1 {
  x1 : Int
}

fn T1::default() -> T1 {
  { x1: 0 }
}

struct T2 {
  x2 : Int
}

fn T2::default() -> T2 {
  { x2: 0 }
}

test {
  let t1 = T1::default()
  let t2 = T2::default()

}
```

#### 本地方法
为确保方法解析的单一数据源并避免歧义，
[方法只能在其类型所属的同一个包中定义](packages.md#trait-implementations)。
但该规则有一个例外：MoonBit 允许为外部类型在本地定义*私有*方法。
这些本地方法可以覆盖来自该类型自身包的方法（此时 MoonBit 会发出警告），
并可为上游 API 提供扩展/补充功能：

```moonbit
fn Int::my_int_method(self : Int) -> Int {
  self * self + self
}

test {
  assert_eq((6).my_int_method(), 42)
}
```

#### 将方法别名化为函数
MoonBit 允许通过别名使用替代名称调用方法。

方法别名会创建一个对应名称的方法。
你也可以选择创建一个对应名称的函数。
可见性也可以被控制。

```moonbit
##alias(m)
##alias(n, visibility="priv")
##as_free_fn(m)
##as_free_fn(n, visibility="pub")
fn List::f() -> Bool {
  true
}
test {
  assert_eq(List::f(), List::m())
  assert_eq(List::m(), m())
}
```

### 运算符重载
MoonBit 支持通过多个内置特征重载内置运算符的中缀运算符。例如：

```moonbit
struct T {
  x : Int
}

impl Add for T with add(self : T, other : T) -> T {
  { x: self.x + other.x }
}

test {
  let a = { x: 0 }
  let b = { x: 2 }
  assert_eq((a + b).x, 2)
}
```

其他运算符可通过带注解的方法重载，例如 `_[_]` 和 `_[_]=_`：

```moonbit
struct Coord {
  mut x : Int
  mut y : Int
} derive(Show)

##alias("_[_]")
fn Coord::get(coord : Self, key : String) -> Int {
  match key {
    "x" => coord.x
    "y" => coord.y
  }
}

##alias("_[_]=_")
fn Coord::set(coord : Self, key : String, val : Int) -> Unit {
  match key {
    "x" => coord.x = val
    "y" => coord.y = val
  }
}
```

```moonbit
fn main {
  let c = { x: 1, y: 2 }
  println(c)
  println(c["y"])
  c["x"] = 23
  println(c)
  println(c["x"])
}
```

```default
{x: 1, y: 2}
2
{x: 23, y: 2}
23
```

目前，以下运算符可被重载：

| 运算符名称            | 重载机制                |
|-----------------------|-------------------------|
| `+`                   | 特征 `Add`              |
| `-`                   | 特征 `Sub`              |
| `*`                   | 特征 `Mul`              |
| `/`                   | 特征 `Div`              |
| `%`                   | 特征 `Mod`              |
| `==`                  | 特征 `Eq`               |
| `<<`                  | 特征 `Shl`              |
| `>>`                  | 特征 `Shr`              |
| `-`（一元）           | 特征 `Neg`              |
| `_[_]`（获取元素）    | 方法 + 别名 `_[_]`      |
| `_[_] = _`（设置元素）| 方法 + 别名 `_[_]=_`    |
| `_[_:_]`（切片视图）  | 方法 + 别名 `_[_:_]`    |
| `&`                   | 特征 `BitAnd`           |
| `|`                   | 特征 `BitOr`            |
| `^`                   | 特征 `BitXOr`           |

重载 `_[_]`/`_[_] = _`/`_[_:_]` 时，方法必须具备正确的签名：

- `_[_]` 应具有签名 `(Self, Index) -> Result`，使用方式为 `let result = self[index]`
- `_[_]=_` 应具有签名 `(Self, Index, Value) -> Unit`，使用方式为 `self[index] = value`
- `_[_:_]` 应具有签名 `(Self, start? : Index, end? : Index) -> Result`，使用方式为 `let result = self[start:end]`

通过实现 `_[_:_]` 方法，你可以为自定义类型创建切片视图。示例如下：

```moonbit
struct DataView(String)

struct Data {}

##alias("_[_:_]")
fn Data::as_view(_self : Data, start? : Int = 0, end? : Int) -> DataView {
  "[\{start}, \{end.unwrap_or(100)})"
}

test {
  let data = Data::{  }
  inspect(data[:].0, content="[0, 100)")
  inspect(data[2:].0, content="[2, 100)")
  inspect(data[:5].0, content="[0, 5)")
  inspect(data[2:5].0, content="[2, 5)")
}
```

### 特征系统
MoonBit 提供特征系统以支持重载/特设多态。特征会声明一组操作，当某个类型想要实现该特征时，必须提供这些操作的具体实现。特征的声明方式如下：

```moonbit
pub(open) trait I {
  method_(Int) -> Int
  method_with_label(Int, label~ : Int) -> Int
  //! method_with_label(Int, label?: Int) -> Int
}
```

在特征定义的主体中，特殊类型 `Self` 用于指代实现该特征的类型。

#### 扩展特征
一个特征可以依赖其他特征，例如：

```moonbit
pub(open) trait Position {
  pos(Self) -> (Int, Int)
}

pub(open) trait Draw {
  draw(Self, Int, Int) -> Unit
}

pub(open) trait Object: Position + Draw {}
```

#### 实现特征
要实现一个特征，类型必须通过 `impl Trait for Type with method_name(...) { ... }` 语法显式提供该特征要求的所有方法。例如：

```moonbit
pub(open) trait MyShow {
  to_string(Self) -> String
}

struct MyType {}

pub impl MyShow for MyType with to_string(self) {
  ...
}

struct MyContainer[_] {}

// 带类型参数的特征实现。
// `[X : Show]` 表示类型参数 `X` 必须实现 `Show` 特征，
// 这部分内容后续会详细说明。
pub impl[X : MyShow] MyShow for MyContainer[X] with to_string(self) {
  ...
}
```

特征实现中可以省略类型注解：MoonBit 会根据 `Trait::method` 的签名和 self 类型自动推导类型。

特征的作者还可以为特征中的某些方法定义**默认实现**，例如：

```moonbit
pub(open) trait J {
  f(Self) -> Unit
  f_twice(Self) -> Unit = _
}

impl J with f_twice(self) {
  self.f()
  self.f()
}
```

注意，除了为 `f_twice` 编写实际的默认实现 `impl J with f_twice` 外，
还需要在 `J` 中 `f_twice` 的声明处添加标记 `= _`。
`= _` 标记用于指示该方法拥有默认实现，
能让读者一眼就知道哪些方法有默认实现，提升代码可读性。

特征 `J` 的实现者无需为 `f_twice` 提供实现：要实现 `J`，只需实现 `f` 即可。
不过，如果需要，实现者也可以通过显式的 `impl J for Type with f_twice` 覆盖默认实现。

```moonbit
impl J for Int with f(self) {
  println(self)
}

impl J for String with f(self) {
  println(self)
}

impl J for String with f_twice(self) {
  println(self)
  println(self)
}

```

要实现子特征，必须先实现父特征，
并实现子特征中定义的方法。例如：

```moonbit
impl Position for Point with pos(self) {
  (self.x, self.y)
}

impl Draw for Point with draw(self, x, y) {
  ()
}

pub fn[O : Object] draw_object(obj : O) -> Unit {
  let (x, y) = obj.pos()
  obj.draw(x, y)
}

test {
  let p = Point::{ x: 1, y: 2 }
  draw_object(p)
}
```

对于所有方法都有默认实现的特征，
仍需显式实现该特征，
以支持[抽象特征](packages.md#traits)等特性。
为此，MoonBit 提供了 `impl Trait for Type` 语法（即不带方法部分）。
`impl Trait for Type` 用于确保 `Type` 实现了 `Trait`，
MoonBit 会自动检查该特征中的每个方法是否都有对应的实现（自定义实现或默认实现）。

除了处理所有方法都有默认实现的特征外，
`impl Trait for Type` 还可作为文档说明，或作为填充实际实现前的待办标记。

##### 警告
目前，没有任何方法的空特征会被自动实现。

#### 使用特征
声明泛型函数时，可以为类型参数标注其应实现的特征，从而定义带约束的泛型函数。例如：

```moonbit
fn[X : Eq] contains(xs : Array[X], elem : X) -> Bool {
  for x in xs {
    if x == elem {
      return true
    }
  } else {
    false
  }
}
```

如果没有 `Eq` 约束，`contains` 中的表达式 `x == elem` 会导致类型错误。现在，函数 `contains` 可被任何实现了 `Eq` 特征的类型调用，例如：

```moonbit
struct Point {
  x : Int
  y : Int
}

impl Eq for Point with equal(p1, p2) {
  p1.x == p2.x && p1.y == p2.y
}

test {
  assert_false(contains([1, 2, 3], 4))
  assert_true(contains([1.5, 2.25, 3.375], 2.25))
  assert_false(contains([{ x: 2, y: 3 }], { x: 4, y: 9 }))
}
```

##### 直接调用特征方法
特征的方法可通过 `Trait::method` 直接调用。MoonBit 会推导 `Self` 的类型，并检查 `Self` 是否确实实现了该特征，例如：

```moonbit
test {
  assert_eq(Show::to_string(42), "42")
  assert_eq(Compare::compare(1.0, 2.5), -1)
}
```

特征实现也可通过点语法调用，但需遵循以下限制：

1. 如果存在普通方法，使用点语法时会优先调用普通方法
2. 只有位于 self 类型所属包中的特征实现才能通过点语法调用
   - 如果存在多个来自不同特征的同名特征方法可用，会报歧义错误

上述规则确保了 MoonBit 的点语法在保持灵活性的同时具备良好的特性。
例如，添加新依赖绝不会因歧义而破坏现有使用点语法的代码。
这些规则也让 MoonBit 的名称解析变得极其简单：
通过点语法调用的方法必定来自当前包或该类型所属的包！

以下是通过点语法调用特征实现的示例：

```moonbit
struct MyCustomType {}

pub impl Show for MyCustomType with output(self, logger) {
  ...
}

fn f() -> Unit {
  let x = MyCustomType::{  }
  let _ = x.to_string()

}
```

### 特征对象
MoonBit 支持通过特征对象实现运行时多态。
如果 `t` 的类型为 `T`，且 `T` 实现了特征 `I`，
则可通过 `t as &I` 将实现 `I` 的 `T` 方法与 `t` 一起打包为运行时对象。
当表达式的预期类型为特征对象类型时，`as &I` 可省略。
特征对象会擦除值的具体类型，
因此来自不同具体类型的对象可放入同一个数据结构中并被统一处理：

```moonbit
pub(open) trait Animal {
  speak(Self) -> String
}

struct Duck(String)

fn Duck::make(name : String) -> Duck {
  Duck(name)
}

impl Animal for Duck with speak(self) {
  "\{self.0}: quack!"
}

struct Fox(String)

fn Fox::make(name : String) -> Fox {
  Fox(name)
}

impl Animal for Fox with speak(_self) {
  "What does the fox say?"
}

test {
  let duck1 = Duck::make("duck1")
  let duck2 = Duck::make("duck2")
  let fox1 = Fox::make("fox1")
  let animals : Array[&Animal] = [duck1, duck2, fox1]
  inspect(
    animals.map(fn(animal) { animal.speak() }),
    content=(
      #|["duck1: quack!", "duck2: quack!", "What does the fox say?"]
    ),
  )
}
```

并非所有特征都可用于创建对象。
“对象安全”的特征方法必须满足以下条件：

- `Self` 必须是方法的第一个参数
- 方法的类型中只能出现一次 `Self`（即第一个参数位置）

用户可为特征对象定义新方法，就像为结构体和枚举定义新方法一样：

```moonbit
pub(open) trait Logger {
  write_string(Self, String) -> Unit
}

pub(open) trait CanLog {
  log(Self, &Logger) -> Unit
}

fn[Obj : CanLog] &Logger::write_object(self : &Logger, obj : Obj) -> Unit {
  obj.log(self)
}

// 使用新方法简化代码
pub impl[A : CanLog, B : CanLog] CanLog for (A, B) with log(self, logger) {
  let (a, b) = self
  logger
  ..write_string("(")
  ..write_object(a)
  ..write_string(", ")
  ..write_object(b)
  ..write_string(")")
}
```

### 内置特征
MoonBit 提供了以下实用的内置特征：

<!-- MANUAL CHECK https://github.com/moonbitlang/core/blob/80cf250d22a5d5eff4a2a1b9a6720026f2fe8e38/builtin/traits.mbt -->
```moonbit
trait Eq {
  op_equal(Self, Self) -> Bool
}

trait Compare : Eq {
  // `0` 表示相等，`-1` 表示小于，`1` 表示大于
  compare(Self, Self) -> Int
}

trait Hash {
  hash_combine(Self, Hasher) -> Unit // 待实现
  hash(Self) -> Int // 有默认实现
}

trait Show {
  output(Self, Logger) -> Unit // 待实现
  to_string(Self) -> String // 有默认实现
}

trait Default {
  default() -> Self
}
```

#### 派生内置特征
MoonBit 可自动为部分内置特征派生实现：

```moonbit
struct T {
  a : Int
  b : Int
} derive(Eq, Compare, Show, Default)

test {
  let t1 = T::default()
  let t2 = T::{ a: 1, b: 1 }
  inspect(t1, content="{a: 0, b: 0}")
  inspect(t2, content="{a: 1, b: 1}")
  assert_not_eq(t1, t2)
  assert_true(t1 < t2)
}
```

有关派生特征的更多信息，请参见 [Deriving](derive.md)。
