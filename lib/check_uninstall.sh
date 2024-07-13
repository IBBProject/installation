check_uninstall () {
  # Uninstall IBB
  if [ "$UNINSTALL" = true ]; then
    log_info "Uninstalling K3S"
    /usr/local/bin/k3s-uninstall.sh &>/dev/null
    log_info "Deleting IBB Directory"
    rm -rf "$IBB_INSTALL_DIR"
    echo "[****] IBB has been Installed"
    exit 1
  fi
}
