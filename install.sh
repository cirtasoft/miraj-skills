#!/usr/bin/env sh
# Installs the MIRAJ skills (miraj-dba, miraj-dev, miraj-mcp) for Claude Code.
#
#   ./install.sh              # for the user: ~/.claude/skills
#   ./install.sh --project    # for the current project: ./.claude/skills
#   ./install.sh miraj-dev    # a single skill
#   ./install.sh --uninstall  # removes the skills
set -eu

source_dir=$(cd "$(dirname "$0")" && pwd)
target="$HOME/.claude/skills"
uninstall=0
skills=""

for arg in "$@"; do
    case "$arg" in
        --project) target="$(pwd)/.claude/skills" ;;
        --uninstall) uninstall=1 ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) skills="$skills $arg" ;;
    esac
done
[ -n "$skills" ] || skills="miraj-dba miraj-dev miraj-mcp"

for name in $skills; do
    dest="$target/$name"
    if [ "$uninstall" -eq 1 ]; then
        if [ -d "$dest" ]; then rm -rf "$dest"; echo "Removed: $dest"; else echo "Not found: $dest"; fi
        continue
    fi
    [ -f "$source_dir/$name/SKILL.md" ] || { echo "Skill not found: $name" >&2; exit 1; }
    mkdir -p "$target"
    rm -rf "$dest"
    cp -R "$source_dir/$name" "$dest"
    echo "Installed: $name -> $dest"
done

[ "$uninstall" -eq 1 ] || echo "Done. Restart Claude Code, then type /skills to check."
