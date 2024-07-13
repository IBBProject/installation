check_required_binaries () {
  # Check binaries exist on system
  for BINARY in $REQUIRED_BINARIES
  do
    log_info "Checking for $BINARY"
    if !  command -v $BINARY &>/dev/null
    then
      log_fail "$BINARY not found. Exiting..."
    fi
    if [[ "$BINARY" -eq "grep" ]]; then
      log_info "Checking grep version"
      grep --version | grep "GNU grep" > /dev/null
      GNU_GREP=$?
      if [[ "$GNU_GREP" -gt 0 ]]; then
        log_fail "GNU Grep is not installed. Please install and try again"
      fi
    fi
  done
}
