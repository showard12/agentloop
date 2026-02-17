#!/bin/bash
# AgentLoop — Full Installation Script
# Installs the agentloop plugin and all dependencies (plugins + MCPs + tools)
#
# Usage: ./install.sh [--all | --minimal | --check]
#   --all      Install everything (default)
#   --minimal  Only required dependencies (hookify, vibekanban, jq)
#   --check    Just verify what's installed, don't install anything

set -e

# ─── Colors ─────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ok() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
info() { echo -e "  ${BLUE}→${NC} $1"; }
header() { echo -e "\n${BLUE}━━━ $1 ━━━${NC}"; }

# ─── Parse Args ─────────────────────────────────────────────────────────────

MODE="all"
while [[ $# -gt 0 ]]; do
  case $1 in
    --minimal) MODE="minimal"; shift ;;
    --check) MODE="check"; shift ;;
    --all) MODE="all"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERRORS=0

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║  AgentLoop Installer                              ║"
echo "║  Mode: $MODE                                      "
echo "╚═══════════════════════════════════════════════════╝"

# ─── 1. Check Prerequisites ────────────────────────────────────────────────

header "Prerequisites"

# Claude CLI
if command -v claude &>/dev/null; then
  ok "claude CLI found: $(claude --version 2>/dev/null || echo 'installed')"
else
  fail "claude CLI not found"
  info "Install: npm install -g @anthropic-ai/claude-code"
  ERRORS=$((ERRORS + 1))
fi

# Node.js
if command -v node &>/dev/null; then
  ok "Node.js found: $(node --version)"
else
  fail "Node.js not found (required for MCP servers)"
  ERRORS=$((ERRORS + 1))
fi

# jq
if command -v jq &>/dev/null; then
  ok "jq found: $(jq --version)"
else
  if [[ "$MODE" != "check" ]]; then
    info "Installing jq..."
    if command -v brew &>/dev/null; then
      brew install jq
      ok "jq installed"
    else
      fail "jq not found and Homebrew not available"
      info "Install manually: https://jqlang.github.io/jq/download/"
      ERRORS=$((ERRORS + 1))
    fi
  else
    fail "jq not found"
    ERRORS=$((ERRORS + 1))
  fi
fi

# Git
if command -v git &>/dev/null; then
  ok "git found: $(git --version | head -1)"
else
  fail "git not found"
  ERRORS=$((ERRORS + 1))
fi

# bun (optional — needed for claude-mem)
if command -v bun &>/dev/null; then
  ok "bun found: $(bun --version)"
else
  if [[ "$MODE" == "all" && "$MODE" != "check" ]]; then
    info "Installing bun (needed for claude-mem)..."
    curl -fsSL https://bun.sh/install | bash
    ok "bun installed"
  else
    warn "bun not found (optional — needed for claude-mem worker)"
  fi
fi

# ─── 2. Install AgentLoop Plugin ───────────────────────────────────────────

header "AgentLoop Plugin"

SETTINGS_FILE="$HOME/.claude/settings.json"

if [[ -f "$SETTINGS_FILE" ]] && jq -e '.enabledPlugins["agentloop@local"]' "$SETTINGS_FILE" &>/dev/null; then
  ok "agentloop@local already registered"
else
  if [[ "$MODE" != "check" ]]; then
    info "Registering agentloop plugin..."

    # Ensure settings file exists
    mkdir -p "$HOME/.claude"
    if [[ ! -f "$SETTINGS_FILE" ]]; then
      echo '{}' > "$SETTINGS_FILE"
    fi

    # Add to enabledPlugins
    jq --arg path "$SCRIPT_DIR" '.enabledPlugins["agentloop@local"] = true' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

    # Add to installed_plugins.json
    INSTALLED_FILE="$HOME/.claude/plugins/installed_plugins.json"
    mkdir -p "$HOME/.claude/plugins"
    if [[ ! -f "$INSTALLED_FILE" ]]; then
      echo '[]' > "$INSTALLED_FILE"
    fi

    # Check if already in installed list
    if ! jq -e ".[] | select(.name == \"agentloop\")" "$INSTALLED_FILE" &>/dev/null; then
      jq --arg path "$SCRIPT_DIR" '. += [{"name": "agentloop", "version": "0.2.0", "source": "local", "installPath": $path, "installedAt": (now | todate)}]' "$INSTALLED_FILE" > "$INSTALLED_FILE.tmp"
      mv "$INSTALLED_FILE.tmp" "$INSTALLED_FILE"
    fi

    ok "agentloop plugin registered"
  else
    fail "agentloop plugin not registered"
    ERRORS=$((ERRORS + 1))
  fi
fi

# ─── 3. Install Required Plugins ──────────────────────────────────────────

header "Claude Code Plugins"

install_plugin() {
  local name="$1"
  local required="$2"

  if [[ -f "$SETTINGS_FILE" ]] && jq -e ".enabledPlugins[\"$name\"]" "$SETTINGS_FILE" 2>/dev/null | grep -q "true"; then
    ok "$name (enabled)"
  else
    if [[ "$required" == "true" ]]; then
      fail "$name (NOT installed — REQUIRED)"
      info "Enable in Claude Code: /plugin install or add to ~/.claude/settings.json"
      ERRORS=$((ERRORS + 1))
    else
      warn "$name (not installed — optional)"
    fi
  fi
}

