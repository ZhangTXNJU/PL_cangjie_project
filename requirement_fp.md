# 南京大学 编程语言设计和实现2025
## Project B-泛型与类型推断 2025/12/03
## Project B-泛型与类型推断
1. 概述 ......
3. 类型推断 ......
3.1 变量声明 ......4
3.1.1 可变变量var的特殊性 ......4
3.1.2 全局变量 ......4
3.2 函数 ......
3.3 一元运算符 ......5
3.4 二元运算符 ......5
3.5 if表达式 ......5
3.6 while表达式 ......5
3.7 解释 ......6
3.7.1 函数的自我递归 ......6
3.7.2 调用返回类型未知的函数 ......6
4. 泛型函数 ......
4.1 类型检查与实例化顺序 ......8
4.2 泛型类型错误 ......8
4.3 手动指定泛型参数 ......9
5. 泛型与Option ......
5.1 Some ......10
5.2 None ......10
6. 泛型类 ......10
7. interface ......11
7.1 实现接口 ......12
7.2 泛型接口 ......12
7.3 子接口 ......13
7.4 内置接口 ......13
7.5 默认实现 ......13
8. 泛型约束 ......15
8.1 对函数和类进行约束 ......15
8.2 对接口进行约束 ......15
9. Hindley-Milner类型推断 ......16
9.1 Hindley Milner with Typeclasses ......16
9.2 Hindley Milner与类 ......16
10. 输入输出 ......18
11. 提交 ......19
11.1 提交格式 ......19
11.1.1 说明 ......19
11.2 实验报告要求 ......19
11.3 代码提示 ......20
11.4 学术诚信Academic Integrity ......20
A. 附录A ......21
A.1 错误代码 ......21
A.1.1 静态错误代码 ......21
A.1.2 动态错误代码 ......22
A.2 内置接口 ......22
A.2.1 HAdd<T,R>异质加法 ......22
A.2.2 HSub<T,R>异质减法 ......23
A.2.3 HMul<T,R>异质乘法 ......23
A.2.4 HDiv<T,R>异质除法 ......23
A.2.5 HMod<T,R>异质取余 ......23
A.2.7 HOrd<T>异质比较 ......24
A.2.8 HEq<T>异质相等比较 ......24
B. 附录 B ......25
B.1 子类型与约束的区别 ......25
B.2 Haskell如何解决成员访问问题 ......25
B.3 在Hindley-Milner中支持Typeclasses ......26

---

## 1. 概述
在 lab3 中，你已经实现了对类型的静态检查。然而，你的类型检查器仍然需要程序员为每个函数显式地标注参数和返回值的类型，哪怕它们是显而易见的。同时，泛型也不受支持，这使得你无法编写类型安全且可复用的代码。

这个 Project 中，你将在 njucj 中实现更完善的类型系统与类型推断算法。

**提示**
Hindley-Milner 类型推断与子类型系统不能共存，这是因为泛型约束 + 完整的子类型系统会使得推断算法直接变得图灵不可判定。

选择这个 Project，你可能需要完全放弃 Project A(面向对象和垃圾回收)的代码。如果你因为某些原因需要同时选择两个 Project，你需要将你的代码仓库分叉成两个互不影响的版本，每个版本分别实现一个 Project 的要求。

## 分数说明
Project 由 3 类测试要求构成:
- **基本要求 (40%)**
  在这 40% 的测试用例中，只需要实现从上到下，从左到右的朴素类型推断，就能拿到分数。
  你还要实现泛型函数。
- **阶段要求 1 (20%)**
  在基础要求的基础上，允许定义 interface。在这个 Project 中，interface 是一种类似 typeclass 的东西。它不能被当作子类型使用，但是泛型参数可以被 interface 约束。
- **阶段要求 2 (25%)**
  在基础要求的基础上，实现 Hindley-Milner 类型推断算法。
- **综合测试 (15%)**
  有 15% 的测试点需要同时支持 interface 和 Hindley-Milner 类型推断算法才能通过，即，同时实现上面的 3 个要求。
- **Bonus (10%)**
  文档中被标记为 Bonus 的内容可以让你额外获得 10% 的分数奖励。Bonus 内容没有测试点，你可以在实验报告中附上实现思路、自制的测试用例和运行结果截图来证明你完成了它们。

测试用例是混合评测的。只有实现上面的所有要求，才能获得满分。

保证不会出现要求发生冲突的情况。例如，要求 1 中说明的朴素类型推断机制不会和要求 3 中的 Hindley-Milner 类型推断算法冲突。因此，有 40% + 20% 的测试用例要么能在朴素的从上到下，从左到右的类型推断下通过，要么能被该算法判定为错误。

## 3. 类型推断
你应该已经注意到，在 lab3 中，实际上也需要去计算一些表达式的类型。例如，在变量声明中:
```
let x: Int64 = 1 + 2
```
你需要计算 `1 + 2` 的类型，并检查它是否与变量 `x` 的标注类型 `Int64` 一致。

那么，既然你已经实现了表达式类型的计算，为什么不直接用它来推断变量和函数的类型呢?

