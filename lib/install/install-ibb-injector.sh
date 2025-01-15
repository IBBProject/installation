do_injector() {
  if [ "$INSTALL_INJECTOR" != true ]; then
    log_info "Install Injector flag is not true. Skipping Injector installation..."
    return 0
  fi
 
   if [ "$DO_UPDATE" == true ]; then
    log_info "Updating Injector..."
    update_injector
    log_info "Done."
    return 0
  fi

  # If we make it this far, we should install the injector
  log_info "Installing IBB Injector..."
  install_injector
  log_info "Done."
}

install_injector () {
  if [ ! -d "$IBB_INJECTOR_PATH" ]; then
    mkdir "$IBB_INJECTOR_PATH"
  fi

  # Installation has been configured, run the update to install the injector
  update_injector

  if [ ! -f "$INJECTOR_TOKEN_PATH" ]; then
    log_info "Could not find $INJECTOR_TOKEN_PATH file. Downloading..."

    if [ ! -f "$IBB_INSTALL_DIR/padi.json" ]; then
      log_fail "Could not find authorization file. Failing"
    fi

    set +o noglob

    TKN=$( \
      cat "$IBB_INSTALL_DIR/padi.json" \
        | grep -Po '"padiToken":"[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"' \
        | cut -d ':' -f2 \
        | tr -d '"'
    )

    # Fail if token is less than 150 chars
    if [ "${#TKN}" -lt 150 ]; then
      echo "Padi token looks incorrect. Failing."
    fi

    log_debug "Making CURL request to PADI"
    # Make CURL request to Padi to get manifest file
    curl --request GET \
      --silent \
      --url $PADI_ONBOARDING_PIKO_URL \
      --header "Authorization: Bearer $TKN" \
      --header "content-type: application/json" \
      > $INJECTOR_TOKEN_PATH
  fi

  # Add piko-token k8s secret if not found
  if ! k3s kubectl get secret -n default piko-token > /dev/null 2>&1; then
    log_info "Piko token not found in cluster. Creating..."
    k3s kubectl create secret generic -n default piko-token --from-file=$INJECTOR_TOKEN_PATH | tee -a $IBB_LOG_FILE
  fi

  set -o noglob
}


update_injector () {
  log_info "Updating Helm repositories"
  helm repo update > /dev/null
  log_info "Updating sidecar injector"
  helm upgrade --install ibb-injector \
    ibb/ibb-injector \
    --namespace sidecar-injector \
    --wait | tee -a $IBB_LOG_FILE
  
  INJECTOR_VERSION=$(helm search repo ibb/ibb-injector | tail -n 1 | cut -f2)
  log_info "Success. ibb/ibb-injector is now on version $INJECTOR_VERSION"
}
