---
description: Создать .test-pipeline.yaml в корне текущего репо. Автодетект стека (Python/TypeScript). Usage — /test-init [--stack python|typescript]
---

# /test-init

Создаёт `.test-pipeline.yaml` в корне репо на базе шаблона.

## Аргументы

- `--stack python|typescript` — опционально. Если не задан — авто-детект по наличию `pyproject.toml` / `package.json`.
- `--force` — перезаписать существующий `.test-pipeline.yaml` (default: не перезаписывать, спросить).

## Действия

1. Найди корень репо (`git rev-parse --show-toplevel`).
2. Если `.test-pipeline.yaml` уже есть и не задан `--force` — покажи текущий, спроси `overwrite / keep / abort`.
3. **Автодетект стека:**
   - `pyproject.toml` или `setup.py` → `python`
   - `package.json` с `react`/`vue`/`typescript` в deps → `typescript`
   - Ничего не найдено → спроси у пользователя.
4. Прочитай шаблон `~/.claude/skills/unit-tester/templates/.test-pipeline.yaml`.
5. Активируй правильный preset (раскомментируй нужный, удали другой).
6. Подстрой `source_globs` под фактическую структуру:
   - Python: если есть `src/` — оставь. Иначе — предложи `<top_pkg>/**/*.py`.
   - TypeScript: если есть `src/` — оставь. Иначе — `app/`, `pages/` и т.п.
7. Запиши в `<repo_root>/.test-pipeline.yaml`.
8. Спроси: **«Хочешь добавить `.test-pipeline.yaml` в git и создать `.test-pipeline.local.yaml.example` для локальных override'ов?»**
9. Print следующий шаг:
   ```
   ✅ .test-pipeline.yaml создан.
   Дальше:
     /test-component <path>   — прогнать pipeline на одном файле
     /test-commits            — commit-driven режим
     Read ~/.claude/skills/unit-tester/references/pipeline-config.md — полная схема
   ```

## Пример

```
/test-init                      # автодетект
/test-init --stack python
/test-init --force              # перезаписать без вопросов
```
