#!/usr/bin/env bash
# CoVibe installer — copies skill, rule, and hook to ~/.claude/
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing CoVibe..."

# Skills
mkdir -p ~/.claude/skills/covibe
cp "$SCRIPT_DIR/skills/covibe/SKILL.md" ~/.claude/skills/covibe/SKILL.md
echo "  /covibe skill installed"

mkdir -p ~/.claude/skills/covibe-coordination
cp "$SCRIPT_DIR/skills/covibe-coordination/SKILL.md" ~/.claude/skills/covibe-coordination/SKILL.md
echo "  Coordination guidance installed"

# Hook script
mkdir -p ~/.claude/scripts
cp "$SCRIPT_DIR/scripts/covibe-sync.sh" ~/.claude/scripts/covibe-sync.sh
chmod +x ~/.claude/scripts/covibe-sync.sh
echo "  Hook installed at ~/.claude/scripts/covibe-sync.sh"

# Check if hook is in settings.json
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  if grep -q "covibe-sync.sh" "$SETTINGS"; then
    echo "  Hook already registered in settings.json"
  else
    echo ""
    echo "  ACTION NEEDED: Add this to your Stop hooks in $SETTINGS:"
    echo ""
    echo '  {"type": "command", "command": "$HOME/.claude/scripts/covibe-sync.sh"}'
    echo ""
  fi
else
  echo ""
  echo "  No settings.json found at $SETTINGS"
  echo "  Create one or add the Stop hook manually (see README)."
fi

echo ""
echo "Done. Run /covibe start in any shared repo to begin."
