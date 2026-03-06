# MoonBit 语言基础


## 快速参考：

```mbt check
///|
/// 注释文档字符串
pub fn sum(x : Int, y : Int) -> Int {
  x + y
}

///|
struct Rect {
  width : Int
  height : Int
}

///|
fn Rect::area(self : Rect) -> Int {
  self.width * self.height
}

///|
pub impl Show for Rect with output(_self, logger) {
  logger.write_string("Rect")
}

///|
enum MyOption {
  MyNone
  MySome(Int)
} derive(Show, ToJson, Eq, Compare)

///|
///  match + 循环都是表达式
test "everything is expression in MoonBit" {
  // 元组
  let (n, opt) = (1, MySome(2))
  // if 表达式有返回值
  let msg : String = if n > 0 { "pos" } else { "non-pos" }
  let res = match opt {
    MySome(x) => {
      inspect(x, content="2")
      1
    }
    MyNone => 0
  }
  let status : Result[Int, String] = Ok(10)
  // match 表达式有返回值
  let description = match status {
    Ok(value) => "Success: \{value}"
    Err(error) => "Error: \{error}"
  }
  let array = [1, 2, 3, 4, 5]
  let mut i = 0 // 可变绑定（仅局部可用，全局绑定不可变）
  let target = 3
  // 循环可通过 'break' 返回值
  let found : Int? = while i < array.length() {
    if array[i] == target {
      break Some(i) // 带值退出循环
    }
    i = i + 1
  } else { // 循环正常结束时的返回值
    None
  }
  assert_eq(found, Some(2)) // 在索引 2 处找到目标值
}

///|
/// 全局绑定
pub let my_name : String = "MoonBit"

///|
pub const PI : Double = 3.14159 // 常量使用大写蛇形命名法（UPPER_SNAKE）或帕斯卡命名法（PascalCase）

///|
pub fn maximum(xs : Array[Int]) -> Int raise {
  // 顶层函数默认是**相互递归**的
  // `raise` 注解表示该函数可能抛出任意类型的 Error
  // 仅当需要追踪特定错误类型时，才添加 `raise XXError`
  match xs {
    [] => fail("Empty array") // fail() 是内置的通用错误抛出函数
    [x] => x
    // 对数组进行模式匹配，`.. rest` 是剩余模式
    // 其类型为 `ArrayView[Int]`（切片）
    [x, .. rest] => {
      let mut max_val = x // `mut` 仅允许用于局部绑定
      for y in rest {
        if y > max_val {
          max_val = y
        }
      }
      max_val // 如果最后一个表达式是返回值，可省略 return 关键字
    }
  }
}

///|
/// pub(all) 表示该结构体可在包外被读取和实例化
pub(all) struct Point {
  x : Int
  mut y : Int
} derive(Show, ToJson)

///|
pub enum MyResult[T, E] {
  MyOk(T) // 换行时，分号 `;` 可选
  MyErr(E) // 枚举变体必须以大写字母开头
} derive(Show, Eq, ToJson)
// pub 表示该枚举可在包外进行模式匹配
// 但无法在包外实例化，如需实例化请使用 `pub(all)`

///|
/// pub (open) 表示该 trait 可被外部包的类型实现
pub(open) trait Comparable {
  compare(Self, Self) -> Int // `Self` 指代实现该 trait 的类型
}

///|
test "inspect test" {
  let result = sum(1, 2)
  inspect(result, content="3")
  // 运行 `moon test --update` 可自动修正 `content` 的值
  let point = Point::{ x: 10, y: 20 }
  // 对于复杂结构，使用 @json.inspect 可获得更易读的输出：
  @json.inspect(point, content={ "x": 10, "y": 20 })
}
```


## 复杂类型

```mbt check
///|
pub type UserId = Int // 将 Int 别名化为 UserId - 类似符号链接

///|
/// 用于回调的元组结构体
pub struct Handler((String) -> Unit) // 新类型包装器

///|
/// 单字段新类型的元组结构体语法
struct Meters(Int) // 元组结构体语法

///|
let distance : Meters = Meters(100)

///|
let raw : Int = distance.0 // 通过 .0 访问第一个字段

///|
struct Addr {
  host : String
  port : Int
} derive(Show, Eq, ToJson, FromJson)

///|
/// 带字面量语法的结构化类型
let config : Addr = Addr::{
  // 由于类型已明确，`Type::` 前缀可省略
  host: "localhost",
  port: 8080,
}
```

## 常见可派生 Trait

大多数类型可通过 `derive(...)` 语法自动派生标准 trait：

- **`Show`** - 启用 `to_string()` 方法和 `\{value}` 字符串插值
- **`Eq`** - 启用 `==` 和 `!=` 相等运算符
- **`Compare`** - 启用 `<`、`>`、`<=`、`>=` 比较运算符
- **`ToJson`** - 启用 `@json.inspect()` 以生成可读性更好的测试输出
- **`Hash`** - 允许类型作为 Map 的键

```mbt check
///|
struct Coordinate {
  x : Int
  y : Int
} derive(Show, Eq, ToJson)

///|
enum Status {
  Active
  Inactive
} derive(Show, Eq, Compare)
```

**最佳实践**：为所有数据类型派生 `Show` 和 `Eq`。如果计划使用 `@json.inspect()` 测试类型，需添加 `ToJson`。

## 默认引用语义

MoonBit 语义上默认按引用传递大多数类型（优化器可能会复制不可变值）：

