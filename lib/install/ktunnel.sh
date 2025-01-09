do_ktunnel() {
  if [ "$INSTALL_KTUNNEL" != true ]; then
    log_info "Install KTunnel flag is not true. Skipping KTunnel installation..."
    return 0
  fi
 
   if [ "$DO_UPDATE" == true ]; then
    log_info "Updating KTunnel..."
    update_ktunnel
    log_info "Done."
    return 0
  fi

  # If we make it this far, we should install KTunnel
  log_info "Installing KTunnel..."
  install_ktunnel
  log_info "Done."
}

install_ktunnel () {
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
      --silent \
      --url $PADI_ONBOARDING_CONFIG_URL \
      --header "Authorization: Bearer $TKN" \
      --header "content-type: application/json" \
      | grep -Po '"config":".*"' \
      | cut -d ":" -f2 \
      | tr -d '"' \
      | base64 -d \
      > $KTUNNEL_KUBECONFIG_SECRET_MANIFEST
  fi

  if [ ! -f "$IBB_INSTALL_DIR/ktunnel/csr.conf" ]; then
    log_info "Writing ktunnel csr.conf"
    cat << EOF > "$IBB_INSTALL_DIR/ktunnel/csr.conf"
[ req ]
default_bits        = 2048
default_keyfile     = sidecar-injector.key
distinguished_name  = req_distinguished_name
req_extensions      = req_ext # The extentions to add to the self signed cert
 
[ req_distinguished_name ]
countryName                 = Country Name (2 letter code)
countryName_default         = US
stateOrProvinceName         = State or Province Name (full name)
stateOrProvinceName_default = NC
localityName                = Locality Name (eg, city)
localityName_default        = Ashville
organizationName            = Organization Name (eg, company)
organizationName_default    = IBB
commonName                  = Common Name (eg, YOUR name)
commonName_default          = ibb-ktunnel-sidecar-injector
commonName_max              = 64
 
[ req_ext ]
subjectAltName          = @alt_names

[alt_names]
DNS.1   = ibb-ktunnel-sidecar-injector
DNS.2   = ibb-ktunnel-sidecar-injector.kube-system
DNS.3   = ibb-ktunnel-sidecar-injector.kube-system.svc
EOF
  fi

  # Generate OpenSSL Certificates needed
  log_info "Generating ktunnel certificates and keys..."

  if [ ! -f "$IBB_INSTALL_DIR/ktunnel/ca.key" ]; then
    log_info "Creating ca.key"
    openssl genrsa -out $IBB_INSTALL_DIR/ktunnel/ca.key 4096 | tee -a $IBB_LOG_FILE
  fi

  if [ ! -f "$IBB_INSTALL_DIR/ktunnel/ca.crt" ]; then
    log_info "Creating ca.crt"
    openssl req -x509 -new -nodes \
            -subj "/C=US/ST=NC/O=IBB/CN=ibb-ktunnel-sidecar-injector" \
            -config "$IBB_INSTALL_DIR/ktunnel/csr.conf" \
            -key $IBB_INSTALL_DIR/ktunnel/ca.key \
            -sha256 -days 9999 \
            -out $IBB_INSTALL_DIR/ktunnel/ca.crt | tee -a $IBB_LOG_FILE
  fi


  if [ ! -f "$IBB_INSTALL_DIR/ktunnel/sidecar-injector.key" ]; then
    log_info "Creating sidecar-injector.key"
    openssl genrsa -out $IBB_INSTALL_DIR/ktunnel/sidecar-injector.key 2048 | tee -a $IBB_LOG_FILE
  fi

  if [ ! -f "$IBB_INSTALL_DIR/ktunnel/sidecar-injector.csr" ]; then
    log_info "Creating sidecar-injector.csr"
    openssl req -new -key $IBB_INSTALL_DIR/ktunnel/sidecar-injector.key \
            -out $IBB_INSTALL_DIR/ktunnel/sidecar-injector.csr \
            -config "$IBB_INSTALL_DIR/ktunnel/csr.conf" \
            -subj "/C=US/ST=NC/O=IBB/CN=ibb-ktunnel-sidecar-injector" | tee -a $IBB_LOG_FILE
  fi

  if [ ! -f "$IBB_INSTALL_DIR/ktunnel/sidecar-injector.crt" ]; then
    log_info "Creating the certificate"
    openssl x509 -req -in $IBB_INSTALL_DIR/ktunnel/sidecar-injector.csr \
            -CA $IBB_INSTALL_DIR/ktunnel/ca.crt \
            -CAkey $IBB_INSTALL_DIR/ktunnel/ca.key \
            -CAcreateserial \
            -out $IBB_INSTALL_DIR/ktunnel/sidecar-injector.crt \
            -extensions req_ext \
            -extfile $IBB_INSTALL_DIR/ktunnel/csr.conf \
            -days 9999 -sha256 >> $IBB_LOG_FILE 2>&1
  fi


  update_ktunnel

  log_info "Adding the KTunnel kubeconfig"
  k3s kubectl apply -f $KTUNNEL_KUBECONFIG_SECRET_MANIFEST >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE

  set -o noglob
}


update_ktunnel () {
  # Check that required files are present
  if ! [[ -f "$IBB_INSTALL_DIR/ktunnel/ca.crt" 
    && -f "$IBB_INSTALL_DIR/ktunnel/sidecar-injector.crt" 
    && -f "$IBB_INSTALL_DIR/ktunnel/sidecar-injector.key" 
  ]];
  then
    log_fail "Ktunnel Update Failed. Required files not present. Please run the install script to generate required files"
    exit 1
  fi

  log_info "Updating Helm repositories"
  helm repo update > /dev/null
  log_info "Updating ktunnel sidecar injector"
  helm upgrade --install ibb-ktunnel-inejctor ibb/ibb-ktunnel-injector --namespace kube-system --set-file caCrt=$IBB_INSTALL_DIR/ktunnel/ca.crt,sidecarInjectorCrt=$IBB_INSTALL_DIR/ktunnel/sidecar-injector.crt,sidecarInjectorKey=$IBB_INSTALL_DIR/ktunnel/sidecar-injector.key --wait | tee -a $IBB_LOG_FILE
  
  KTUNNEL_VERSION=$(helm search repo ibb/ibb-ktunnel-injector | tail -n 1 | cut -f2)
  log_info "Success. ibb/ibb-ktunnel-injector is now on version $KTUNNEL_VERSION"
}