# Required
install_plugin "hookify@claude-plugins-official" "true"

# Optional (all mode)
if [[ "$MODE" == "all" ]]; then
  install_plugin "claude-mem@thedotmack" "false"
  install_plugin "superpowers@claude-plugins-official" "false"
  install_plugin "code-review@claude-plugins-official" "false"
  install_plugin "pr-review-toolkit@claude-plugins-official" "false"
  install_plugin "dev-browser@dev-browser-marketplace" "false"
fi

# ─── 4. Install MCP Servers ───────────────────────────────────────────────

header "MCP Servers"

# Check if MCP servers are declared in the plugin .mcp.json
if [[ -f "$SCRIPT_DIR/.mcp.json" ]]; then
  ok "Plugin .mcp.json found (vibekanban + mobile-mcp auto-registered)"
else
  fail ".mcp.json missing from plugin directory"
  ERRORS=$((ERRORS + 1))
fi

# Verify npx can resolve the packages
if [[ "$MODE" != "check" ]]; then
  info "Verifying MCP packages are resolvable..."

  if npx -y claude-vibekanban --help &>/dev/null 2>&1 || npx -y claude-vibekanban --version &>/dev/null 2>&1; then
    ok "claude-vibekanban (npx resolvable)"
  else
    # npx -y will auto-install, so just check npm registry
    if npm view claude-vibekanban version &>/dev/null 2>&1; then
      ok "claude-vibekanban (available on npm, will auto-install via npx)"
    else
      warn "claude-vibekanban — couldn't verify package availability"
    fi
  fi

  if npm view @mobilenext/mobile-mcp version &>/dev/null 2>&1; then
    ok "@mobilenext/mobile-mcp (available on npm)"
  else
    warn "@mobilenext/mobile-mcp — couldn't verify (optional, for mobile projects)"
  fi
else
  info "Skipping MCP package verification (check mode)"
fi

# Also install mobile-mcp via claude CLI for direct use
if [[ "$MODE" == "all" && "$MODE" != "check" ]]; then
  info "Registering mobile-mcp with Claude CLI..."
  claude mcp add mobile -- npx -y @mobilenext/mobile-mcp@latest 2>/dev/null && ok "mobile-mcp registered with Claude CLI" || warn "Could not register mobile-mcp (may need manual setup)"
fi

# ─── 5. Verify claude-mem Worker ──────────────────────────────────────────

if [[ "$MODE" == "all" ]]; then
  header "claude-mem Worker"

  CLAUDE_MEM_DIR="$HOME/.claude/plugins/marketplaces/thedotmack"

  if [[ -d "$CLAUDE_MEM_DIR" ]]; then
    ok "claude-mem marketplace directory found"

    if curl -sf http://127.0.0.1:8100/api/health &>/dev/null || curl -sf http://127.0.0.1:8000/api/health &>/dev/null; then
      ok "claude-mem worker is running"
    else
      warn "claude-mem worker not responding"
      info "Start with: cd $CLAUDE_MEM_DIR && bun run worker:restart"
    fi

    # Check Chroma port conflict
    CHROMA_PORT=$(jq -r '.CLAUDE_MEM_CHROMA_PORT // "8000"' "$HOME/.claude-mem/settings.json" 2>/dev/null || echo "8000")
    if [[ "$CHROMA_PORT" == "8000" ]]; then
      warn "Chroma port is 8000 — may conflict with backend services"
      info "Recommend changing to 8100 in ~/.claude-mem/settings.json"
    else
      ok "Chroma port: $CHROMA_PORT (no conflict)"
    fi
  else
    warn "claude-mem not installed (memory features will be skipped)"
  fi
fi

# ─── 6. Copy agentloop.sh to working directory ────────────────────────────

header "Script Setup"

info "agentloop.sh lives at: $SCRIPT_DIR/agentloop.sh"
info "To use in a project, copy or symlink:"
info "  cp $SCRIPT_DIR/agentloop.sh /path/to/project/"
info "  OR: ln -sf $SCRIPT_DIR/agentloop.sh /path/to/project/agentloop.sh"

if [[ -x "$SCRIPT_DIR/agentloop.sh" ]]; then
  ok "agentloop.sh is executable"
else
  chmod +x "$SCRIPT_DIR/agentloop.sh"
  ok "agentloop.sh made executable"
fi

# ─── Summary ──────────────────────────────────────────────────────────────

header "Summary"

if [[ $ERRORS -eq 0 ]]; then
  echo -e "\n  ${GREEN}All checks passed!${NC}\n"
  echo "  Next steps:"
  echo "    1. cd /path/to/your/project"
  echo "    2. claude                        # Start Claude Code"
  echo "    3. /onboard-agentloop            # Set up project"
  echo "    4. ./agentloop.sh                # Start autonomous loop"
  echo ""
else
  echo -e "\n  ${RED}$ERRORS issue(s) found.${NC} Fix the items marked with ✗ above.\n"
fi

exit $ERRORS
