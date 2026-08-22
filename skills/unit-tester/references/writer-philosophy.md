# Writer philosophy

Rules the `test-writer` must follow. Rules the `test-reviewer` scores against. Overridable per project via `.test-pipeline.yaml → philosophy`.

## The one rule

**Test behavior, not implementation.**

- Behavior = what the SUT does for its caller (return values, thrown errors, emitted events, visible side effects)
- Implementation = how it does it (which private method it calls, in what order, with which intermediate variables)

If a legitimate refactor of the SUT breaks the test without changing behavior, the test was implementation-coupled. Rewrite it.

## The nine sub-rules

### 1. One `test`/`it` per behavior
- Test name = intent in plain English (`empty_input_returns_none`, not `test_1`)
- If a test has "and" in its name and both parts are independent, split it

### 2. Arrange → Act → Assert
```python
def test_empty_input_returns_none():
    # Arrange
    processor = Processor(config={})

    # Act
    result = processor.run([])

    # Assert
    assert result is None
```
Blank line between sections. Reviewer flags missing structure.

### 3. Assertion strength
Weak → strong:

- `assert result` → tautology, catches nothing
- `assert result is not None` → catches None-return mutation only
- `assert len(result) == 3` → catches count mutations
- `assert result == [1, 2, 3]` → catches content + count + order mutations ✓

**Prefer full equality** when the expected value is small. Prefer field-level equality for large objects (`assert result.status == "ok" and result.items == [...]`).

### 4. Mock at boundaries, never internally
Boundaries: HTTP, filesystem, DB, time, RNG, environment variables, LLM APIs, message queues.

Not boundaries: helper functions inside the SUT's own module, private methods, imported utilities.

If forced to mock an internal helper to make the test pass, that's a signal the SUT needs splitting — flag it in `unimplemented_cases.notes`.

### 5. Deterministic
- `freeze_time("2026-01-01")` for time-dependent SUT
- Seed RNG explicitly if the SUT uses one
- No network calls, ever
- No filesystem writes to real paths (use `tmp_path` fixture)

### 6. No shared mutable state
- Fixtures scoped to `function` unless there's a proven perf need
- Never mutate module-level globals inside a test
- Never rely on test order

### 7. No comments explaining what the test does
The test name is the doc. If you need a comment, rename the test.

Exception: comments explaining a *workaround* for a framework quirk. Prefix with `# workaround:`.

### 8. Skip snapshot tests
Snapshot tests fail on formatting changes and pass on real regressions. They are "always green, always noisy".

Exception: stable opaque binary output (rendered PDF bytes, image SHA). Then justify in a comment.

### 9. Parametrize related cases
Instead of five near-identical tests, use one parametrized test with a row per case:

```python
@pytest.mark.parametrize("input,expected", [
    ([], None),
    ([1], 1),
    ([1, 2, 3], 6),
])
def test_sum(input, expected):
    assert sum_or_none(input) == expected
```

Reviewer approves. But: if cases have different `Arrange` sections, keep them separate — parametrize only when Arrange is identical.

## Anti-patterns (must_fix on sight)

- `expect(mockFn).toHaveBeenCalled()` as the only assertion (checks nothing about behavior)
- `assert True` / `expect(true).toBe(true)` (tautology)
- Comparing datetime with `datetime.now()` (flaky)
- `try/except` inside a test to swallow errors (fails silently)
- Multiple `assert`s in one test with no context (which one failed?)
- `pytest.mark.skip` without a reason
- Tests longer than 40 lines (probably testing multiple things)

## Reviewer's default rubric

Each dimension scored 1–10:

| Dimension | 10 | 5 | 1 |
|-----------|----|---|---|
| Behavior focus | Every assertion is user-observable | Half check implementation | All check internals |
| Assertion strength | Full-equality, catches all mutations | Length/type checks | `assert result` |
| Naming | Intent in prose | Function name paraphrased | `test_1` |
| Structure | AAA clean, no shared state | AAA implicit | One-liner, no arrange |
| Philosophy | Matches all sub-rules | Missing 1–2 | Snapshot spam, mocks everywhere |
| Plan coverage | All plan cases + edge notes | 80%+ | Half missing |

Average ≥ 9 = approved. Below = revise.
