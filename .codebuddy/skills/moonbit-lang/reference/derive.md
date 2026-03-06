## 派生 trait

MoonBit 支持从类型定义中自动派生多个内置 trait。

要为某个类型派生 trait `T`，要求该类型中使用的所有字段都实现了 `T`。
例如，为结构体 `struct A { x: T1; y: T2 }` 派生 `Show` trait，需要 `T1: Show` 且 `T2: Show` 同时成立。

### Show

`derive(Show)` 会为该类型生成一个美观的打印方法。
派生后的格式与该类型在代码中的构造方式类似。

```moonbit
struct MyStruct {
  x : Int
  y : Int
} derive(Show)

test "derive show struct" {
  let p = MyStruct::{ x: 1, y: 2 }
  assert_eq(Show::to_string(p), "{x: 1, y: 2}")
}
```

```moonbit
enum MyEnum {
  Case1(Int)
  Case2(label~ : String)
  Case3
} derive(Show)

test "derive show enum" {
  assert_eq(Show::to_string(MyEnum::Case1(42)), "Case1(42)")
  assert_eq(
    Show::to_string(MyEnum::Case2(label="hello")),
    "Case2(label=\"hello\")",
  )
  assert_eq(Show::to_string(MyEnum::Case3), "Case3")
}
```

### Eq 和 Compare

`derive(Eq)` 和 `derive(Compare)` 会分别生成用于测试相等性和比较操作的对应方法。
结构体字段会按照其定义的顺序进行比较。
对于枚举类型，不同枚举成员之间的比较顺序遵循其定义时的先后顺序（定义越靠前，值越小）。

```moonbit
struct DeriveEqCompare {
  x : Int
  y : Int
} derive(Eq, Compare)

test "derive eq_compare struct" {
  let p1 = DeriveEqCompare::{ x: 1, y: 2 }
  let p2 = DeriveEqCompare::{ x: 2, y: 1 }
  let p3 = DeriveEqCompare::{ x: 1, y: 2 }
  let p4 = DeriveEqCompare::{ x: 1, y: 3 }

  // Eq
  assert_eq(p1 == p2, false)
  assert_eq(p1 == p3, true)
  assert_eq(p1 == p4, false)
  assert_eq(p1 != p2, true)
  assert_eq(p1 != p3, false)
  assert_eq(p1 != p4, true)

  // Compare
  assert_eq(p1 < p2, true)
  assert_eq(p1 < p3, false)
  assert_eq(p1 < p4, true)
  assert_eq(p1 > p2, false)
  assert_eq(p1 > p3, false)
  assert_eq(p1 > p4, false)
  assert_eq(p1 <= p2, true)
  assert_eq(p1 >= p2, false)
}
```

```moonbit
enum DeriveEqCompareEnum {
  Case1(Int)
  Case2(label~ : String)
  Case3
} derive(Eq, Compare)

test "derive eq_compare enum" {
  let p1 = DeriveEqCompareEnum::Case1(42)
  let p2 = DeriveEqCompareEnum::Case1(43)
  let p3 = DeriveEqCompareEnum::Case1(42)
  let p4 = DeriveEqCompareEnum::Case2(label="hello")
  let p5 = DeriveEqCompareEnum::Case2(label="world")
  let p6 = DeriveEqCompareEnum::Case2(label="hello")
  let p7 = DeriveEqCompareEnum::Case3

  // Eq
  assert_eq(p1 == p2, false)
  assert_eq(p1 == p3, true)
  assert_eq(p1 == p4, false)
  assert_eq(p1 != p2, true)
  assert_eq(p1 != p3, false)
  assert_eq(p1 != p4, true)

  // Compare
  assert_eq(p1 < p2, true) // 42 < 43
  assert_eq(p1 < p3, false)
  assert_eq(p1 < p4, true) // Case1 < Case2
  assert_eq(p4 < p5, true)
  assert_eq(p4 < p6, false)
  assert_eq(p4 < p7, true) // Case2 < Case3
}
```

### Default

`derive(Default)` 会生成一个返回该类型默认值的方法。

对于结构体，其默认值是所有字段都设置为各自默认值的结构体实例。

