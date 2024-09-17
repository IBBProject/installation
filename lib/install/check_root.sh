check_root () {
  # Check that script is running as root
  if [ "$EUID" -ne 0 ]
  then
    log_fail "Setup must be ran as root."
  fi
}
