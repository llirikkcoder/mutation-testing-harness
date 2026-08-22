# Hooks recipe — как встроить unit-tester в обычный workflow

Хуки прописываются в `~/.claude/settings.json` (global) или `<repo>/.claude/settings.json` (per-project). Ниже — три готовых рецепта. **Скилл сам не правит `settings.json`** — это работа пользователя, чтобы не сломать существующие хуки.

## Как посмотреть текущие хуки

```bash
cat ~/.claude/settings.json | jq '.hooks // empty'
cat .claude/settings.json | jq '.hooks // empty' 2>/dev/null
```

## Рецепт 1 — pre-commit reminder (безопасный)

Перед `git commit` напоминает про `/test-commits`, но не блокирует.

Добавь в `hooks` секцию `settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "if echo \"$CLAUDE_TOOL_INPUT\" | grep -qE '^git commit'; then echo '💡 Reminder: consider /test-commits before committing to auto-generate tests for changed files.' >&2; fi",
            "timeout": 2
          }
        ]
      }
    ]
  }
}
```

Не блокирует, только печатает reminder. Ты решаешь дальше сам.

## Рецепт 2 — post-edit trigger (более агрессивный)

После `Write`/`Edit` на файл в `source_globs` — предлагает прогнать unit-tester сразу.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "path=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r '.file_path // empty'); if echo \"$path\" | grep -qE '\\.(py|ts|tsx)$' && ! echo \"$path\" | grep -qE '(test_|\\.test\\.|\\.spec\\.)'; then echo \"💡 Файл $path изменён. Прогнать /test-component для авто-теста?\" >&2; fi",
            "timeout": 2
          }
        ]
      }
    ]
  }
}
```

**Осторожно:** триггерится **на каждый** edit. Если ты активно рефакторишь один файл 20 раз подряд — 20 напоминаний. Обычно достаточно рецепта 1.

## Рецепт 3 — Stop hook: auto-run на изменённые файлы

После завершения работы Claude автоматически проверяет `git diff --name-only` и напоминает про non-tested файлы. **Не запускает pipeline автоматически** — только сообщает.

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "changed=$(git diff --name-only 2>/dev/null | grep -E '\\.(py|ts|tsx)$' | grep -vE '(test_|\\.test\\.|\\.spec\\.)' | head -5); if [ -n \"$changed\" ]; then echo '📝 Изменены исходники без прогона тестов:'; echo \"$changed\" | sed 's/^/  - /'; echo 'Запусти /test-commits чтобы прогнать pipeline.'; fi",
            "timeout": 3
          }
        ]
      }
    ]
  }
}
```

## Не рекомендую (антипаттерны)

- **Auto-run unit-tester в PreCommit** — это долго (5–15 мин на файл) и дорого. Держи в интерактивной команде.
- **Блокировать commit** если тесты не написаны — сам себе яму копаешь на срочных фиксах. Лучше reminder + опциональный gate в CI.
- **Auto-invoke skill** через `SessionStart` hook — скилл нагружает контекст, нужен только когда реально нужен.

## AZ-RAG-специфика

Для regulated env (GxP) стоит **не** триггерить pipeline автоматически. Ручной approve по каждой сессии = audit-trail. Рецепт 1 или 3 — да; рецепт 2 — только если ты один разработчик и знаешь, что делаешь.
