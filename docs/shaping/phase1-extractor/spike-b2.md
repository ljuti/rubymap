# Spike B2: Prism AST node types in method bodies

**Status:** COMPLETE

## Verification

**What was verified:**
- Prism AST node types for all common Ruby control flow and call constructs: `StatementsNode` for method bodies, `IfNode` (covering both `if/elsif/else` and ternary `?:`), `UnlessNode`, `CaseNode`/`WhenNode`/`ElseNode`, `WhileNode`/`UntilNode`/`ForNode`, `AndNode`/`OrNode`, `RescueModifierNode`, `BeginNode` with `RescueNode`
- `CallNode` field names and shapes: `receiver`, `name`, `arguments`, `block`
- Block iteration detection: `CallNode` with `block` field and `name` in LOOP_METHODS
- Receiver chain walk structure for resolving namespaced calls (`Rails.logger.info`)
- Body line measurement from `DefNode` location start/end

**How verified:**
- Empirical AST inspection: 20 representative Ruby method bodies (regular methods, single-expression, begin/end blocks, conditionals, loops, block iterators, logical operators, rescue, ternary) were parsed with Prism and their AST node types and field structures were examined at the REPL
- Results recorded in Q1–Q10 below

**Not verified:**
- Behavior across multiple Prism/Ruby versions (single version snapshot)
- Nested rescue within blocks, lambda-inside-lambda, complex heredoc arguments
- Interactions between multiple control flow constructs in a single expression
- LOOP_METHODS list is based on common Ruby idioms and Enumerable — not an exhaustive enumeration of all block-accepting methods
- Performance on large method bodies or deeply nested ASTs


## Context

We're designing `MethodBodyVisitor` — a class that walks a method's body AST to record calls, count control flow, and measure body lines. Need to verify what Prism node types actually appear.

## Findings

### Q1: Body node type

Method bodies are always `StatementsNode`. Consistent across all 20 test cases — regular methods, methods with single expressions, methods with begin/end blocks.

### Q2: Conditionals

| Ruby | Prism node | Notes |
|------|-----------|-------|
| `if x; a; elsif y; b; else; c; end` | `IfNode` | `subsequent` chain for elsif/else |
| `unless x; a; end` | `UnlessNode` | |
| `case v; when :a; b; when :b; c; else; d; end` | `CaseNode` + `WhenNode` + `ElseNode` | |
| `a ? b : c` | `IfNode` (ternary) | `if_keyword_loc` is nil/empty — **same class as regular if** |
| `a if b` | `IfNode` (modifier) | same class, `if_keyword_loc` populated |

**Key insight:** Ternary `?:` IS `IfNode` — not a separate node type. Distinguish by checking `node.if_keyword_loc` is nil.

### Q3: Loops

| Ruby | Prism node |
|------|-----------|
| `while x; a; end` | `WhileNode` |
| `until x; a; end` | `UntilNode` |
| `for i in coll; a; end` | `ForNode` |

### Q4: Block iteration (.each, .map, etc.)

`items.each do \|item\| process(item); end` → `CallNode` with `name: :each`, `block: BlockNode`

The `BlockNode` has `parameters` (BlockParametersNode) and `body` (StatementsNode). Detection: `node.is_a?(CallNode) && LOOP_METHODS.include?(node.name.to_s) && node.block`.

### Q5: Logical operators

`x && y \|\| z` → `OrNode(left: AndNode(left: CallNode(x), right: CallNode(y)), right: CallNode(z))`

Nodes: `AndNode`, `OrNode`.

### Q6: Ternary

Covered in Q2 — ternary is `IfNode` with nil `if_keyword_loc`.

### Q7: Rescue

| Ruby | Prism node |
|------|-----------|
| `dangerous rescue fallback` | `RescueModifierNode` with `rescue_expression` |
| `begin; a; rescue E => e; b; end` | `BeginNode` with `statements` + `rescue_clause` (RescueNode) |

### Q8: All node types encountered across 20 test methods

```
StatementsNode, CallNode, ArgumentsNode, IfNode, UnlessNode, CaseNode, WhenNode,
ElseNode, WhileNode, UntilNode, ForNode, AndNode, OrNode, RescueModifierNode,
BeginNode, RescueNode, BlockNode, BlockParametersNode, ParametersNode,
RequiredParameterNode, LambdaNode, LocalVariableReadNode, LocalVariableTargetNode,
ConstantReadNode, SymbolNode, StringNode, IntegerNode, TrueNode, AssocNode,
KeywordHashNode
```

### Q9: CallNode fields

```
node.receiver    → Prism::Node or nil (nil = self call)
node.name        → Symbol (e.g., :save, :has_many)
node.arguments   → ArgumentsNode (has .arguments array)
node.block       → BlockNode or nil
```

### Q10: Body lines

`def_node.location.start_line` and `def_node.location.end_line` are available. Simplest: `end_line - start_line`. Can also use `body.location` for just the body (excluding def/end lines).

## Visitor Design (confirmed by spike)

### Node types → action:

| Node type | Action | Reason |
|-----------|--------|--------|
| `CallNode` | Record call info; if name in LOOP_METHODS + has block → count as loop | Q4 |
| `IfNode` | If `if_keyword_loc` nil → branch only; else → branch + conditional | Q2 (ternary vs regular) |
| `UnlessNode` | Branch + conditional | Q2 |
| `CaseNode` | Branch + conditional | Q2 |
| `WhileNode`, `UntilNode`, `ForNode` | Loop | Q3 |
| `AndNode`, `OrNode` | Branch | Q5 |
| `RescueModifierNode` | Branch | Q7 |
| `BeginNode` | Branch (if has rescue_clause) | Q7 |
| `StatementsNode`, `ArgumentsNode`, `ElseNode`, `WhenNode`, `RescueNode`, `BlockNode`, `BlockParametersNode`, `ParametersNode`, `RequiredParameterNode`, `LocalVariableReadNode`, `LocalVariableTargetNode`, `AssocNode`, `KeywordHashNode`, `LambdaNode` | Recurse only | Structure, not control flow |
| All leaf types (Symbol, String, Integer, Float, True, False, Nil, ConstantRead, ConstantPath, etc.) | No-op | Terminal nodes |

### LOOP_METHODS

```
%w[each map collect select reject find detect reduce inject
   times upto downto step each_with_index each_with_object
   group_by partition sort_by flat_map]
```

### Receiver chain resolution (R6)

Walk up the receiver chain:
```
bar.save           → receiver = nil → ["self"]
bar.foo.save       → receiver = CallNode(name=:foo, receiver=CallNode(name=:bar)) → ["self", "bar", "foo"]
Rails.logger.info  → receiver = CallNode(name=:logger, receiver=ConstantReadNode(name=:Rails)) → ["Rails", "logger"]
```
