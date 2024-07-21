install_ktunnel () {
  if [ "$INSTALL_KTUNNEL" != true ]; then
    log_info "Install KTunnel flag is not true. Skipping KTunnel installation..."
    return 0
  fi

  if [ ! -d "$IBB_KTUNNEL_PATH" ]; then
    mkdir "$IBB_KTUNNEL_PATH"
  fi

  if [ ! -f "$KTUNNEL_KUBECONFIG_SECRET_MANIFEST" ]; then
    log_info "Could not find $KTUNNEL_KUBECONFIG_SECRET_MANIFEST file. Downloading..."

    if [ ! -f "$IBB_INSTALL_DIR/padi.json" ]; then
      log_fail "Could not find authorization file. Failing"
    fi

    set +o noglob

    TKN=$( \
      cat "$IBB_INSTALL_DIR/padi.json" \
      | grep -Po '"padiToken":"[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"' \
      | cut -d ':' -f2 \
      | tr -d '"' \
    )

    # Fail if token is less than 150 chars
    if [ "${#TKN}" -lt 150 ]; then
      echo "Padi token looks incorrect. Failing."
    fi

    # Make CURL request to Padi to get manifest file
    curl --request GET \
      --url $PADI_ONBOARDING_CONFIG_URL \
      --header "Authorization: Bearer $TKN" \
      --header "content-type: application/json" \
      | grep -Po '"config":".*"' \
      | cut -d ":" -f2 \
      | tr -d '"' \
      | base64 -d \
      > $KTUNNEL_KUBECONFIG_SECRET_MANIFEST
  fi

  # Generate OpenSSL Certificates needed
  log_info "Generating ktunnel certificates and keys..."
  log_info "Creating ca.key"
  openssl genrsa -out $IBB_INSTALL_DIR/ktunnel/ca.key 4096 | tee -a $IBB_LOG_FILE

  log_info "Creating ca.crt"
  openssl req -x509 -new -nodes \
          -subj "/C=US/ST=NC/O=IBB/CN=ibb-ktunnel-sidecar-injector" \
          -addext "subjectAltName = DNS:ibb-ktunnel-sidecar-injector,DNS:ibb-ktunnel-sidecar-injector.kube-system,DNS:ibb-ktunnel-sidecar-injector.kube-system.svc" \
          -key $IBB_INSTALL_DIR/ktunnel/ca.key \
          -sha256 -days 9999 \
          -out $IBB_INSTALL_DIR/ktunnel/ca.crt | tee -a $IBB_LOG_FILE

  log_info "Creating sidecar-injector.key"
  openssl genrsa -out $IBB_INSTALL_DIR/ktunnel/sidecar-injector.key 2048 | tee -a $IBB_LOG_FILE

  log_info "Creating sidecar-injector.csr"
  openssl req -new -key $IBB_INSTALL_DIR/ktunnel/sidecar-injector.key \
          -out $IBB_INSTALL_DIR/ktunnel/sidecar-injector.csr \
          -addext "subjectAltName = DNS:ibb-ktunnel-sidecar-injector,DNS:ibb-ktunnel-sidecar-injector.kube-system,DNS:ibb-ktunnel-sidecar-injector.kube-system.svc" \
          -subj "/C=US/ST=NC/O=IBB/CN=ibb-ktunnel-sidecar-injector" | tee -a $IBB_LOG_FILE

  log_info "Creating the certificate"
  openssl x509 -req -in $IBB_INSTALL_DIR/ktunnel/sidecar-injector.csr \
          -CA $IBB_INSTALL_DIR/ktunnel/ca.crt -CAkey $IBB_INSTALL_DIR/ktunnel/ca.key \
          -CAcreateserial \
          -out $IBB_INSTALL_DIR/ktunnel/sidecar-injector.crt \
          -days 9999 -sha256 | tee -a $IBB_LOG_FILE


  log_info "Adding IBB Project Helm repository"
  helm repo add ibb https://ibbproject.github.io/helm-charts/ > /dev/null
  log_info "Updating Helm repositories"
  helm repo update > /dev/null
  log_info "Installing ktunnel sidecar injector"
  helm upgrade --install ibb-ktunnel-inejctor ibb/ibb-ktunnel-injector --namespace kube-system --set-file caCrt=$IBB_INSTALL_DIR/ktunnel/ca.crt,sidecarInjectorCrt=$IBB_INSTALL_DIR/ktunnel/sidecar-injector.crt,sidecarInjectorKey=$IBB_INSTALL_DIR/ktunnel/sidecar-injector.key --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE

  log_info "Adding the KTunnel kubeconfig"
  k3s kubectl apply -f $KTUNNEL_KUBECONFIG_SECRET_MANIFEST | tee -a $IBB_LOG_FILE

  set -o noglob
}
