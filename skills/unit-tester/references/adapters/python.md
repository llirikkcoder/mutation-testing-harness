# Adapter — Python

Stack: **pytest + ruff + mypy + mutmut** (mutation testing via `mutmut` or `cosmic-ray`).

## Example `.test-pipeline.yaml` fragment

```yaml
stack: python
framework: pytest
test_path_template: "tests/test_{stem}.py"   # src/foo/bar.py → tests/test_bar.py

source_globs: ["src/**/*.py", "az_rag/**/*.py"]
ignore_globs: ["**/migrations/**", "**/__pycache__/**", "**/conftest.py"]

validator:
  lint: "ruff check {file}"
  typecheck: "mypy --no-error-summary {file}"
  test: "pytest {file} -x --tb=short -q"        # {file} substituted with test path
  test_single: "pytest {file}::{test_name} -x --tb=short -q"  # for verifier

mocks:
  http: "pytest-httpx / respx"
  fs: "pyfakefs"
  time: "freezegun"
  db: "pytest-postgresql / testcontainers"

mutator: mutmut       # or "cosmic-ray"

philosophy: |
  - Behavior over implementation. Assert on public return values / raised exceptions / observable side effects.
  - No mocking internals of the SUT's module. Mock only at process boundaries (HTTP, FS, DB, time, RNG).
  - No `assert result` — always assert a value or a shape.
  - No snapshot tests unless the output is genuinely opaque (e.g. rendered PDF bytes).
  - Fixtures via `@pytest.fixture` with narrowest scope that works.
  - Parametrize related cases via `@pytest.mark.parametrize`, one case per row.

coverage_target: branch    # branch coverage, not just line
reviewer_threshold: 9
max_revisions: 3
```

## Validator output parsing

- **ruff** — parse `path:line:col: CODE message` lines
- **mypy** — parse `path:line: error: message [error-code]`
- **pytest** — extract `FAILED tests/... - AssertionError: ...` + short traceback (last 5 frames)

Strip: `warnings.warn`, deprecation notices, `PytestUnknownMarkWarning`, plugin banner lines, coverage summaries.

## Mutation operators (for mutation-planner)

Use these on Python SUT:

| Category | Operator | Example |
|----------|----------|---------|
| Boundary | `>` ↔ `>=`, `<` ↔ `<=` | `if len(x) > 5` → `if len(x) >= 5` |
| Conditional | invert `if`, replace `and`/`or` | `if a and b` → `if a or b` |
| Return | swap None/[] | `return None` → `return []` |
| Literal | shift constant | `timeout = 30` → `timeout = 0` |
| Remove | drop validation/side-effect | comment out `raise ValueError(...)` |
| Args | swap positional args of same type | `merge(a, b)` → `merge(b, a)` |
| Method | swap `.append` ↔ `.extend`, `.get` default | |

## test-verifier command template

```bash
pytest {test_path}::{test_name} -x --tb=line -q --no-header
```

Exit code 0 = pass, 1 = fail (expected during mutation), 2/3/4 = infra error (halt).

## AZ-RAG specifics (from memory [[project-az-rag-stack]])

- LLM: YandexGPT — don't hit it in tests, mock via the client wrapper
- Existing MLflow tracing (`@traced`) — pytest fixture should disable it or route to a dummy tracker
- GxP audit trail (`ChatAuditEvent`) — tests must not write real audit events; use a dummy sink
- Golden dataset lives outside tests — don't confuse eval-tests with unit tests
