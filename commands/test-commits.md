---
description: Пройтись по коммитам от <ref> до HEAD, интерактивно approve/skip каждый затронутый файл, для approve — запустить pipeline. Usage — /test-commits [<from_ref>]
---

# /test-commits

Commit-driven режим: агент проходит по изменённым файлам, ты решаешь approve/skip.

## Аргументы

- `<from_ref>` — опционально. Git ref (hash / branch / tag). Default: последний тег или `HEAD~10`.
- `--auto` — опционально. Auto-approve всё (для CI-подобного прогона; **не** рекомендуется для первого запуска).

## Действия

1. Проверь git repo + `.test-pipeline.yaml`.
2. Invoke agent `commit-analyzer` с `from_ref` (default см. выше) и `pipeline_config`. Получи worklist.
3. Print worklist header:
   ```
   Изменения от <from_ref> до HEAD:
     new_component: X, significant_change: Y, trivial: Z (skipped)
   Приступаем к обходу…
   ```
4. **Для каждого элемента worklist** (в порядке `new_component → significant_change → trivial`):
   - Print: `[i/n] <path> — <class> (<diff_summary>) — existing_test: <path or "none"> — commits: <n>`
   - Если `--auto` — сразу approve. Иначе — спроси у пользователя `[a]pprove / [s]kip / [d]iff / [q]uit`.
     - `d` → покажи `git diff <from_ref>..HEAD -- <path>`, спроси снова
     - `a` → invoke skill `unit-tester` в режиме `mode: single_component, sut_path: <path>`, дождись отчёта
     - `s` → лог, продолжай
     - `q` → напечатай финальный summary, стоп
5. **После обхода** — сводка:
   ```
   Обработано: <n_approved>, пропущено: <n_skipped>, ошибок: <n_failed>
   Средний catch rate: <X%>
   Время: <mm:ss>
   Список созданных/обновлённых тест-файлов:
     - tests/test_foo.py (8/8 mutations caught)
     - tests/test_bar.py (7/9 mutations caught, 2 surviving surfaced)
   ```

## Пример

```
/test-commits                    # от последнего тега
/test-commits abc1234            # от конкретного commit
/test-commits main               # от main до HEAD
/test-commits HEAD~5 --auto      # 5 последних коммитов, auto-approve
```
