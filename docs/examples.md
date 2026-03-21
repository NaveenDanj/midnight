# Examples

## Sample Program

Current sample file `src/tests/test1.mn`:

```mn
const float PI = 3.14;

struct Person {
    var string first_name;
    var string last_name;

    func greet() string {
        return first_name + last_name;
    }
}

func main2(int a, int b) bool {
    var int a = 10;
    a = 1 * 100;
    return true;
}

func main() int {
    const string first_name = "Naveen";
    const string last_name = "Hettiwaththa";
    const string fullName = first_name + " " + last_name;
    var bool flag = false;

    flag = false;

    while (main2(10, 20)) {
        var bool total = false;
        var bool isTrue = false;
    }

    if (flag) {
        var int x = 10;
    } else {
        var int y = 0;
    }

    return 100.20;
}

func add(int a, int b) int {
    return a + b;
}
```

## What This Example Exercises

- Struct declaration with methods and properties
- Function declaration and call
- Typed variable declarations
- Reassignment semantics
- While/if control flow
- String concatenation and numeric arithmetic

## Why It Currently Fails

- `greet()` references `first_name` and `last_name` as bare identifiers.
- Semantic analyzer does not yet support struct receiver/member scope resolution.
- Runtime exits with `UndefinedVariable` during semantic analysis.

## Suggested Passing Minimal Example

```mn
func add(int a, int b) int {
    return a + b;
}

func main() int {
    var int x = 10;
    x = x + 5;

    if (true) {
        var int y = 2;
    } else {
        var int z = 3;
    }

    while (false) {
        var int never = 0;
    }

    add(1, 2);
    return x;
}
```
