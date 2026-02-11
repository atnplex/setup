MODULE_ID="agent_config"
MODULE_DESC="Deploy Antigravity agent configuration (rules, skills, workflows)"
MODULE_ORDER=70

module_supports_os() { return 0; }
module_requires_root() { return 1; } # Does not require root

module_run() {
  local setup_repo="${SETUP_REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  local config_dir="${setup_repo}/config"
  local atn_root="${NAMESPACE:-/atn}"

  if [[ ! -d "$config_dir" ]]; then
    log_error "Config directory not found: $config_dir"
    return 1
  fi

  log_info "Deploying agent config from $config_dir to $atn_root..."

  # Create /atn namespace directory structure
  local dirs=(
    "$atn_root/.gemini/antigravity/skills"
    "$atn_root/.gemini/antigravity/global_workflows"
    "$atn_root/.gemini/antigravity/scratch"
    "$atn_root/.gemini/antigravity/personas"
    "$atn_root/.gemini/antigravity/brain"
    "$atn_root/.agent/rules"
    "$atn_root/.agent/learning/reflections"
    "$atn_root/baseline"
    "$atn_root/github"
    "$atn_root/bin"
    "$atn_root/logs"
  )
  for d in "${dirs[@]}"; do
    mkdir -p "$d"
  done
  log_info "Created /atn namespace directory structure"

  # Deploy GEMINI.md (global rules entry point)
  if [[ -f "$config_dir/gemini/GEMINI.md" ]]; then
    cp "$config_dir/gemini/GEMINI.md" "$atn_root/.gemini/GEMINI.md"
    log_info "Deployed GEMINI.md"
  fi

  # Deploy MCP config (render template variables)
  if [[ -f "$config_dir/gemini/mcp_config.json" ]]; then
    sed -e "s|\${HOME}|$HOME|g" \
      -e "s|\${NAMESPACE}|$atn_root|g" \
      "$config_dir/gemini/mcp_config.json" >"$atn_root/.gemini/antigravity/mcp_config.json"
    log_info "Deployed mcp_config.json (rendered with HOME=$HOME, NAMESPACE=$atn_root)"
  fi

  # Deploy rules
  if [[ -d "$config_dir/agent/rules" ]]; then
    cp -r "$config_dir/agent/rules/"* "$atn_root/.agent/rules/" 2>/dev/null || true
    local count
    count=$(find "$atn_root/.agent/rules" -type f | wc -l)
    log_info "Deployed $count rules"
  fi

  # Deploy learning
  if [[ -d "$config_dir/agent/learning" ]]; then
    cp -r "$config_dir/agent/learning/"* "$atn_root/.agent/learning/" 2>/dev/null || true
    log_info "Deployed learning data"
  fi

  # Deploy skills
  if [[ -d "$config_dir/gemini/skills" ]]; then
    cp -r "$config_dir/gemini/skills/"* "$atn_root/.gemini/antigravity/skills/" 2>/dev/null || true
    local count
    count=$(find "$atn_root/.gemini/antigravity/skills" -maxdepth 1 -type d | wc -l)
    log_info "Deployed $((count - 1)) skills"
  fi

  # Deploy workflows
  if [[ -d "$config_dir/gemini/global_workflows" ]]; then
    cp -r "$config_dir/gemini/global_workflows/"* "$atn_root/.gemini/antigravity/global_workflows/" 2>/dev/null || true
    local count
    count=$(find "$atn_root/.gemini/antigravity/global_workflows" -type f | wc -l)
    log_info "Deployed $count workflows"
  fi

  # Deploy personas
  if [[ -d "$config_dir/gemini/personas" ]]; then
    cp -r "$config_dir/gemini/personas/"* "$atn_root/.gemini/antigravity/personas/" 2>/dev/null || true
    log_info "Deployed personas"
  fi

  # Deploy baseline
  if [[ -d "$config_dir/baseline" ]]; then
    cp -r "$config_dir/baseline/"* "$atn_root/baseline/" 2>/dev/null || true
    log_info "Deployed baseline"
  fi

  # Deploy VS Code server settings (auto-approve, etc.)
  if [[ -f "$config_dir/vscode/machine-settings.json" ]]; then
    local vscode_dir="$atn_root/.antigravity-server/data/Machine"
    mkdir -p "$vscode_dir"
    if [[ -f "$vscode_dir/settings.json" ]]; then
      log_info "VS Code settings already exist, merging auto-approve keys..."
      # Use python to merge (preserve existing, add missing keys)
      python3 -c "
import json, sys
existing = json.load(open('$vscode_dir/settings.json'))
template = json.load(open('$config_dir/vscode/machine-settings.json'))
for k, v in template.items():
    if k not in existing:
        existing[k] = v
json.dump(existing, open('$vscode_dir/settings.json', 'w'), indent=2)
print(f'Merged {len(template)} keys into settings.json')
" 2>/dev/null || cp "$config_dir/vscode/machine-settings.json" "$vscode_dir/settings.json"
    else
      cp "$config_dir/vscode/machine-settings.json" "$vscode_dir/settings.json"
      log_info "Deployed VS Code machine settings"
    fi
  fi

  # Create scratch templates if they don't exist
  if [[ ! -f "$atn_root/.gemini/antigravity/scratch/session_log.md" ]]; then
    cat >"$atn_root/.gemini/antigravity/scratch/session_log.md" <<'EOF'
# Session Log

> Append-only log of what each session accomplished. Primary context for `/resume` across conversations.

---
EOF
    log_info "Created session_log.md template"
  fi

  if [[ ! -f "$atn_root/.gemini/antigravity/scratch/todo.md" ]]; then
    cat >"$atn_root/.gemini/antigravity/scratch/todo.md" <<'EOF'
# Todo List

## 🔴 Critical (blocking work)

## 🟡 Important (should do soon)

## 🟢 Normal (when time permits)

## 🔵 Ideas (backlog)

## ✅ Completed
EOF
    log_info "Created todo.md template"
  fi

  if [[ ! -f "$atn_root/.gemini/antigravity/scratch/user_preferences.md" ]]; then
    cat >"$atn_root/.gemini/antigravity/scratch/user_preferences.md" <<'EOF'
# User Preferences

> Configure per-user preferences here. Checked by `/resume` workflow.
EOF
    log_info "Created user_preferences.md template"
  fi

  log_info "Agent config deployment complete"
}