在 40% + 20% 的测试用例中，你可以只实现一种朴素的类型推断机制就拿到分数。该机制可以从上到下、从左到右地推断出变量和函数的类型。为了和 Hindley-Milner 算法兼容，这一部分测试用例将会保证，使用朴素的类型推断机制，类型要么能被确定的推断出来，要么能被判定为错误。

### 3.1 变量声明
对于标记了类型的变量声明，也就是 `let <标识符>: 类型 (= <表达式>)?`
与之前一样，你应当检查 `<表达式>` 的类型是否与标注的类型一致。

我们同时允许没有标注类型的变量声明:
```
let <标识符> = <表达式>
```
在这种情况下，你应当推断 `<表达式>` 的类型，并将该类型赋予变量 `<标识符>`。

### 3.1.1 可变变量 var 的特殊性
上面的内容没有 var 是有意为之。

由于一些相对复杂的原因， Hindley-Milner 不能直接处理可变变量，会导致类型系统 unsound，因此，在这个实验中，我们要求任何可变变量 var 一定要标注类型。

njucj 中变量的类型标注无法使用泛型，从而回避了需要 value restriction 的问题。

### 3.1.2 全局变量
特别的，由于全局变量的初始化表达式可能会引用其它全局变量和函数的问题，仍然保证全局变量一定会标注类型。

### 3.2 函数
类似的，函数的返回值现在也可以没有标注类型:
```
func foo(x: Int) {
  x + 1
}
```
对于朴素算法，在这种情况下，你应当从上到下找到第一个返回的表达式，并从中推断出返回值的类型。然后，你还应该继续向下遍历，检查其它返回语句的类型是否与该类型一致。如果不一致，以第一个返回语句的类型为准，报告错误 RETURN_TYPE_MISMATCH 。

### 3.3 一元运算符
对于一元运算符表达式，例如 `-x` 或 `!flag`，它们不是泛型的运算符，因此和 lab3 中一样，你可以直接检查操作数的类型是否符合要求。
- `operator func !(a: Bool): Bool`
- `operator func -(a: Int64): Int64`

### 3.4 二元运算符
重载机制对 Hindley-Milner 类型推断不够友好。因此，在这个实验中，大部分二元运算符被修改成了具有泛型约束的泛型函数。

下文中， HAdd 等约束是内置的泛型约束，详见 附录 A.2

现在，二元运算符的类型变成了:
- `operator func - <A, B, C>(a: A, b: B): C where A <: HSub<B, C>`
- `operator func + <A, B, C>(a: A, b: B): C where A <: HAdd<B, C>`
- `operator func * <A, B, C>(a: A, b: B): C where A <: HMul<B, C>`
- `operator func / <A, B, C>(a: A, b: B): C where A <: HDiv<B, C>`
- `operator func % <A, B, C>(a: A, b: B): C where A <: HMod<B, C>`
- `operator func ** <A, B, C>(a: A, b: B): C where A <: HExp<B, C>`
- `operator func < <A, B>(a: A, b: B): Bool where A <: HOrd<B>`
- `operator func > <A, B>(a: A, b: B): Bool where A <: HOrd<B>`
- `operator func <= <A, B>(a: A, b: B): Bool where A <: HOrd<B>`
- `operator func >= <A, B>(a: A, b: B): Bool where A <: HOrd<B>`
- `operator func == <A, B>(a: A, b: B): Bool where A <: HEq<B>`
- `operator func != <A, B>(a: A, b: B): Bool where A <: HEq<B>`

你需要为内置类型实现这些泛型约束，详见 附录 A.2。

布尔运算符仍然是非泛型的:
- `operator func &&(a: Bool, b: Bool): Bool`
- `operator func ||(a: Bool, b: Bool): Bool`

### 3.5 if 表达式
要求与 lab3 中相同。

if 表达式的条件部分必须是 Bool 类型。

对于没有 else 分支的 if 表达式，其类型为 Unit。无论 then 分支的类型为何，其结果都会被丢弃。

对于有 else 分支的 if 表达式，then 分支和 else 分支的类型必须相同，其结果类型即为该类型。

对于朴素的类型判断算法，先观察 then 分支的类型。如果是 Nothing，再观察 else 分支的类型，作为 if 表达式的类型。

### 3.6 while 表达式
要求与 lab3 中相同。

while 表达式的条件部分必须是 Bool 类型。无论 while 的语句块是什么类型都会被抛弃，其结果类型为 Unit。

continue 和 break 语句均只能出现在 while 循环内。你需要对它们进行静态检查，如果出现在其它地方，输出错误。

### 3.7 解释
这里给出一些代码片段，说明如何从上到下、从左到右地推断类型，同时解释阶段分数的原理。

#### 3.7.1 函数的自我递归
使用朴素的算法，一部分递归函数可以用朴素算法正确地被推断出类型，例如:
```
func fib(n: Int64) {
  if n <= 1 {
    return n
  } else {
    return fib(n - 1) + fib(n - 2)
  }
}
```
从上往下，检查:
1. 第一行，得到了 n 的类型是 Int64。
2. 第二行，if 条件的类型是 Bool，符合要求。
3. 第三行，返回 n，类型是 Int64。因此，函数 fib 的返回类型被推断为 Int64，并被记录。
4. 继续向下走，第五行，返回 `fib(n - 1) + fib(n - 2)`。此时，fib 已经被推断为返回 Int64 类型，因此递归调用 `fib(n - 1)` 和 `fib(n - 2)` 的类型也是 Int64。加法运算的结果也是 Int64，与之前推断的返回类型一致。

