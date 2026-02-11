3. Module contract (how each module should behave)
Each modules/*.sh implements a simple contract:

bash
# Required: unique ID
MODULE_ID="ssh"
MODULE_DESC="Configure SSH server and client defaults"
MODULE_ORDER=10   # For deterministic ordering

# Optional: OS support declaration
module_supports_os() {
  # Return 0 if supported, 1 if not
  case "$OS_ID" in
    ubuntu|debian|fedora|centos) return 0 ;;
    *) return 1 ;;
  esac
}

# Optional: does this require root?
module_requires_root() {
  return 0  # 0 = yes, 1 = no
}

# Optional: interactive description
module_interactive_prompt() {
  echo "Configure SSH (hardened server, client config, keys)?"
}

# Required: main entrypoint
module_run() {
  # Use helper functions from core.sh: log_info, ensure_pkg, etc.
  log_info "Configuring SSH..."
  # ... do work ...
}
The core registry.sh:

Sources all modules/*.sh.

Builds an in‑memory registry (array or associative array).

Filters by module_supports_os and module_requires_root.
