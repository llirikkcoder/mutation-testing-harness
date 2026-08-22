#!/usr/bin/env bash
# install.sh — быстро устанавливает unit-tester harness в .claude/ целевого проекта.
#
# Использование:
#   ./install.sh [путь_к_проекту] [--force]
#
#   путь_к_проекту   куда ставить (по умолчанию: текущая директория)
#   --force          перезаписать файлы, уже существующие в целевом .claude/
#
# Примеры:
#   ./install.sh                      # установить в $(pwd)/.claude
#   ./install.sh ~/code/my-project    # установить в другой проект
#   ./install.sh . --force            # переустановить, перезаписав всё

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_DIR="."
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    *) TARGET_DIR="$arg" ;;
  esac
done

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
CLAUDE_DIR="$TARGET_DIR/.claude"

echo "Источник:  $SOURCE_DIR"
echo "Установка в: $CLAUDE_DIR"
echo

mkdir -p "$CLAUDE_DIR/agents" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/skills"

copied=0
skipped=0

copy_tree() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  while IFS= read -r -d '' file; do
    local rel="${file#"$src"/}"
    local dest_file="$dst/$rel"
    if [[ -e "$dest_file" && "$FORCE" -eq 0 ]]; then
      echo "  пропуск (уже существует): .claude/${dest_file#"$CLAUDE_DIR"/}"
      skipped=$((skipped + 1))
      continue
    fi
    mkdir -p "$(dirname "$dest_file")"
    cp "$file" "$dest_file"
    echo "  установлен: .claude/${dest_file#"$CLAUDE_DIR"/}"
    copied=$((copied + 1))
  done < <(find "$src" -type f -print0)
}

echo "agents/"
copy_tree "$SOURCE_DIR/agents" "$CLAUDE_DIR/agents"

echo "commands/"
copy_tree "$SOURCE_DIR/commands" "$CLAUDE_DIR/commands"

echo "skills/unit-tester/"
copy_tree "$SOURCE_DIR/skills/unit-tester" "$CLAUDE_DIR/skills/unit-tester"

echo
echo "Готово: установлено $copied файлов, пропущено $skipped."
if [[ "$skipped" -gt 0 && "$FORCE" -eq 0 ]]; then
  echo "Чтобы перезаписать существующие файлы, запусти с флагом --force."
fi
echo
echo "Дальше: перейди в $TARGET_DIR и выполни /test-init, чтобы создать .test-pipeline.yaml."