所以，函数 fib 的类型被正确地推断为 `(Int64) -> Int64`。它可以通过类型检查。

显然，并不是所有的递归函数都能被这种朴素的从上到下的类型推断所处理。例如:
```
func fib2(n: Int64) {
  if n > 1 {
    return fib2(n - 1) + fib2(n - 2)
  } else {
    return n
  }
}
```
虽然这里只是调换了 if 分支的顺序，此时从上往下，检查到第三行时，fib2 的返回类型还没有被推断出来，因此无法确定 `fib2(n - 1)` 和 `fib2(n - 2)` 的类型，算法将会卡住。

Hindley-Milner 类型推断算法可以处理这种情况。这将会是阶段要求 2 (25%) 和综合测试 (15%) 的测试用例。

#### 3.7.2 调用返回类型未知的函数
考虑以下代码:
```
func fun1() {
  42
}

func fun2() {
  fun1() + 1
}
```
从上往下，检查:
1. 第一行，定义了函数 fun1。它没有标注返回类型，因此需要继续检查函数体。
2. 第二行，函数体只有一行，返回 42。因此，fun1 的返回类型被推断为 Int64 并被记录。
3. 第五行，定义了函数 fun2。它也没有标注返回类型，因此需要继续检查函数体。
4. 第六行，函数体只有一行，返回 `fun1() + 1`。此时，fun1 已经被推断为返回 Int64 类型，因此 `fun1()` 的类型是 Int64。加法运算的结果也是 Int64，因此 fun2 的返回类型被推断为 Int64。

因此，我们看到它能被朴素的类型推断算法正确地处理。所以，它可以出现在 40% + 20% 的测试用例中。

再考虑以下代码:
```
func fun2() {
  fun1() + 1
}

func fun1() {
  42
}
```
尽管只是调换了函数定义的顺序，此时从上往下，检查到第二行时，fun1 的返回类型还没有被推断出来，因此无法确定 `fun1()` 的类型，算法将会卡住。

当然，它能被 Hindley-Milner 类型推断算法处理。所以它只会出现在阶段要求 2 (25%) 和综合测试 (15%) 中的测试用例。

## 4. 泛型函数
泛型函数允许你编写与类型无关的代码，从而提高代码的复用性。

### 4.1 类型检查与实例化顺序
泛型函数应当先推断类型，再实例化。

**提示**
为了理解这句话，我们以 C++ 的模板为反例:
```cpp
template<typename T>
T add(T a, T b) {
  return a + b;
}
```
在 C++ 中，模板函数 add 在被调用之前，并不会进行类型检查。只有在调用时，编译器才会根据传入的实参类型实例化出具体的函数版本，并对该版本进行类型检查。雖然没人能保证 T 拥有 + 运算符，但是直到传入的类型真正不支持 + 运算符，编译器才会报错。

仓颉等语言的泛型函数并不是这样设计的。相反地，泛型函数在被调用之前就会被类型检查和推断。这也使得它们的报错信息更加及时和准确。

看一个简单的例子:
```
func identity<T>(x: T) {
  x
}
```
这个函数没有标注返回类型。你应该在调用前就对它进行类型检查和推断:
1. 首先，你会看到它是一个泛型函数，类型参数为 T。
2. 然后，你会检查函数体，它只有一行，返回 x 。变量 x 的类型是 T，因此函数 identity 的返回类型也被推断为 T。
3. 最终，你记录下函数 identity 的类型为 `<T>(T) -> T`。

然后，每次调用该函数时，例如:
```
let a = identity(42)
```
1. 你会看到传入的实参 42 的类型是 Int64。
2. 它对应了泛型参数 T，因此你会实例化出一个具体的函数版本，类型为 `(Int64) -> Int64`。
3. 于是，a 的类型被推断为 Int64。

### 4.2 泛型类型错误
即使是泛型类型也可能出现类型错误。例如:
```
func ignore1<T>(a: T, b: T) {
  b
}
```
在这个例子中，函数 ignore1 的两个参数 a 和 b 都是类型 T。它的类型是 `<T>(T, T) -> T`

如果我们这样调用它:
```
let x = ignore1(42, "hello")
```
如果不看类型检查器，我们会发现返回值其实与参数 a 的类型无关，它总是返回参数 b。然而，类型检查器并不知道这一点。类型检查器会发现:
1. 首先，42 的类型是 Int64，对应泛型参数 T，记录 T = Int64。
2. 然后，"hello" 的类型是 String，也对应泛型参数 T。
3. 但是，此时 T 已经被记录为 Int64，与 String 不一致，因此类型检查器会报错 CALL_ARG_TYPE_MISMATCH。

### 4.3 手动指定泛型参数
在调用泛型函数时，你可以手动指定泛型参数:
```
let a = identity<Int64>(42)
let b = identity<String>("hello")
```
这样，类型检查器会直接使用你指定的泛型参数来实例化函数版本，而不需要从实参类型中推断。

