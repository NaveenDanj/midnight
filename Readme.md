# Building My Own Programming Language (Dev Log #1)

### Or: How I Accidentally Started Writing a Compiler

Every programmer eventually reaches a point where they look at existing programming languages and think:

> *“How hard could it be to make my own?”*

This is usually followed by a sequence of events involving **tokenizers, ASTs, existential dread, and an unhealthy number of compiler errors**.

Recently I decided to begin writing my own programming language (currently living inside a folder called `midnight`). This dev log documents what I’ve built so far, the mistakes I made, the problems I solved, and the lessons learned along the way.

And yes — this includes fighting Zig’s error system at 2AM.

---

# Phase 1: The Lexer — Teaching the Language to Read

Every compiler starts with the same fundamental problem:

> The computer has no idea what your code means.

Before we can interpret syntax or semantics, we need to **convert raw text into tokens**. This process is called **lexical analysis**.

For example, the code:

```
x + 10
```

needs to become something like:

```
Identifier("x")
Plus("+")
IntegerLiteral("10")
```

So the first major component I built was the **lexer**.

The lexer scans characters and produces tokens such as:

* identifiers
* numbers
* operators
* keywords
* parentheses

Essentially, it answers the question:

> “What *things* exist in this source code?”

This stage went relatively smoothly. The biggest challenge here was designing the **token system** in a way that the parser could easily consume later.

Each token stores:

* its **kind** (identifier, integer literal, etc.)
* its **lexeme** (the original text)
* potentially position data (for error messages later)

At this point the language could finally *read* code.

Progress!

---

# Phase 2: The Parser — Turning Tokens into Meaning

If the lexer answers:

> “What words are here?”

The parser answers:

> “What do these words *mean together*?”

This is where things get interesting.

I implemented a **Pratt parser** to handle expressions. Pratt parsers are extremely elegant for expression parsing because they handle **operator precedence naturally**.

Instead of complicated grammar trees, you define **precedence levels** like:

* lowest
* addition/subtraction
* multiplication/division
* etc.

Then the parser decides whether to continue parsing based on the precedence of the next operator.

For example:

```
1 + 2 * 3
```

correctly becomes:

```
Binary(+)
 ├─ 1
 └─ Binary(*)
    ├─ 2
    └─ 3
```

instead of the cursed alternative:

```
Binary(*)
 ├─ Binary(+)
 │  ├─ 1
 │  └─ 2
 └─ 3
```

Which would be mathematically illegal in most countries.

---

# Phase 3: Designing the AST

To represent parsed code, I built an **AST (Abstract Syntax Tree)**.

Current expression types include:

* Binary expressions
* Integer literals
* Float literals
* Boolean literals
* String literals
* Identifiers

The core structure looks something like this:

```
Expr
 ├─ Binary
 ├─ Identifier
 ├─ IntLiteral
 ├─ FloatLiteral
 ├─ BoolLiteral
 └─ StringLiteral
```

Binary expressions store:

```
left
operator
right
resolvedType (for later semantic analysis)
```

The `resolvedType` field is intentionally nullable because **type checking hasn’t happened yet**.

Future-me will deal with that problem.

Present-me just builds trees.

---

# Phase 4: Allocating AST Nodes

AST nodes are allocated using the parser’s allocator:

```zig
const expr = try self.allocator.create(Expr);
```

This is simple but it introduces one very important Zig concept:

**allocators return errors**.

Specifically:

```
error.OutOfMemory
```

This will become relevant later.

And by later I mean *very soon*.

---

# Phase 5: Zig vs. Recursive Error Sets

While wiring the parser together I ran into a classic Zig compiler message:

```
error: unable to resolve inferred error set
```

Which roughly translates to:

> “You created recursive functions with inferred errors and now the compiler is confused.”

My functions originally returned:

```
!*Expr
```

Zig tries to infer what errors could occur.

But the parser functions call each other recursively:

```
parseExpr
  -> parsePrecedence
      -> parsePrimary
          -> parseExpr
```

So the compiler couldn't determine the final error set.

The fix was simple but important:

**Explicitly define the error set.**

Instead of:

```
!*Expr
```

I changed everything to:

```
ParserError!*Expr
```

This gave Zig a concrete set of possible errors and the compiler immediately stopped complaining.

Lesson learned:

> When recursion enters the chat, inferred error sets leave the chat.

---

# Phase 6: The `OutOfMemory` Plot Twist

After fixing the error inference problem, another error appeared:

```
expected ParserError, found error{OutOfMemory}
```

This came from the allocator:

```
try self.allocator.create(Expr)
```

Because allocation can fail.

The parser functions allowed `ParserError`, but **not `OutOfMemory`**.

So the compiler politely informed me that reality exists.

The solution was to extend the parser error set:

```
pub const ParserError = error{
    TokenNotFound,
    UnExpectedEndOfLine,
    UnExpectedToken,
    UnexpectedEndOfFile,
    OutOfMemory,
};
```

Now allocation errors can propagate correctly.

Lesson learned:

> Memory is not infinite.
> Zig makes sure you remember this.

---

# Phase 7: Parsing Identifiers

Initially the parser only handled literals and binary expressions.

Which meant something like:

```
x + 10
```

would fail because `x` wasn’t recognized.

The fix was adding an **Identifier expression** to the AST:

```
IdentifierExpr {
    name: []const u8,
    resolvedType: ?Type
}
```

Then integrating it into `parsePrimary`.

Now expressions like:

```
x + y * 10
```

produce a clean AST.

Identifiers will later become:

* variables
* function names
* struct members
* etc.

For now, they’re just names.

But they’re important names.

---

# Phase 8: Parentheses Support

Expressions like:

```
(1 + 2) * 3
```

require grouping support.

The parser handles this with:

```
if (self.match(.LParen)) {
    const expr = try parseExpr(self);
    _ = try self.expect(.RParen);
    return expr;
}
```

This allows nested expressions inside parentheses.

Which means the language now understands the universal programmer reflex:

> “If something is confusing, add parentheses.”

---

# Current Capabilities

Right now the language can parse expressions like:

```
x + 5
3 * (2 + 7)
true
10 + y * 3
```

The AST is constructed correctly with precedence rules.

Which means the core **expression parser is functional**.

This is a huge milestone in language development.

---

# What I Learned So Far

Building a language teaches you things that normal programming rarely does:

### 1. Parsing is both elegant and terrifying

At first it feels abstract.

Then suddenly you’re building syntax trees and everything makes sense.

Then you add one feature and everything breaks again.

---

### 2. Zig’s error system is brutally honest

You cannot ignore errors.

You cannot pretend memory allocation never fails.

You cannot hide recursive error inference mistakes.

Zig simply says:

> “Fix it.”

And honestly, that’s kind of refreshing.

---

### 3. Compilers are just programs that read other programs

Once you understand that idea, everything becomes less mysterious.

A compiler is essentially:

```
text
  -> tokens
  -> syntax tree
  -> semantic analysis
  -> code generation
```

Right now I’m finishing step 2.

---

# What Comes Next

The next milestones for the language will likely be:

* variable declarations
* function calls
* member access
* arrays and indexing
* semantic type checking
* IR or bytecode generation

In other words:

> The fun is just getting started.

---

# Final Thoughts

Writing a programming language is one of the most educational projects a developer can undertake.

It forces you to understand:

* parsing
* memory management
* language design
* compiler architecture

And it also forces you to accept that **the compiler will win every argument**.

But when things finally compile and the AST looks correct…

It’s a special kind of satisfaction.

More dev logs coming soon.

Assuming the parser doesn’t start another rebellion.
