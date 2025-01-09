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

  if [ ! -f "$IBB_INJECTOR_PATH/csr.conf" ]; then
    log_info "Writing injector csr.conf"
    cat << EOF > "$IBB_INJECTOR_PATH/csr.conf"
[ req ]
default_bits        = 2048
default_keyfile     = sidecar-injector.key
distinguished_name  = req_distinguished_name
req_extensions      = req_ext

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
commonName_default          = ibb-injector
commonName_max              = 64

[ req_ext ]
subjectAltName          = @alt_names

[alt_names]
DNS.1   = ibb-injector
DNS.2   = ibb-injector.kube-system
DNS.3   = ibb-injector.kube-system.svc
EOF
  fi

  # Generate OpenSSL Certificates needed
  log_info "Generating injector certificates and keys..."

  if [ ! -f "$IBB_INJECTOR_PATH/ca.key" ]; then
    log_info "Creating ca.key"
    openssl genrsa -out $IBB_INJECTOR_PATH/ca.key 4096 | tee -a $IBB_LOG_FILE
  fi

  if [ ! -f "$IBB_INJECTOR_PATH/ca.crt" ]; then
    log_info "Creating ca.crt"
    openssl req -x509 -new -nodes \
            -subj "/C=US/ST=NC/O=IBB/CN=ibb-injector" \
            -config "$IBB_INJECTOR_PATH/csr.conf" \
            -key $IBB_INJECTOR_PATH/ca.key \
            -sha256 -days 9999 \
            -out $IBB_INJECTOR_PATH/ca.crt | tee -a $IBB_LOG_FILE
  fi


  if [ ! -f "$IBB_INJECTOR_PATH/sidecar-injector.key" ]; then
    log_info "Creating sidecar-injector.key"
    openssl genrsa -out $IBB_INJECTOR_PATH/sidecar-injector.key 2048 | tee -a $IBB_LOG_FILE
  fi

  if [ ! -f "$IBB_INJECTOR_PATH/sidecar-injector.csr" ]; then
    log_info "Creating sidecar-injector.csr"
    openssl req -new -key $IBB_INJECTOR_PATH/sidecar-injector.key \
            -out $IBB_INJECTOR_PATH/sidecar-injector.csr \
            -config "$IBB_INJECTOR_PATH/csr.conf" \
            -subj "/C=US/ST=NC/O=IBB/CN=ibb-injector" | tee -a $IBB_LOG_FILE
  fi

  if [ ! -f "$IBB_INJECTOR_PATH/sidecar-injector.crt" ]; then
    log_info "Creating the certificate"
    openssl x509 -req -in $IBB_INJECTOR_PATH/sidecar-injector.csr \
            -CA $IBB_INJECTOR_PATH/ca.crt \
            -CAkey $IBB_INJECTOR_PATH/ca.key \
            -CAcreateserial \
            -out $IBB_INJECTOR_PATH/sidecar-injector.crt \
            -extensions req_ext \
            -extfile $IBB_INJECTOR_PATH/csr.conf \
            -days 9999 -sha256 >> $IBB_LOG_FILE 2>&1
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

    k3s kubectl create secret generic -n default piko-token --from-file=$INJECTOR_TOKEN_PATH >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE
  fi
  set -o noglob
}


update_injector () {
  # Check that required files are present
  # TODO: Check certificate validity and update if needed
  if ! [[ -f "$IBB_INJECTOR_PATH/ca.crt" 
    && -f "$IBB_INJECTOR_PATH/sidecar-injector.crt" 
    && -f "$IBB_INJECTOR_PATH/sidecar-injector.key" 
  ]];
  then
    log_fail "Sidecar injector update failed. Required files not present. Please run the install script to generate required files"
    exit 1
  fi

  log_info "Updating Helm repositories"
  helm repo update > /dev/null
  log_info "Updating sidecar injector"
  helm upgrade --install ibb-injector \
    ibb/ibb-injector \
    --namespace kube-system \
    --set-file injector.caCrt=$IBB_INJECTOR_PATH/ca.crt \
    --set-file injector.sidecarInjectorCrt=$IBB_INJECTOR_PATH/sidecar-injector.crt \
    --set-file injector.sidecarInjectorKey=$IBB_INJECTOR_PATH/sidecar-injector.key \
    --wait | tee -a $IBB_LOG_FILE
  
  INJECTOR_VERSION=$(helm search repo ibb/ibb-injector | tail -n 1 | cut -f2)
  log_info "Success. ibb/ibb-injector is now on version $INJECTOR_VERSION"
}
