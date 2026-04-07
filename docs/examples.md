# Examples

## Sample Program

Current sample file `src/data/struct.mn`:

```mn
struct Sample {
    var int a;
    var int b;
}

struct Person {
    var string first_name;
    var string last_name;
    var int age;
    var Sample sample;

    func greet() string {
        return first_name + last_name;
    }
}

func add(int a, int b) int {
    return a + b;
}

func main() int {
    var string[] arr = ["hello", "world"];

    const Person person1 = Person{
        first_name = "Naveen",
        last_name = "Hettiwaththa",
        age = 24,
        sample = Sample{
            a = 100,
            b = 200
        }
    };

    person1.first_name = "hello world";
    person1.sample.a = 500;
    person1.sample.b = person1.sample.a;

    var bool isIt = !true;

    var int total = 100;
    total = total + (100 * 200);

    add(100, 100);
    return total;
}
```

## What This Example Exercises

- Struct declarations with nested struct properties
- Struct initialization expressions
- Member-access assignments, including nested member access
- Array type declaration and array literal parsing
- Unary boolean expression (`!true`)
- Function call expression statements

## Suggested Passing Minimal Example

```mn
func add(int a, int b) int {
    return a + b;
}

func main() int {
    var int[] values = [1, 2, 3];
    var int x = 10;
    x = x + 5;

    add(1, 2);
    return x;
}
```