```mbt check
///|
/// 包含 'mut' 字段的结构体始终按引用传递
struct Counter {
  mut value : Int
}

///|
fn increment(c : Counter) -> Unit {
  c.value += 1 // 修改原始实例的值
}

///|
/// 数组和映射（Map）是可变引用
fn modify_array(arr : Array[Int]) -> Unit {
  arr[0] = 999 // 修改原始数组
}

///|
test "reference semantics" {
  let counter : Ref[Int] = Ref::{ val: 0 }
  counter.val += 1
  assert_true(counter.val is 1)
  let arr : Array[Int] = [1, 2, 3] // 与 Rust 不同，无需 `mut` 关键字
  modify_array(arr)
  assert_true(arr[0] is 999)
  let mut x = 3 // 对绑定重新赋值时需要 `mut`
  x += 2
  assert_true(x is 5)
}
```

## 模式匹配

```mbt check
///|
#warnings("-unused_value")
test "pattern match over Array, struct and StringView" {
  let arr : Array[Int] = [10, 20, 25, 30]
  match arr {
    [] => ... // 空数组
    [single] => ... // 单元素数组
    [first, .. middle, rest] => {
      let _ : ArrayView[Int] = middle // middle 的类型是 ArrayView[Int]
      assert_true(first is 10 && middle is [20, 25] && rest is 30)
    }
  }
  fn process_point(point : Point) -> Unit {
    match point {
      { x: 0, y: 0 } => ...
      { x, y } if x == y => ...
      { x, .. } if x < 0 => ...
      ...
    }
  }
  /// 用于解析的 StringView 模式匹配
  fn is_palindrome(s : StringView) -> Bool {
    loop s {
      [] | [_] => true
      [a, .. rest, b] if a == b => continue rest
      // a 的类型是 Char，rest 的类型是 StringView
      _ => false
    }
  }
}
```

## 函数式 `loop` 控制流

`loop` 结构是 MoonBit 特有的：

```mbt check
///|
/// 对循环变量进行模式匹配的函数式循环
/// @list.List 来自标准库
fn sum_list(list : @list.List[Int]) -> Int {
  loop (list, 0) {
    (Empty, acc) => acc // 基准情况返回累加器
    (More(x, tail=rest), acc) => continue (rest, x + acc) // 携带新值递归
  }
}

///|
/// 带复杂控制流的多循环变量
fn find_pair(arr : Array[Int], target : Int) -> (Int, Int)? {
  loop (0, arr.length() - 1) {
    (i, j) if i >= j => None
    (i, j) => {
      let sum = arr[i] + arr[j]
      if sum == target {
        Some((i, j)) // 找到匹配对
      } else if sum < target {
        continue (i + 1, j) // 移动左指针
      } else {
        continue (i, j - 1) // 移动右指针
      }
    }
  }
}
```

**注意**：必须为 `loop` 提供参数。如果需要无限循环，请使用 `while true { ... }`。不带参数的 `loop { ... }` 语法是无效的。

## 方法与 Trait

方法使用 `Type::method_name` 语法，Trait 需要显式实现：

```mbt check
///|
struct Rectangle {
  width : Double
  height : Double
}

///|
// 方法以 Type:: 为前缀
fn Rectangle::area(self : Rectangle) -> Double {
  self.width * self.height
}

///|
/// 静态方法不需要 self 参数
fn Rectangle::new(w : Double, h : Double) -> Rectangle {
  { width: w, height: h }
}

///|
/// Show trait 现在使用 output(self, logger) 实现自定义格式化
/// to_string() 会由此自动派生
pub impl Show for Rectangle with output(self, logger) {
  logger.write_string("Rectangle(\{self.width}x\{self.height})")
}

///|
/// Trait 可以包含非对象安全的方法
trait Named {
  name() -> String // 无 'self' 参数 - 非对象安全
}

///|
/// 泛型中的 Trait 约束
fn[T : Show + Named] describe(value : T) -> String {
  "\{T::name()}: \{value.to_string()}"
}

///|
/// Trait 实现
impl Hash for Rectangle with hash_combine(self, hasher) {
  hasher..combine(self.width)..combine(self.height)
}
```

## 运算符重载

MoonBit 支持通过 Trait 实现运算符重载：

```mbt check
///|
struct Vector(Int, Int)

///|
/// 实现算术运算符
pub impl Add for Vector with add(self, other) {
  Vector(self.0 + other.0, self.1 + other.1)
}

///|
struct Person {
  age : Int
} derive(Eq)

///|
/// 比较运算符
pub impl Compare for Person with compare(self, other) {
  self.age.compare(other.age)
}

///|
test "overloading" {
  let v1 : Vector = Vector(1, 2)
  let v2 : Vector = Vector(3, 4)
  let _v3 : Vector = v1 + v2
}
```

## 访问控制修饰符

MoonBit 提供细粒度的可见性控制：

```mbt check
///|
/// `fn` 默认私有 - 仅在当前包内可见
fn internal_helper() -> Unit {
  ...
}

///|
pub fn get_value() -> Int {
  ...
}

///|
// 结构体（默认）- 类型可见，实现细节隐藏
struct DataStructure {}

///|
/// `pub struct` 默认只读 - 可读取、模式匹配，但不可实例化
pub struct Config {}

///|
/// 完全公开 - 拥有全部访问权限
pub(all) struct Config2 {}

///|
/// 抽象 trait（默认）- 外部包的类型无法实现该 trait
pub trait MyTrait {}

///|
/// 可扩展的 trait
pub(open) trait Extendable {}
```
