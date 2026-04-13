#!/usr/bin/env bash
# CoVibe installer — copies skill, coordination skill, and hook to ~/.claude/
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing CoVibe..."

# Skills
mkdir -p ~/.claude/skills/covibe
if [ -f ~/.claude/skills/covibe/SKILL.md ]; then
  echo "  Updating /covibe skill..."
else
  echo "  Installing /covibe skill..."
fi
cp "$SCRIPT_DIR/skills/covibe/SKILL.md" ~/.claude/skills/covibe/SKILL.md

mkdir -p ~/.claude/skills/covibe-coordination
if [ -f ~/.claude/skills/covibe-coordination/SKILL.md ]; then
  echo "  Updating coordination guidance..."
else
  echo "  Installing coordination guidance..."
fi
cp "$SCRIPT_DIR/skills/covibe-coordination/SKILL.md" ~/.claude/skills/covibe-coordination/SKILL.md

# Hook script
mkdir -p ~/.claude/scripts
if [ -f ~/.claude/scripts/covibe-sync.sh ]; then
  echo "  Updating hook at ~/.claude/scripts/covibe-sync.sh"
else
  echo "  Installing hook at ~/.claude/scripts/covibe-sync.sh"
fi
cp "$SCRIPT_DIR/scripts/covibe-sync.sh" ~/.claude/scripts/covibe-sync.sh
chmod +x ~/.claude/scripts/covibe-sync.sh

# Check if hook is in settings.json
SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  if grep -q "covibe-sync.sh" "$SETTINGS"; then
    echo "  Hook already registered in settings.json"
  else
    echo ""
    echo "  ACTION NEEDED: Add the sync hook to your settings.json."
    echo "  Open $SETTINGS and add this to the \"hooks\" section:"
    echo ""
    echo '  "hooks": {'
    echo '    "Stop": ['
    echo '      {'
    echo '        "matcher": "",'
    echo '        "hooks": ['
    echo '          {'
    echo '            "type": "command",'
    echo '            "command": "$HOME/.claude/scripts/covibe-sync.sh"'
    echo '          }'
    echo '        ]'
    echo '      }'
    echo '    ]'
    echo '  }'
    echo ""
    echo "  If you already have Stop hooks, add the covibe entry to the existing array."
  fi
else
  echo ""
  echo "  No settings.json found at $SETTINGS"
  echo "  Create it with the hook configuration above, or use the plugin install method (see README)."
fi

echo ""
echo "Done. Run /covibe start in any shared repo to begin."