## 5. 泛型与 Option
由于泛型的引入，Option 类型现在有了更优雅的写法。

### 5.1 Some
现在 Some 可以被视为一个泛型函数
```
func Some<T>(value: T): Option<T>
```
它接受一个 T 类型的参数，返回值类型为 Option<T>，为具有值的 Option。

对于标注类型的 Some，我们不再使用 `Option<T>.Some(value)` 的写法，而是直接使用 `Some<T>(value)` 的写法。

### 5.2 None
None 有些特殊，它不能被解释成一个泛型函数，而是一个常量。

不过，Hindley-Milner 类型推断算法允许我们将 None 视为一个多态的常量，其类型可以是任意的 Option<T>，就解决了这个问题。

保证 40% + 20% 的测试用例中，None 只会和 lab3 一样地以 `Option<T>.None` 的形式出现，允许类型推断简单化

剩下的 25% + 15% 的测试用例中，None 可以原样出现，你必须实现 Hindley-Milner 类型推断算法来处理它。例如:
```
let x = None
var y: Option<Int64> = Some(1)
y = x
```

## 6. 泛型类
参见 仓颉语言文档。

## 7. interface
接口用来定义一个抽象类型，它不包含数据，但可以定义类型的行为。一个类型如果声明实现某接口，并且实现了该接口中所有的成员，就被称为实现了该接口。

关于接口的语义，请参见 仓颉语言文档。

njucj 的 interface 与原版仓颉的 interface 有所不同。

**注意**
在原版仓颉中， interface 定义的接口本身也是一个类型。当某个类型实现了某个接口之后，该类型就会成为该接口的子类型。
```
interface Showable {
  func show(): String
}

class Person <: Showable {
  Person(let name: String) {}
  public func show(): String {
    "Person: " + this.name
  }
}

func printShowable(x: Showable) {
  // x 被视作 Showable 类型
  println(x.show())
}
```
我们希望完全避免在这个 Project 中出现一般意义的子类型¹。因此，在这个 Project 中， interface 的语义被修改成 typeclass 的简化版本:interface 不能被当成类型使用，而是只能用来约束泛型参数。自然，也就没有引入子类型了。

回忆 Haskell 中的 typeclass:
```haskell
foo :: Show a => a -> String
foo x = "showing x is " ++ show x
```
在这里， a 表示一个泛型类型变量，而 Show a 则表示对 a 的约束，要求 a 必须实现 Show 这个 typeclass。因此， foo 可以接受任何实现了 Show 的类型作为参数，而无需在类型系统中引入子类型。

在 njucj 中我们采用与 Haskell 类似的设计。上述的代码必须被写成:
```
func printShowable<T>(x: T) where T <: Showable {
  // x 是 T， 同时 T 被 Showable 约束
  println(x.show())
}
```
两种设计有什么不同之处参见 附录 B.1。

> ¹Nothing 除外，它是特殊的，是一切类型的子类型

### 7.1 实现接口
njucj 不支持 extend 接口来动态扩展类的功能。所有的接口实现都必须在类定义中给出。

### 7.2 泛型接口
接口本身也可以是泛型的，例如:
```
interface Comparable<T> {
  func compareTo(other: T): Int64
}
```
实现泛型接口时，可以是偏特化的实现，例如:
```
class MyInt64 <: Comparable<Int64> {
  let v = 0
  func compareTo(other: Int64) {
    v - other
  }
}
```
也可以是泛型的实现，例如:
```
class WrapInt64<T> <: Comparable<T> {
  let v = 0
  func compareTo(other: T) {
    v
  }
}

main() {
  println(WrapInt64<Int64>().compareTo(1))
  println(WrapInt64<String>().compareTo("hello"))
}
```
为了简化，除了内置的 Int64 类型同时满足 `HMul<String, String>` 和 `HMul<Int64, Int64>` 之外我们的测试用例不会让同一个类型实现同一个泛型接口的多个不同偏特化版本。(即，不会出现 `class C <: Comparable<Int64>, Comparable<String>` 这种情况)，因为它相当于支持了重载。

**Bonus**
你可以尝试实现重载功能，并在实验报告中明确说明你完成了 bonus，并说明你的设计与实现思路。

至少需要能处理下面的 interface 才能拿到 bonus 满分:
```
interface Cast<T> {
  func cast(): T
}
```
**提示**:支持重载并不简单。如果你完成了 bonus，请阐述上面的例子难点在哪里。

### 7.3 子接口
在仓颉中接口可以继承一个或多个接口。然而为了简化，我们删去接口继承的功能。

### 7.4 内置接口
内置接口的存在是为了将原先的函数重载语义转换成泛型约束语义，便于 Hindley-Milner 算法。这顺便为我们带来了运算符重载的能力:

同时，测试用例可以去实现这些内置接口，从而让自定义类型支持相应的操作符。

例如，如果一个类实现了 HAdd 接口，那么它的实例就可以使用 + 运算符。
```
class MyInt64 <: HAdd<MyInt64, MyInt64> {
  var v: Int64
  init(v: Int64) {
    this.v = v
  }
  func hadd(other: MyInt64): MyInt64 {
    MyInt64(this.v + other.v)
  }
}

main() {
  let a = MyInt64(10)
  let b = MyInt64(20)
  let c = a + b // 使用了 HAdd 接口的 hadd 方法
  println(c.v) // 输出 30
}
```
所有的内置接口列表请参见 附录 A.2。

