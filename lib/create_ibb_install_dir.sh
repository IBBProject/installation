create_ibb_install_dir () {
  # Create IBB Install Directory
  if [ ! -d "$IBB_INSTALL_DIR" ]; then
    mkdir -p "$IBB_LOG_PATH" # Log path must exist before we can log_info
    log_info "Creating IBB directory $IBB_LOG_PATH"
    log_info "Creating IBB directory $IBB_DOWNLOAD_PATH"
    mkdir -p "$IBB_DOWNLOAD_PATH"
  else
    log_info "IBB Directory already at $IBB_INSTALL_DIR"
  fi
}
