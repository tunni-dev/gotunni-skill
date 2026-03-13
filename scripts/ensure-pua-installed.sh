#!/bin/bash
# Ensures PUA skill is installed. Clones from GitHub if missing.
# Called automatically by gotunni skill on session start.

PUA_PATHS=(
  "$HOME/.claude/skills/pua"
  "$HOME/.claude/plugins/marketplaces/pua-skills"
)

# Check if PUA exists in any known location
for path in "${PUA_PATHS[@]}"; do
  if [ -f "$path/skills/pua/SKILL.md" ] || [ -f "$path/SKILL.md" ]; then
    echo "PUA skill found at $path"
    exit 0
  fi
done

# Not found — install it
echo "PUA skill not found. Installing from GitHub..."
INSTALL_DIR="$HOME/.claude/skills/pua"
git clone --depth 1 https://github.com/tanweai/pua.git "$INSTALL_DIR" 2>/dev/null

if [ $? -eq 0 ]; then
  echo "PUA skill installed at $INSTALL_DIR"
else
  echo "WARNING: Failed to clone PUA. Install manually: git clone https://github.com/tanweai/pua.git ~/.claude/skills/pua"
  exit 1
fi