### 7.5 默认实现
接口中的方法可以有默认实现。例如:
```
interface Show {
  func show(): String {
    "<something showable>"
  }
}
```
此时，如果一个类实现了 Show 接口，但没有提供 show 方法的实现，那么就会使用接口中提供的默认实现。
```
class Empty <: Show {
  init () {} // 没有实现 show 方法
}

main() {
  let e = Empty()
  println(e.show()) // 也能输出 "<something showable>"
}
```
接口默认实现不得依赖 this， 否则会报错 THIS_SUPER_OUTSIDE_CLASS。

## 8. 泛型约束
如 仓颉文档 所言，泛型约束的作用是在 function、class、interface 声明时明确泛型形参所具备的操作与能力。只有声明了这些约束才能调用相应的成员函数。在很多场景下泛型形参是需要加以约束的。以 id 函数为例:
```
func id<T>(a: T) {
  return a
}
```
开发者唯一能做的事情就是将函数形参 a 这个值返回，而不能进行 `a + 1`， `a.toString()` 等操作，因为它可能是一个任意的类型，比如 `(Bool) -> Bool`，这样就无法与整数相加，同样因为是函数类型，也没有 toString 的方法。而如果这一泛型形参上有了约束，那么就可以做更多操作了。

### 8.1 对函数和类进行约束
对函数和类进行约束时，约束参数出现在函数的 where 子句中
```
interface Say {
  func say(x: String): Unit
}

func sayHi<T>(a: T): Unit where T <: Say {
  a.say("hi")
}
```

### 8.2 对接口进行约束
根据仓颉的表现，一件值得注意的是，泛型约束会递归地蕴含约束要求满足的约束:
```
interface Say {
  func say(x: String): Unit
}

interface Talk<T> where T <: Say {
  func talk(x: T, y: String): Unit
}

// 在这个函数中，由于 Talk<T> 蕴含了 T <: Say， Say 约束需要被递归添加到 T 上
// 因此 T 同时拥有 Talk 和 Say 的能力，无需标出 & Say
// 下面的函数可以正常编译
func talk<T>(a: T, b: T): Unit where T <: Talk<T> /* & Say */ {
  a.talk(b, "hi")
  a.say("hello")
}
```

## 9. Hindley-Milner 类型推断
在 Hindley-Milner 的帮助下，函数参数的类型也可以被推断出来，因此可以允许以下形式的函数定义:
```
// id: <A> (A) -> A
func id(x: _) {
  x
}

// ignore1: <A, B> (A, B) -> B
func ignore1(a: _, b: _) {
  b
}
```
受限于 njucj 的文法，我们无法省略类型标注，因此我们 _ 来表示需要被推断的类型。

关于如何用 Hindley-Milner 推断类型，请复习 课件的内容。

### 9.1 Hindley Milner with Typeclasses
扩展的 Hindley-Milner 类型推断算法可以和 typeclass 协同工作。这也是 Haskell 等语言的设计思路。 15% 的测试点将会考察这一部分实现。

例如，
```
func mymul(a: _) {
  a * 3
}
```
如果使用传统的运算符重载，将会比较难实现类型推断，因此在 小节 3.4 中我们给出了二元运算符的对应 interface。现在，* 运算符对应的函数定义为:
```
operator func * <A, B, C>(a: A, b: B): C where A <: HMul<B, C>
```
因此， mymul 函数的类型可以被推断为:
```
func mymul<A, C>(a: A): C where A <: HMul<Int64, C>
```
关于如何在 Hindley-Milner 算法中支持 typeclass 约束的更多细节，请参见 附录 B.3.

### 9.2 Hindley Milner 与类
规定只有实现了接口的类才能被 Hindley-Milner 类型推断算法处理。

也就是说，下面的代码无法编译通过:
```
class Test1 {
  func test() {
    "111"
  }
}

// 只看形状， x 可以是 Test1
// 但是没有任何 instance 拥有 test 函数，因此 HM 无法推断 x 的类型
func call_test(x: _) {
  x.test()
}
```
同样的，由于 interface 定义不允许声明变量，因此 `a.b` 形式的成员访问也无法被 Hindley-Milner 类型推断算法处理。你应该对此报告 BAD_MEMBER_ACCESS 错误。

关于 Haskell 如何处理这些问题的，请参见 附录 B.2.

## 10. 输入输出
与 lab 3 一样，类型检查和运行将会分为两个命令。 check 只进行类型检查， run 则先进行类型检查，再运行程序。

**样例1**
执行: `cjcj run`
标准输入:
```
interface Show {
  func show(): String
}

class Person <: Show {
  let name: String
  init(name: String) {
    this.name = name
  }
  func show() {
    "Person: " + this.name
  }
}

func show<T>(x: T) where T <: Show {
  x.show()
}

main() {
  let x = show(Person("Alice"))
  println(x)
}
```
标准输出:
```
Person: Alice ()
```

