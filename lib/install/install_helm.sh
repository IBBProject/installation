install_helm () {
  if [ "$INSTALL_HELM" != true ]; then 
    log_info "Install helm flag is not true. Skipping helm installation..."
    return 1
  fi
  if command -v helm &>/dev/null
  then
    log_info "Found helm binary. No need to reinstall."
  else
    log_info "Installing helm..."

    HELM_INSTALL_SCRIPT="$IBB_DOWNLOAD_PATH/$HELM_INSTALL_SCRIPT_FILENAME"
    if [[ -f "$HELM_INSTALL_SCRIPT" ]]
    then
      rm "$HELM_INSTALL_SCRIPT"
    fi
    curl -fsSL -o $HELM_INSTALL_SCRIPT https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 $HELM_INSTALL_SCRIPT
    $HELM_INSTALL_SCRIPT | tee -a $IBB_LOG_FILE
  fi
}
