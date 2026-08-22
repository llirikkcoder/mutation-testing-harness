# Adapter — TypeScript / React

Stack: **Vitest (or Jest) + ESLint + tsc + StrykerJS** (mutation testing).

## Example `.test-pipeline.yaml` fragment

```yaml
stack: typescript
framework: vitest             # or "jest"
test_path_template: "{dir}/{stem}.test.tsx"    # src/foo/Bar.tsx → src/foo/Bar.test.tsx

source_globs: ["src/**/*.{ts,tsx}"]
ignore_globs: ["**/*.d.ts", "**/*.stories.tsx", "**/node_modules/**"]

validator:
  lint: "eslint --no-error-on-unmatched-pattern {file}"
  typecheck: "tsc --noEmit --pretty false"
  test: "vitest run {file} --reporter=default"
  test_single: "vitest run {file} -t \"{test_name}\" --reporter=default"

mocks:
  http: "msw"
  fs: "memfs"
  time: "vi.useFakeTimers()"
  storage: "vi.stubGlobal('localStorage', ...)"
  router: "MemoryRouter"

mutator: stryker

philosophy: |
  - React Testing Library philosophy. Query by role, name, label — not test-id.
  - Test user-observable behavior. Never assert on component internals or state.
  - Prefer `screen.getByRole` > `getByLabelText` > `getByText` > `getByTestId` (last resort).
  - Assert on rendered output or user-visible side effects, not on function calls (except boundary APIs).
  - `userEvent`, not `fireEvent`, for user interactions.
  - No snapshot tests except for stable large outputs (icons, SVGs).
  - Arrange / Act / Assert visible; blank line between.

coverage_target: branch
reviewer_threshold: 9
max_revisions: 3
```

## Validator output parsing

- **eslint** — parse `path\n  line:col  error  message  rule-id`
- **tsc** — parse `path(line,col): error TSxxxx: message`
- **vitest** — extract `FAIL` blocks; keep `AssertionError` message + trimmed stack

Strip: coverage tables, `[vite]` HMR notices, `stderr` from unrelated workers.

## Mutation operators (for mutation-planner)

| Category | Operator | Example |
|----------|----------|---------|
| Boundary | `>` ↔ `>=`, `<` ↔ `<=` | |
| Conditional | invert `if`, `&&` ↔ \|\| | |
| Return | `return x` → `return null` / `return !x` | |
| JSX | remove `disabled`, remove conditional render | `disabled={!valid}` → `disabled={false}` |
| Handler | drop `onClick`, swap handlers | `onClick={submit}` → `onClick={() => {}}` |
| Effect | comment `useEffect` body | |
| Literal | shift constant | `const MAX = 10` → `const MAX = 1` |

## Notes

- If `framework: jest`, replace `vitest run` with `jest --testPathPattern`.
- With Testing Library, `test-writer` should **never** query by CSS class. Reviewer flags it as `must_fix`.
- StrykerJS is heavy — for per-test mutation planning we don't use Stryker as a runner. Use `test-verifier` with manual Edit + single-test runs. Stryker is only reference for the operator catalog.