```moonbit
struct DeriveDefault {
  x : Int
  y : String?
} derive(Default, Eq, Show)

test "derive default struct" {
  let p = DeriveDefault::default()
  assert_eq(p, DeriveDefault::{ x: 0, y: None })
}
```

对于枚举类型，默认值是唯一一个不带参数的枚举成员。

```moonbit
enum DeriveDefaultEnum {
  Case1(Int)
  Case2(label~ : String)
  Case3
} derive(Default, Eq, Show)

test "derive default enum" {
  assert_eq(DeriveDefaultEnum::default(), DeriveDefaultEnum::Case3)
}
```

没有任何枚举成员，或者有多个不带参数的枚举成员的枚举类型，无法派生 `Default` trait。

<!-- 手动检查：以下代码不应编译 -->
```moonbit
enum CannotDerive1 {
    Case1(String)
    Case2(Int)
} derive(Default) // 无法找到作为默认值的无参构造函数

enum CannotDerive2 {
    Case1
    Case2
} derive(Default) // Case1 和 Case2 都可作为默认构造函数的候选，产生冲突
```

### Hash

`derive(Hash)` 会为该类型生成哈希实现。
这使得该类型可以用在需要 `Hash` 实现的场景中，
例如 `HashMap` 和 `HashSet`。

```moonbit
struct DeriveHash {
  x : Int
  y : String?
} derive(Hash, Eq, Show)

test "derive hash struct" {
  let hs = @hashset.new()
  hs.add(DeriveHash::{ x: 123, y: None })
  hs.add(DeriveHash::{ x: 123, y: None })
  assert_eq(hs.length(), 1)
  hs.add(DeriveHash::{ x: 123, y: Some("456") })
  assert_eq(hs.length(), 2)
}
```

### Arbitrary

`derive(Arbitrary)` 会生成该类型的随机值。

### FromJson 和 ToJson

`derive(FromJson)` 和 `derive(ToJson)` 会自动派生可往返（round-trippable）的方法实现，
用于将类型序列化为 JSON 格式以及从 JSON 格式反序列化。
该实现主要用于调试，以及将类型以人类可读的格式存储。

```moonbit
struct JsonTest1 {
  x : Int
  y : Int
} derive(FromJson, ToJson, Eq, Show)

enum JsonTest2 {
  A(x~ : Int)
  B(x~ : Int, y~ : Int)
} derive(FromJson(style="legacy"), ToJson(style="legacy"), Eq, Show)

test "json basic" {
  let input = JsonTest1::{ x: 123, y: 456 }
  let expected : Json = { "x": 123, "y": 456 }
  assert_eq(input.to_json(), expected)
  assert_eq(@json.from_json(expected), input)
  let input = JsonTest2::A(x=123)
  let expected : Json = { "$tag": "A", "x": 123 }
  assert_eq(input.to_json(), expected)
  assert_eq(@json.from_json(expected), input)
}
```

这两个派生指令都接受若干参数，用于配置序列化和反序列化的具体行为。

##### 警告
JSON 序列化参数的实际行为尚未稳定。

##### 警告
JSON 派生参数仅用于对派生格式进行粗粒度的控制。
如果需要精确控制类型的布局方式，
建议**直接手动实现这两个 trait**。

我们近期已弃用了大量用于调整高级布局的参数。
对于这类场景的使用以及未来可能的使用需求，请手动实现对应的 trait。
这些弃用的参数包括：`repr`、`case_repr`、`default`、`rename_all` 等。

```moonbit
struct JsonTest3 {
  x : Int
  y : Int
} derive (
  FromJson(fields(x(rename="renamedX"))),
  ToJson(fields(x(rename="renamedX"))),
  Eq,
  Show,
)

enum JsonTest4 {
  A(x~ : Int)
  B(x~ : Int, y~ : Int)
} derive(FromJson, ToJson, Eq, Show)

test "json args" {
  let input = JsonTest3::{ x: 123, y: 456 }
  let expected : Json = { "renamedX": 123, "y": 456 }
  assert_eq(input.to_json(), expected)
  assert_eq(@json.from_json(expected), input)
  let input = JsonTest4::A(x=123)
  let expected : Json = ["A", { "x": 123 }]
  assert_eq(input.to_json(), expected)
  assert_eq(@json.from_json(expected), input)
}
```