**样例2**
执行: `cjcj check`
标准输入:
```
func main(): Unit {
  let x: Int64 = 10 + true
  println(x)
}
```
标准错误输出:
```
Error at line 2: [ADD_TYPE_MISMATCH]: cannot add 'Int64' and 'Bool'.
```

## 11. 提交
提交方式在智慧南雍平台 (https://lms.nju.edu.cn) 提交实验代码和实验报告
截止日期1/21， 23:59

### 11.1 提交格式
将你的代码文件打包成 `projectB_[YOUR_ID]_[YOUR_NAME].zip`，例如，`projectB_123456789_张三.zip`，文件树如下
```
projectB_[YOUR_ID]_[YOUR_NAME].zip/
├─ report.pdf # 实验报告
├─ cjpm.toml # 仓颉项目文件
├─ cjpm.lock # 仓颉项目文件
├─ src/ # 源代码文件夹
│  ├─ main.cj # 你的代码文件
```

#### 11.1.1 说明
`projectB_[YOUR_ID]_[YOUR_NAME].zip` 文件夹的根目录应该直接包含 report.pdf， cjpm.toml， src/ 文件夹。请不要嵌套额外的文件夹，更不要缺少打包的文件。 请不要将 .git， target 等文件夹打包在内。

在先前的实验中，出现有同学的压缩包格式错误的情况。为了自动评测的方便，推荐使用 linux 下的 zip 命令打包，例如:
```bash
zip -r projectB_123456789_张三.zip report.pdf cjpm.toml cjpm.lock src/
```
提交格式出现错误，可能导致最终分数出现一定的折扣。

### 11.2 实验报告要求
实验报告命名为 report.pdf 并放置在打包的文件夹的根目录。该文件应该是 3~5 页的 PDF。

报告内容应包含以下内容:
1. 你完成的 bonus: 如果你完成了 bonus，请在报告中明确说明你完成了哪些 bonus 内容，并简要描述你的设计与实现思路。请在最前面说明，以便助教快速找到。
2. 代码结构与设计: 简要描述你采用的代码结构、设计思路。你无需描述实验框架已经给出的内容。你如何优雅地处理表达式？如何管理变量作用域？如何封装和抽象，从而保持代码整洁，在实验结束前仍然可以被你阅读？你的代码有没有什么亮点？你可以简要描述你认为比较重要或有趣的设计细节。
3. 遇到的问题与解决方案: 简要描述你在实验过程中遇到的主要问题，以及你是如何解决这些问题的。如果没有遇到问题，可以简要描述你认为的实验难度，和可以改进的地方。
4. 已知 Bug(可选): 如果你的代码中存在你已知但未解决的 Bug，可以简要描述。

### 11.3 代码提示
- 创建一个本地的 Git 仓库来跟踪你的更改是一个不错的选择。你也可以将你的代码上传到 GitHub 等平台的私有仓库。保持提交记录的整洁有利于在代码变得复杂时跟踪你的每一行代码是何时编写、为何编写。
- 适当的编写注释有利于你在一段时间后仍能快速理解你编写的代码。对于复杂的代码，注释也有助于理清自己的思路。
- 在提交代码前，你可以执行 `cjfmt -d .` 来格式化代码。好的代码风格能方便你和助教的阅读。使用合理的、适当的变量名，避免过长的函数和代码块。

### 11.4 学术诚信 Academic Integrity
学术诚信是所有从事学术活动的学生和学者最基本的职业道德底线，本课程将不遗余力的维护学术诚信规范，违反这一底线的行为将不会被容忍。

作业完成的原则:署你名字的工作必须是你个人的贡献。在完成作业的过程中，允许讨论，前提是讨论的所有参与者均处于同等完成度。但关键想法的执行、以及作业文本的写作必须独立完成，并在报告中致谢(acknowledge)所有参与讨论的人。不允许其他任何形式的合作--尤其是与已经完成作业的同学“讨论”。

本课程将对剽窃行为采取零容忍的态度。在完成作业过程中，对他人工作(出版物、互联网资料、其他人的作业等)直接的文本抄袭和对关键思想、关键元素的抄袭，按照 ACM Policy on Plagiarism 的解释，都将视为剽窃。剽窃者成绩将被取消。如果发现互相抄袭行为， 抄袭和被抄袭双方的成绩都将被取消。因此请主动防止自己的作业被他人抄袭。

学术诚信影响学生个人的品行，也关乎整个教育系统的正常运转。为了一点分数而做出学术不端的行为，不仅使自己沦为一个欺骗者，也使他人的诚实努力失去意义。让我们一起努力维护一个诚信的环境。

## A. 附录 A
### A.1 错误代码
#### A.1.1 静态错误代码
- ADD_TYPE_MISMATCH：加法两侧类型不受支持，在 BinaryExpr 处报错。
- SUB_TYPE_MISMATCH：减法两侧类型不受支持，在 BinaryExpr 处报错。
- MUL_TYPE_MISMATCH：乘法两侧类型不受支持，在 BinaryExpr 处报错。
- DIV_TYPE_MISMATCH：除法两侧类型不受支持，在 BinaryExpr 处报错。
- MOD_TYPE_MISMATCH：取余两侧类型不受支持，在 BinaryExpr 处报错。
- EXP_TYPE_MISMATCH：幂运算两侧类型不受支持，在 BinaryExpr 处报错。
- CMP_TYPE_MISMATCH：比较运算两侧的类型不受支持，在 BinaryExpr 处报错。
- EQ_TYPE_MISMATCH：比较两个不一样的类型 + 比较运算两侧的类型不受支持，在 BinaryExpr 处报错。
- NEQ_TYPE_MISMATCH：比较两个不一样的类型 + 比较运算两侧的类型不受支持，在 BinaryExpr 处报错。
- AND_TYPE_MISMATCH：在计算中遇到逻辑与的任一操作数不是 Bool，在不是 Bool 的操作数处报错。
- OR_TYPE_MISMATCH：在计算中遇到逻辑或的任一操作数不是 Bool，在不是 Bool 的操作数处报错。
- NOT_TYPE_MISMATCH：逻辑非的操作数不是 Bool，在 UnaryExpr 处报错。
- NEG_TYPE_MISMATCH：一元取负的操作数不是 Int64，在 UnaryExpr 处报错。
- IF_TYPE_MISMATCH：if 条件表达式的结果不是 Bool，在 if 的条件表达式处报错；或者 if 的结果被使用，但两个分支的类型没有公共基类型，在 IfExpr 处报错。
- WHILE_TYPE_MISMATCH：while 条件表达式的结果不是 Bool，在 while 的条件表达式处报错。
- BREAK_OUTSIDE_LOOP：在非循环体内使用 break，在 JumpExpr 处报错。
- CONTINUE_OUTSIDE_LOOP：在非循环体内使用 continue，在 JumpExpr 处报错。
- ASSIGN_IMMUT_DECL：试图给带有初始化的 let 变量、函数(包括带有初始化表达式的 let 成员变量、成员函数)、类等不可变实体赋值，在 AssignExpr 处报错。
- ASSIGN_TYPE_MISMATCH：试图给变量赋值成不同的类型，在 AssignExpr 处报错。
- UNDEFINED_VAR：试图使用未定义的变量、函数(包括成员变量、成员函数)或类型，在 RefExpr、MemberAccess 或 RefType 处报错。
- DUPLICATED_DEF：试图在同一静态作用域内定义同名变量、函数或类型，在 VarDecl、FuncDecl 或 ClassDecl 处报错。
- DEF_TYPE_MISMATCH：变量定义时，赋值的类型与声明的类型不匹配，在 VarDecl 处报错。
- GLOBAL_NO_INITIALIZER：全局变量定义时缺少初始化表达式，在 VarDecl 处报错。
- FUNC_MISSING_RETURN_TYPE：函数定义中省略了返回类型，在 FuncDecl 处报错。不过由于已经保证了所有可以标注类型的地方都标注了类型，因此这个错误实际上不会出现。
- FUNC_MISSING_BODY：函数定义中缺少函数体，在 FuncDecl 处报错。
- CALLEE_NOT_FUNCTION：试图调用一个既不是类(对象创建)也不是函数(函数调用)的值，在 CallExpr 处报错。
- CALL_ARG_COUNT_MISMATCH：函数调用(包括对象创建)时传入的参数数量与函数定义不符，在 CallExpr 处报错。
- CALL_ARG_TYPE_MISMATCH：函数调用(包括对象创建)时实参类型与形参类型不匹配，在类型不匹配的实参表达式处报错。
- FUNC_USE_MUTABLE_NONLOCAL：试图访问可变非局部变量，在 RefExpr 处报错。
- FUNC_RETURN_TYPE_MISMATCH：函数返回值类型与声明的返回类型不匹配，在 FuncDecl 处报错。
- THIS_SUPER_OUTSIDE_CLASS：在类的方法外使用了 this 或 super 关键字，在 ThisSuperExpr 处报错。
- INTERFACE_NOT_IMPLEMENTED：类没有实现其声明的接口中的所有成员。在 ClassDecl 处报错。
- INTERFACE_METHOD_MISMATCH：类中实现的接口方法与接口声明不匹配。在 FuncDecl 处报错。
- BAD_MEMBER_ACCESS：试图访问不存在的成员变量或方法，比如没有约束的 T。在 MemberAccess 处报错
- TYPE_CANNOT_BE_INFERRED：无法推断出表达式的类型。在使用该表达式的第一个位置报错。

#### A.1.2 动态错误代码
- ADD_OVERFLOW：整数加法结果超出 Int64 表示范围。
- SUB_OVERFLOW：整数减法结果超出 Int64 表示范围。
- MUL_OVERFLOW：整数乘法结果超出 Int64 表示范围。
- DIV_BY_ZERO：整数除法的除数为 0。
- MOD_BY_ZERO：取余运算的除数为 0。
- EXP_NEGATIVE_POWER：指数为负数的幂运算不被支持。
- EXP_OVERFLOW：幂运算结果超出 Int64 表示范围。
- NEG_OVERFLOW：一元取负运算发生溢出。
- UNINITIALIZED_VAR：试图读取未初始化的变量的值。
- ASSIGN_IMMUT_VAR：试图给 let 定义的不可变变量赋值。
- OPTION_IS_NONE：试图在一个值为 None 的 Option 上调用 getOrThrow。
- MEMBER_NOT_INITIALIZED_AFTER_INIT：构造函数执行完毕后，类的成员变量未被初始化。

### A.2 内置接口
“内置实现” 仅供参考，你可以选择不同的实现方式。这些内置接口只是用于让运算符重载进入Hindley-Milner 更容易理解的范围。

#### A.2.1 HAdd<T, R> 异质加法
加法运算符 + 对应的接口。
```
interface HAdd<T, R> {
  func hadd(other: T): R
}
```
**内置实现**
- extend Int64 <: HAdd<Int64, Int64>
- extend String <: HAdd<String, String>

#### A.2.2 HSub<T, R> 异质减法
减法运算符 - 对应的接口。
```
interface HSub<T, R> {
  func hsub(other: T): R
}
```
**内置实现**
- extend Int64 <: HSub<Int64, Int64>

#### A.2.3 HMul<T, R> 异质乘法
乘法运算符 * 对应的接口。
```
interface HMul<T, R> {
  func hmul(other: T): R
}
```
**内置实现**
- extend Int64 <: HMul<Int64, Int64> (整数乘法 e.g. 3 * 4)
- extend String <: HMul<Int64, String> (字符串重复 e.g. "hello" * 3)
- extend Int64 <: HMul<String, String> (字符串重复 e.g. 3 * "hello")

#### A.2.4 HDiv<T, R> 异质除法
除法运算符 / 对应的接口。
```
interface HDiv<T, R> {
  func hdiv(other: T): R
}
```
**内置实现**
- extend Int64 <: HDiv<Int64, Int64>

#### A.2.5 HMod<T, R> 异质取余
取余运算符 % 对应的接口。
```
interface HMod<T, R> {
  func hmod(other: T): R
}
```
**内置实现**
- extend Int64 <: HMod<Int64, Int64>

#### A.2.6 HExp<T, R> 异质幂运算
幂运算符 ** 对应的接口。
```
interface HExp<T, R> {
  func hexp(other: T): R
}
```
**内置实现**
- extend Int64 <: HExp<Int64, Int64>

#### A.2.7 HOrd<T> 异质比较
比较运算符 `<, >, <=, >=` 对应的接口。
```
interface HOrd<T> {
  func hcmp(other: T): Int64
}
```
返回的值小于 0 表示小于，等于 0 表示等于，大于 0 表示大于。

**内置实现**
- extend Int64 <: HOrd<Int64>
- extend String <: HOrd<String>

#### A.2.8 HEq<T> 异质相等比较
相等运算符 `==` 和不等运算符 `!=` 对应的接口。
```
interface HEq<T> {
  func heq(other: T): Bool
}
```
**内置实现**
- extend Int64 <: HEq<Int64>
- extend String <: HEq<String>
- extend Bool <: HEq<Bool>
- extend Unit <: HEq<Unit>

## B. 附录 B
### B.1 子类型与约束的区别
如果我们简单地给 代码 1 加上一个返回值 x，就能看到子类型的问题:
```
interface Showable {
  func show(): String
}

class Person <: Showable {
  Person(public let name: String) {}
  public func show(): String {
    "Person: " + this.name
  }
}

func printShowable(x: Showable) {
  // x 被视作 Showable 类型
  println(x.show())
  return x // printShowable 的返回值类型是 Showable
}

main() {
  let x = Person("111")
  let y = printShowable(x)
  println(y.name)
}
```
在这个例子中，函数 printShowable 的返回值类型是 Showable。然而，在 main 函数中，我们将 printShowable 的返回值赋值给变量 y，并试图访问 y.name。但是，y 的静态类型是 Showable，而 Showable 接口并没有定义 name 成员，因此编译器会报错。

如果我们使用约束而不是子类型，就不会出现这个问题:
```
func printShowable2<T>(x: T) where T <: Showable {
  println(x.show())
  return x // printShowable2 的返回值类型是 T
}

main() {
  let x = Person("111")
  let y = printShowable2(x)
  println(y.name)
}
```

### B.2 Haskell 如何解决成员访问问题
不开语法扩展的 Haskell 中没有 dot notation， 不存在 `a.b` 形式，而是使用 `b a` 形式来得到 record 的成员 b。
```haskell
data Cat = Cat {
  name :: String,
  age :: Int
}

azukisan = Cat { name = "azuki", age = 10 }

main = print (name azukisan)
```
此时，name 是一个函数，类型是 `Cat -> String`。因此不存在成员访问的类型推断问题。

由于同时 Haskell 也不能就地重载函数，因此同一个文件声明的所有 record 在不开扩展的 Haskell 中，都不能有相同的成员名。

### B.3 在 Hindley-Milner 中支持 Typeclasses
这里列出一些参考资料，帮助你从 Hindley-Milner 类型推断扩展到支持 typeclass 约束的 Hindley-Milner 类型推断。
- https://reasonablypolymorphic.com/blog/algorithmic-sytc/
- https://web.cecs.pdx.edu/~mpj/thih/thih.pdf

---

要不要我帮你把这份markdown文档整理成**带目录跳转的版本**，方便你直接查看对应章节？