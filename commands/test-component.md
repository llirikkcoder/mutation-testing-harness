---
description: Запустить agent-driven test pipeline для одного компонента (SUT). Usage — /test-component <path> [--skip-mutations]
---

# /test-component

Полный проход pipeline (planner → writer → reviewer → validator → mutation-planner → verifier) для **одного** файла.

## Аргументы

- `<path>` — обязательно, путь к source-компоненту (не к тесту)
- `--skip-mutations` — опционально, пропустить стадии 5–6 (быстрый режим)
- `--threshold=N` — опционально, override reviewer threshold (default 9)

## Действия

1. Проверь что мы в git repo и `.test-pipeline.yaml` существует. Если нет — предложи запустить `/test-init` и остановись.
2. Проверь что `<path>` существует и попадает в `source_globs` / не в `ignore_globs`.
3. Invoke skill `unit-tester` с параметрами:
   - `mode: single_component`
   - `sut_path: <path>`
   - `skip_mutations: <flag>`
   - `reviewer_threshold_override: <N or null>`
4. Skill orchestrator сам вызовет 6 sub-agents, вернёт итоговый отчёт.
5. Выведи компактный summary (см. output-контракт в SKILL.md).

## Пример

```
/test-component src/az_rag/retriever/hybrid.py
/test-component src/foo.py --skip-mutations
/test-component src/utils/parse.ts --threshold=8
```