#### 枚举序列化风格

目前枚举有两种序列化风格：`legacy`（传统）和 `flat`（扁平化），
用户必须通过 `style` 参数选择其中一种。
以下面的枚举定义为例：

```moonbit
enum E {
  One
  Uniform(Int)
  Axes(x~: Int, y~: Int)
}
```

使用 `derive(ToJson(style="legacy"))` 时，该枚举会被格式化为：

```default
E::One              => { "$tag": "One" }
E::Uniform(2)       => { "$tag": "Uniform", "0": 2 }
E::Axes(x=-1, y=1)  => { "$tag": "Axes", "x": -1, "y": 1 }
```

使用 `derive(ToJson(style="flat"))` 时，该枚举会被格式化为：

```default
E::One              => "One"
E::Uniform(2)       => [ "Uniform", 2 ]
E::Axes(x=-1, y=1)  => [ "Axes", -1, 1 ]
```

##### 为 `Option` 派生

一个值得注意的例外是内置类型 `Option[T]`。
理想情况下，它应被解析为 `T | undefined`，但问题在于，对于 `Option[Option[T]]` 类型，
无法区分 `Some(None)` 和 `None` 两种情况。

因此，只有当 `Option` 作为结构体的直接字段时，才会被解析为 `T | undefined`；
其他情况下则解析为 `[T] | null`：

```moonbit
struct A {
  x : Int?
  y : Int??
  z : (Int?, Int??)
} derive(ToJson)

test {
  @json.inspect({ x: None, y: None, z: (None, None) }, content={
    "z": [null, null],
  })
  @json.inspect({ x: Some(1), y: Some(None), z: (Some(1), Some(None)) }, content={
    "x": 1,
    "y": null,
    "z": [[1], [null]],
  })
  @json.inspect({ x: Some(1), y: Some(Some(1)), z: (Some(1), Some(Some(1))) }, content={
    "x": 1,
    "y": [1],
    "z": [[1], [[1]]],
  })
}
```

#### 容器参数

- `rename_fields` 和 `rename_cases`（仅枚举可用）
  批量将字段（枚举和结构体）或枚举成员重命名为指定格式。
  支持的参数值包括：
  - `lowercase`（小写）
  - `UPPERCASE`（大写）
  - `camelCase`（小驼峰）
  - `PascalCase`（大驼峰）
  - `snake_case`（蛇形命名）
  - `SCREAMING_SNAKE_CASE`（全大写蛇形）
  - `kebab-case`（短横线命名）
  - `SCREAMING-KEBAB-CASE`（全大写短横线）

  示例：若字段名为 `my_long_field_name`，设置 `rename_fields = "PascalCase"` 后，
  该字段会被重命名为 `MyLongFieldName`。

  重命名逻辑默认假定字段名初始为 `snake_case` 格式，
  结构体/枚举成员名初始为 `PascalCase` 格式。
- `cases(...)`（仅枚举可用）控制枚举成员的布局。

  #### 警告
  未来该参数可能会被枚举成员属性替代。

  例如，对于如下枚举：
  ```moonbit
  enum E {
    A(...)
    B(...)
  }
  ```

  可以通过 `cases(A(...), B(...))` 来分别控制每个枚举成员的行为。

  具体可参考下文的「成员参数」部分。
- `fields(...)`（仅结构体可用）控制结构体字段的布局。

  #### 警告
  未来该参数可能会被字段属性替代。

  例如，对于如下结构体：
  ```moonbit
  struct S {
    x: Int
    y: Int
  }
  ```

  可以通过 `fields(x(...), y(...))` 来分别控制每个字段的行为。

  具体可参考下文的「字段参数」部分。

#### 成员参数

- `rename = "..."` 重命名指定的枚举成员，
  若存在容器级别的重命名指令，该参数会覆盖容器级指令的效果。
- `fields(...)` 控制该枚举成员负载（payload）的布局。
  注意：目前暂不支持对位置参数（positional fields）进行重命名。

  具体可参考下文的「字段参数」部分。

#### 字段参数

- `rename = "..."` 重命名指定的字段，
  若存在容器级别的重命名指令，该参数会覆盖容器级指令的效果。
