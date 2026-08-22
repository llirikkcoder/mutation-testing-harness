# `.test-pipeline.yaml` — full schema

Lives at repo root. Read by the orchestrator (unit-tester skill), passed as fragments to sub-agents.

## Complete example

```yaml
# Stack identity — picks the right adapter
stack: python                      # python | typescript | scala | go | rust
framework: pytest                  # framework name inside the stack

# Where tests live. {stem} = source filename without ext, {dir} = source directory
test_path_template: "tests/test_{stem}.py"

# What to scan (commit-driven mode uses these)
source_globs: ["src/**/*.py", "az_rag/**/*.py"]
ignore_globs: ["**/migrations/**", "**/__pycache__/**", "**/conftest.py", "**/*.pyi"]

# Validator — commands the test-validator agent runs.
# Placeholders: {file} = test file path, {test_name} = single test name
validator:
  lint: "ruff check {file}"
  typecheck: "mypy --no-error-summary {file}"
  test: "pytest {file} -x --tb=short -q"
  test_single: "pytest {file}::{test_name} -x --tb=short -q"
  run_all: false                  # stop at first failing stage (default true)

# Where to mock. Free-form; the writer reads this to know boundaries.
mocks:
  http: "pytest-httpx / respx"
  fs: "pyfakefs"
  time: "freezegun"
  db: "pytest-postgresql"
  llm: "src/az_rag/llm/_test_double.py"   # project-specific

# Mutator name (used only as a reference; actual mutations planned by mutation-planner)
mutator: mutmut

# Philosophy — passed verbatim to writer and reviewer. Overrides defaults.
philosophy: |
  - Behavior over implementation.
  - Mock at process boundaries only.
  - Full-equality asserts when possible.
  - No snapshot tests.
  - Parametrize when Arrange is identical.
  - Freeze time via freezegun for any time-dependent SUT.
  - Never call YandexGPT in tests — use the test double at src/az_rag/llm/_test_double.py.

# Coverage / quality knobs
coverage_target: branch           # branch | line
reviewer_threshold: 9             # 1–10, minimum reviewer avg to pass
max_revisions: 3                  # reviewer iterations
max_mutation_attempts: 3          # verifier retries with new tests

# Cost / speed
skip_mutations: false             # if true, pipeline stops after validator
model_overrides: {}               # {planner: sonnet} etc — rare
```

## Field reference

| Field | Required | Default | Notes |
|-------|----------|---------|-------|
| `stack` | ✓ | — | Selects adapter reference |
| `framework` | ✓ | — | Free-form label |
| `test_path_template` | ✓ | — | `{stem}` and `{dir}` supported |
| `source_globs` | ✓ | — | Only needed for `/test-commits` |
| `ignore_globs` | ✗ | `[]` | Applied to worklist filtering |
| `validator.lint` | ✗ | (skipped) | Skip if empty |
| `validator.typecheck` | ✗ | (skipped) | Skip if empty |
| `validator.test` | ✓ | — | Full-file test run |
| `validator.test_single` | ✗ | falls back to `test` | Needed for mutation verifier |
| `validator.run_all` | ✗ | `true` | If `false`, stop at first stage failure |
| `mocks` | ✗ | `{}` | Free-form; writer reads keys |
| `mutator` | ✗ | `"generic"` | Label only |
| `philosophy` | ✗ | (see writer-philosophy.md) | Overrides defaults verbatim |
| `coverage_target` | ✗ | `branch` | |
| `reviewer_threshold` | ✗ | `9` | 1–10 |
| `max_revisions` | ✗ | `3` | |
| `max_mutation_attempts` | ✗ | `3` | |
| `skip_mutations` | ✗ | `false` | Fast mode |
| `model_overrides` | ✗ | `{}` | Per-agent model override |

## Where to keep it

- **Repo root** — `.test-pipeline.yaml`. Committed to git.
- **Local overrides** — `.test-pipeline.local.yaml` (git-ignored). Merged on top.

## Migration from Habr article's setup

The article used a single `.test-pipeline.yaml` per project with:
- mocks location, store location
- Jest/Vitest choice
- project conventions
- RTL philosophy

Same idea, extended with explicit validator commands, mutator, and quality knobs.
