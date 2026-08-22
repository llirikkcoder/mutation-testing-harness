# Mutation strategies (per-test)

The mutation-planner reads this file. Purpose: build **one targeted mutation per test case**, not a shotgun sweep.

## Core principle

For a test `T` that protects behavior `B`, the mutation `M` must:

1. Break `B` in the smallest possible edit
2. Cause exactly `T` to fail
3. Not break the type-checker (would confuse `test-verifier`)
4. Be **reversible via a single Edit call** (old string ↔ new string, exact match)

If no such M exists, mark the test `catchable: false`. That's a signal the test is a tautology.

## Catalog (language-agnostic)

### 1. Boundary flips
Best for range / size / threshold tests.

- `x > n` ↔ `x >= n` ↔ `x < n`
- `len(x) > 0` → `len(x) >= 0`
- `i <= last` → `i < last`

### 2. Conditional inversion
Best for branch tests.

- `if cond:` → `if not cond:`
- `if a and b:` → `if a or b:`
- Remove `else` branch
- Swap ternary arms: `x if p else y` → `y if p else x`

### 3. Return-value swap
Best for happy-path tests.

- `return x` → `return None` (or `null`, `undefined`, `false`, `[]`)
- `return True` → `return False`
- `return x + y` → `return x - y`

### 4. Statement removal
Best for validation / side-effect tests.

- Comment out `raise ValueError(...)` → validation test should fail
- Comment out `emit('event')` / `logger.info(...)` → event-test should fail
- Comment out `disabled = true` in JSX → UI-state test should fail
- Comment out `.append(item)` / `.push(item)` → mutation test should fail

### 5. Literal shift
Best for tests that assert specific numbers / strings.

- `timeout = 30` → `timeout = 0`
- `retries = 3` → `retries = 0`
- `"error"` → `"success"` (only if visible in output)

### 6. Argument swap
Best for order-sensitive tests.

- `merge(a, b)` → `merge(b, a)` (only if both are same type)
- `subtract(x, y)` → `subtract(y, x)`

### 7. Operator swap
Best for arithmetic / comparison tests.

- `+` ↔ `-`, `*` ↔ `/`, `&&` ↔ `||`, `==` ↔ `!=`

### 8. Method-call swap
Best for collection-behavior tests.

- `.append(x)` → `.extend(x)` (list vs iterable)
- `.get(key, default)` → `.get(key)` (drops default)
- `.strip()` → `.rstrip()`
- React: `useState(0)` → `useState(1)` (initial state)

## Anti-patterns (skip these mutations)

- **Whitespace / formatting** — never a test signal
- **Import order** — never a test signal
- **Rename local variable** — semantically identical
- **Add `# type: ignore`** — hides typecheck, not behavior
- **Mutations that make the SUT not compile** — verifier can't proceed

## Choosing "the" mutation for a test

Ask: **"What is the one line I could delete or invert to make this test fail?"**

If multiple candidates, prefer:
1. Removal over addition (cleaner revert)
2. Boundary/conditional over literal (more common bug pattern)
3. Public-surface over private-helper (test-relevant)

## When to skip

Return `catchable: false` if:
- Test only asserts `expect(result).toBeDefined()` or `assert result is not None` (tautology — any non-None mutation passes it)
- Test asserts on a mock call that isn't actually called by the SUT (dead assertion)
- SUT has no logic to mutate for this test (pure passthrough)

The orchestrator will route these back to test-writer with `feedback: "test-case {name} — tautology, strengthen assertion"`.

## Sequential execution reminder

The verifier applies mutations **one at a time** to the SUT and reverts before the next. Ordering doesn't usually matter, but **do not** plan two mutations to the same line — the second Edit would fail exact-match.
