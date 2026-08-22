---
name: unit-tester
description: Agent-driven unit-test pipeline. Given one source component (SUT) and a project .test-pipeline.yaml, orchestrates 6 sub-agents (planner → writer → reviewer → validator → mutation-planner → verifier) with feedback loops, targeting 100% mutation catch rate. Universal adapter architecture — stack-specific commands live in .test-pipeline.yaml. Use when the user says "write tests for X", "test this component", or via the /test-component and /test-commits commands.
---

# unit-tester

**What this skill is:** the orchestrator for a 6-agent testing pipeline inspired by the architecture in [Habr article 1020066](https://habr.com/ru/articles/1020066/) (Pavliashik). You call the agents in order, wire the feedback loops, and hand results back to the user.

**What this skill is not:** a test-writing agent itself. You **only orchestrate** — the actual thinking happens inside the sub-agents.

## The 6 agents

| # | Agent | Model | Role |
|---|-------|-------|------|
| 1 | `test-planner` | Opus | Reads SUT, produces test-plan (cases with intent) |
| 2 | `test-writer` | Opus | Implements plan → test file. Also revises on feedback. |
| 3 | `test-reviewer` | Opus | Scores 1–10, requires ≥9. Max 3 iterations. |
| 4 | `test-validator` | Sonnet | Runs lint/type/test commands. Compact error report. |
| 5 | `mutation-planner` | Opus | Per-test targeted mutation plan for the SUT. |
| 6 | `test-verifier` | Sonnet | Sequential mutate → run → restore. 100% catch rate. |

`commit-analyzer` (Sonnet) is a separate agent used only in commit-driven mode (see /test-commits).

## Prerequisites

Before starting, **verify**:

1. Working directory is a git repo.
2. `.test-pipeline.yaml` exists at repo root. If missing, tell the user to run `/test-init` and stop.
3. The SUT path exists.

Load the pipeline config:

```
Read <repo>/.test-pipeline.yaml
```

The relevant fragments to pass to each agent:
- planner: `stack`, `philosophy`, `coverage_target`
- writer: `stack`, `framework`, `mocks`, `test_path_template`, `philosophy`
- reviewer: `philosophy`
- validator: `validator` (lint/typecheck/test commands)
- mutation-planner: (no config needed; reads mutation-strategies.md)
- verifier: `validator.test` (needs `{file}` and `{test_name}` placeholders)

## The pipeline (single component)

```
             ┌──────────────────────── revise ─────────────────────────┐
             │                                                          │
             ▼                                                          │
  planner ─► writer ─► reviewer ──approved──► validator ──pass──► mutation-planner ─► verifier
                          │                       │                                        │
                          │                       │                                        │
                          └──iteration<3, <9──────┘                                        │
                                                  │                                        │
                                                  └──fail──► writer (fix-only revision) ◄─┘
                                                                                           │
                                                                                       surviving
                                                                                       mutations
                                                                                           │
                                                                                           ▼
                                                                                       writer
                                                                                    (strengthen)
```

### Step-by-step

**1. Plan**

Delegate to `test-planner` via Agent tool. Pass `sut_path`, `pipeline_config`, and `existing_tests_path` (if any).

If `plan.cases == []` and `skip_reason` is set → surface to user and stop. Don't force tests on trivial passthroughs.

If `plan.risks` names an untestable design → surface to user, ask whether to proceed anyway (partial tests) or refactor first.

**2. Write (iteration 1)**

Delegate to `test-writer` in fresh-write mode. Pass `plan`, `sut_path`, `pipeline_config`, `target_test_path` (derive from `pipeline_config.test_path_template`).

**3. Review loop (max 3 iterations)**

Loop:
- Delegate to `test-reviewer`. Pass `test_path`, `sut_path`, `plan`, `pipeline_config`, current `iteration`.
- If `approved: true` → break, proceed to validate.
- If `iteration == 3` and `escalate: true` → surface to user, ask approve-as-is or abort.
- Else → delegate to `test-writer` in revision mode with `feedback: reviewer.needs_revision`. Increment iteration.

**4. Validate**

Delegate to `test-validator`. Pass `test_path`, `pipeline_config`.

- If `passed: true` → proceed.
- If `passed: false` and validator errors are mechanical (lint/type/syntax) → delegate to `test-writer` revision with `feedback: validator.errors`, re-run validator. Cap at 2 fix cycles.
- If still failing after fixes → surface, stop.

**5. Plan mutations**

Delegate to `mutation-planner`. Pass `test_path`, `sut_path`.

If `mutations == []` (all tests are tautologies) → weak test file, send back to writer for strengthening. Cap at 1 retry.

**6. Verify mutations (loop, max 3 attempts)**

Delegate to `test-verifier`. Pass `mutation_plan`, `pipeline_config`, `max_attempts`.

- If `success: true` (100% catch rate) → done, report to user.
- If `success: false` and `attempts_remaining > 0` → delegate to `test-writer` revision with `feedback: {surviving_mutations, mutation_plan}`, then re-run verifier. Increment attempt.
- If `escalate: true` → surface surviving mutations to user, ask approve-as-is or abort.
- If `pipeline_halt: true` → SUT corruption. Halt everything, restore from git, tell the user immediately.

## Interactive commit mode

When invoked as `/test-commits`:

1. Ask the user for `from_ref` (default: last tag or `HEAD~10`).
2. Delegate to `commit-analyzer`. Get the worklist.
3. **For each item in worklist** (sorted by class: new_component → significant_change → trivial):
   - Print: `[{i}/{n}] {path} — {class} ({diff_summary}) — existing_test: {existing_test or "none"}`
   - Ask the user: `[a]pprove / [s]kip / [q]uit`
   - On `a` → run the full pipeline for this component (see above)
   - On `s` → skip, log, continue
   - On `q` → stop, print summary

## Output to user

After each component completes, print a compact summary:

```
✅ src/foo.py
   plan: 8 cases, complexity=medium
   writer: 8 cases, 0 unimplemented
   reviewer: 9.2/10 approved after 1 revision
   validator: pass (2.1s)
   mutations: 8 planned, 8 caught (100%)
   → tests/test_foo.py
```

At the end of commit mode, print totals: approved / skipped / failed, catch-rate average, total wall-clock.

## Cost & speed knobs

- **Skip mutation stage** if `pipeline_config.skip_mutations: true` (fast mode for prototyping)
- **Reviewer threshold** overridable via `pipeline_config.reviewer_threshold` (default 9)
- **Max revisions** overridable via `pipeline_config.max_revisions` (default 3)
- **Model overrides** per stage via `pipeline_config.model_overrides` (rare; the defaults are calibrated)

## Universal, not hardcoded

The pipeline is **stack-agnostic**. All stack-specific behavior lives in `.test-pipeline.yaml`:
- `stack` (python | typescript | scala | go | ...)
- `validator.{lint,typecheck,test}` commands
- `test_path_template` (e.g. `tests/test_{stem}.py`)
- `mocks` locations

Read `references/adapters/{stack}.md` before starting if you're unsure how the stack's tools behave.

## References

- [[references/pipeline-config]] — full schema of `.test-pipeline.yaml`
- [[references/adapters/python]] — pytest + mutmut/cosmic-ray + ruff + mypy specifics
- [[references/adapters/typescript]] — vitest/jest + stryker + eslint + tsc specifics
- [[references/mutation-strategies]] — per-test mutation catalog
- [[references/writer-philosophy]] — behavior-focus, AAA, assertion-strength rules
- [[templates/.test-pipeline.yaml]] — starter config

## Do not

- Write tests yourself. You orchestrate; the agents write.
- Read the SUT for reasons other than routing decisions. Agents read.
- Combine agent stages "to save tokens". Isolation is the point — each agent has a clean context.
- Silently skip mutation stage. If skipping, print `mutations: SKIPPED (fast mode)` so the user knows.
