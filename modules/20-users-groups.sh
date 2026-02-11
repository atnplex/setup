MODULE_ID="users-groups"
MODULE_DESC="Create standard users and groups"
MODULE_ORDER=20

module_supports_os() { return 0; }
module_requires_root() { return 0; }

module_run() {
  : "${BOOTSTRAP_USER:=}"  # from config/env if set
  if [[ -z "$BOOTSTRAP_USER" ]]; then
    log_info "No BOOTSTRAP_USER set; skipping user creation."
    return 0
  fi

  if id "$BOOTSTRAP_USER" >/dev/null 2>&1; then
    log_info "User $BOOTSTRAP_USER already exists."
  else
    log_info "Creating user $BOOTSTRAP_USER..."
    sudo useradd -m -s /bin/bash "$BOOTSTRAP_USER"
  fi
}
