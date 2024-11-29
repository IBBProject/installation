#!/bin/bash
set -e
set -o noglob

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This file is dynamically generated. Do not overwrite anything
# in here unless you know what you are doing!
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

INSTALL_SCRIPT_VERSION="1.4.4"

# Must be a k3s-io tagged release: https://github.com/k3s-io/k3s/releases
K3S_VERSION="v1.25.16+k3s4"
ARGOCD_VERSION="latest"
DAPR_VERSION=1.13

# Set some Variables you probably will not need to change
REQUIRED_BINARIES="base64 curl cut git grep openssl tr"

# Paths
IBB_INSTALL_DIR="/opt/ibb"
IBB_LOG_PATH="$IBB_INSTALL_DIR/logs"
IBB_LOG_FILE="$IBB_LOG_PATH/install-$(date +%Y-%m-%dT%H:%M:%S%z).log"
IBB_DOWNLOAD_PATH="$IBB_INSTALL_DIR/downloads"
IBB_KTUNNEL_PATH="$IBB_INSTALL_DIR/ktunnel"
IBB_INJECTOR_PATH="$IBB_INSTALL_DIR/injector"
IBB_K8S_DASHBOARD_PATH="$IBB_INSTALL_DIR/k8s-dashboard"
PROMSTACK_PATH="$IBB_INSTALL_DIR/prometheus"

# Filenames
KTUNNEL_KUBECONFIG_SECRET_MANIFEST="$IBB_KTUNNEL_PATH/ktunnel-auth.yaml"
K3S_INSTALL_SCRIPT_FILENAME="ibb-install-k3s.sh"
HELM_INSTALL_SCRIPT_FILENAME="ibb-install-helm.sh"

# Namespaces
ARGOCD_NS="argocd"
DAPR_NS="dapr-system"
IBB_NS="ibb"
K8S_DASHBOARD_NS="kubernetes-dashboard"
IBB_AUTH_SECRET_NAME="ibb-authorization"

# URLS
PADI_ONBOARDING_URL="https://api.padi.io/onboarding"
PADI_ONBOARDING_CONFIG_URL="https://api.padi.io/onboarding/config/ktunnel"

# Variables set inside functions that need a global scope
ARGOCD_ADMIN_PW=""
PADI_INSTALL_CODE=""
KUBERNETES_DASHBOARD_BEARER_TOKEN=""
KTUNNEL_INJECTOR_REQUEST="ibb-ktunnel"

# Set default installations
DO_UPDATE=false
DO_UPGRADE=false
INSTALL_ARGOCD=false
INSTALL_CNS_DAPR=true
INSTALL_CNS_KUBE=true
INSTALL_DAPR=true
INSTALL_HELM=true
INSTALL_K3S=true
INSTALL_K9S=true
INSTALL_KTUNNEL=false
INSTALL_INJECTOR=true
INSTALL_K8S_DASHBOARD=false
INSTALL_PROMSTACK=true
LINK_TO_PADI=true
NOTIFY_COMPLETE=true
PORT_FORWARD_ARGOCD=true
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

check_root () {
  # Check that script is running as root
  if [ "$EUID" -ne 0 ]
  then
    log_fail "Setup must be ran as root."
  fi
}

check_uninstall () {
  # Uninstall IBB
  if [ "$UNINSTALL" = true ]; then
    log_info "Uninstalling K3S"
    /usr/local/bin/k3s-uninstall.sh || true
    log_info "Deleting IBB Directory"
    rm -rvf "$IBB_INSTALL_DIR" || true
    echo "[****] IBB has been Uninstalled"
    exit 0
  fi
}

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

display_complete () {
  log_info ""
  log_info ""
  log_info "INSTALLATION COMPLETE"
  log_info ""
  log_info ""
}

do_helm() {
  if [ "$INSTALL_HELM" != true ]; then 
    log_info "Install helm flag is not true. Skipping helm installation..."
    return 0
  fi

  if [ "$DO_UPGRADE" == true ]; then
    log_info "Upgrading Helm..."
    install_helm
    log_info "Done."
    return 0
  fi

  if command -v helm &>/dev/null
  then
    log_info "Found helm binary. No need to reinstall."
  else
    log_info "Installing helm..."
    install_helm
    log_info "Done."
  fi
}

install_helm () {
  HELM_INSTALL_SCRIPT="$IBB_DOWNLOAD_PATH/$HELM_INSTALL_SCRIPT_FILENAME"
  if [[ -f "$HELM_INSTALL_SCRIPT" ]]
  then
    rm "$HELM_INSTALL_SCRIPT"
  fi
  curl -fsSL -o $HELM_INSTALL_SCRIPT https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 $HELM_INSTALL_SCRIPT
  $HELM_INSTALL_SCRIPT | tee -a $IBB_LOG_FILE
  
  log_info "Adding IBB Project Helm repository"
  helm repo add ibb https://ibbproject.github.io/helm-charts/ >> $IBB_LOG_FILE
  log_info "Updating Helm repositories"
  helm repo update >> $IBB_LOG_FILE
}

install_argocd () {
  # Install Argo. Requires helm
  if [ "$INSTALL_ARGOCD" != true ]; then 
    log_info "Install argo flag is not true. Skipping..."
    return 0
  fi

  if [[ "$ARGOCD_VERSION" == "latest" ]]; then
    log_info "Downloading ArgoCD Manifest"
    curl -fsSLo "$IBB_DOWNLOAD_PATH/argocd-install.yaml" https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  else
    log_fail "Versioning of Argo not yet implemented. Exiting."
  fi

  log_info "Installing ArgoCD. This will take a moment"
  k3s kubectl create namespace $ARGOCD_NS --dry-run=client -o yaml | k3s kubectl apply -f - >> $IBB_LOG_FILE
  k3s kubectl apply -n $ARGOCD_NS -f "$IBB_DOWNLOAD_PATH/argocd-install.yaml" --wait=true >> $IBB_LOG_FILE
  until k3s kubectl get secrets -n $ARGOCD_NS argocd-initial-admin-secret > /dev/null 2>&1
  do
    log_info "Waiting for ArgoCD Cluster to become available"
    sleep 10
  done
  ARGOCD_ADMIN_PW=$(k3s kubectl get secrets -n $ARGOCD_NS argocd-initial-admin-secret -o json | grep "password" | cut -d'"' -f4 | base64 -d)
}

install_cns_dapr () {
  # Install CNS Dapr and it's Redis dependency. Requires helm
  if [ "$INSTALL_CNS_DAPR" != true ]; then 
    log_info "Install cns-dapr flag is not true. Skipping..."
    return 0
  fi

  log_info "Updating Helm repositories"
  helm repo update > /dev/null
  log_info "Installing redis"
  helm upgrade --install ibb-redis ibb/ibb-redis --namespace default --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE

  # Create IBB Authentication Secrets
  k3s kubectl create namespace $IBB_NS --dry-run=client -o yaml | k3s kubectl apply -f - >> $IBB_LOG_FILE
  if [ ! -f "$IBB_INSTALL_DIR/padi.json" ]; then log_fail "Authentication Not found"; fi
  PADI_ID=$(cat /opt/ibb/padi.json | grep -Po '"padiThing":"([a-zA-Z0-9]+)"' | cut -d ':' -f2 | tr -d '"')
  PADI_TOKEN=$(cat /opt/ibb/padi.json | grep -Po '"padiToken":"[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"' | cut -d ':' -f2 | tr -d '"')
  log_info "Padi Token ${PADI_TOKEN:0:8}"
  if [ -z ${PADI_ID+x} ] || [ -z ${PADI_TOKEN+x} ]; then
    log_fail "Padi ID or Token not set. Exiting"
  fi
  k3s kubectl create secret generic $IBB_AUTH_SECRET_NAME --namespace $IBB_NS --dry-run=client --from-literal=id=$PADI_ID --from-literal=token=$PADI_TOKEN -o yaml | k3s kubectl apply -f - >> $IBB_LOG_FILE

  # Install CNS Dapr
  log_info "Installing CNS Dapr"
  helm upgrade --install ibb-cns-dapr ibb/ibb-cns-dapr --namespace $IBB_NS --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE

  log_info "CNS Dapr Installed"
}

install_cns_kube () {
  # Install CNS Kube
  if [ "$INSTALL_CNS_KUBE" != true ]; then 
    log_info "Install cns-kube flag is not true. Skipping..."
    return 0
  fi

  log_info "Updating Helm repositories"
  helm repo update > /dev/null

  # Verify that IBB Authentication Secret exists
  k3s kubectl get secret --namespace $IBB_NS $IBB_AUTH_SECRET_NAME > /dev/null
  SECRET_EXISTS=$?

  if [ $SECRET_EXISTS -gt 0 ]; then
    log_fail "CNS Kube Authentication Secret does not exist."
  fi

  # Install CNS Kube
  log_info "Installing CNS Kube"
  helm upgrade --install ibb-cns-kube ibb/ibb-cns-kube --namespace $IBB_NS --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE

  log_info "CNS Kube Installed"
}

install_dapr() {
  if [ "$INSTALL_DAPR" != true ]; then 
    log_info "Install dapr flag is not true. Skipping..."
    return 0
  fi
  DAPR_HELM_REPO="https://dapr.github.io/helm-charts"
  log_info "Adding Dapr Helm Repo"
  helm repo add dapr "$DAPR_HELM_REPO" > /dev/null
  log_info "Updating Helm Repos"
  helm repo update > /dev/null
  log_info "Installing dapr"
  helm upgrade --install dapr dapr/dapr --namespace $DAPR_NS --create-namespace --version "$DAPR_VERSION" --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE
  log_info "Finished installing dapr"
}

install_promstack() {
  # Install the Promstack (Prometheus & Grafana). Requires helm

  if [ "$INSTALL_PROMSTACK" != true ]; then 
    log_info "Install Promstack flag is not true. Skipping..."
    return 0
  fi

  if [ ! -d "$PROMSTACK_PATH" ]; then
    mkdir "$PROMSTACK_PATH"
  fi

  log_info "Adding Prometheus Community Helm repository"
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null
  log_info "Updating Helm repositories"
  helm repo update > /dev/null

  if [ ! -f "$PROMSTACK_PATH/values.yaml" ]; then
    log_info "Writing Promstack Values"
    LOWER_PADI_INSTALL_CODE=$(echo $PADI_INSTALL_CODE | tr '[:upper:]' '[:lower:]')
    tee "$PROMSTACK_PATH/values.yaml" > /dev/null <<EOF
grafana:
  extraContainerVolumes:
    - name: podinfo
      downwardAPI:
        items:
        - path: "labels"
          fieldRef:
            fieldPath: metadata.labels
        - path: "annotations"
          fieldRef:
            fieldPath: metadata.annotations
  extraSecretMounts:
    - name: kubeconfig
      secretName: kubeconfig
      mountPath: /root/.kube/config
  podAnnotations:
    injector.ktunnel.ibbproject.com/request: $KTUNNEL_INJECTOR_REQUEST
  podLabels:
    injector.ktunnel.ibbproject.com/id: kt-$LOWER_PADI_INSTALL_CODE
    injector.ktunnel.ibbproject.com/port: "3000"
  securityContext:
    runAsNonRoot: false
    runAsUser: 0
    runAsGroup: 0
    fsGroup: 0
EOF
  fi


  log_info "Installing Prometheus & Grafana Dashboard"
  helm upgrade --install promstack prometheus-community/kube-prometheus-stack \
    --values $PROMSTACK_PATH/values.yaml \
    --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE
}

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

  # if [ ! -f "$KTUNNEL_KUBECONFIG_SECRET_MANIFEST" ]; then
  #   log_info "Could not find $KTUNNEL_KUBECONFIG_SECRET_MANIFEST file. Downloading..."

  #   if [ ! -f "$IBB_INSTALL_DIR/padi.json" ]; then
  #     log_fail "Could not find authorization file. Failing"
  #   fi

  #   set +o noglob

  #   TKN=$( \
  #     cat "$IBB_INSTALL_DIR/padi.json" \
  #     | grep -Po '"padiToken":"[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"' \
  #     | cut -d ':' -f2 \
  #     | tr -d '"' \
  #   )

  #   # Fail if token is less than 150 chars
  #   if [ "${#TKN}" -lt 150 ]; then
  #     echo "Padi token looks incorrect. Failing."
  #   fi

  #   # Make CURL request to Padi to get manifest file
  #   curl --request GET \
  #     --silent \
  #     --url $PADI_ONBOARDING_CONFIG_URL \
  #     --header "Authorization: Bearer $TKN" \
  #     --header "content-type: application/json" \
  #     | grep -Po '"config":".*"' \
  #     | cut -d ":" -f2 \
  #     | tr -d '"' \
  #     | base64 -d \
  #     > $KTUNNEL_KUBECONFIG_SECRET_MANIFEST
  # fi

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

  log_info "[TODO] Adding the piko tunnel secrets"
  # k3s kubectl apply -f $KTUNNEL_KUBECONFIG_SECRET_MANIFEST >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE

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
    --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE
  
  INJECTOR_VERSION=$(helm search repo ibb/ibb-injector | tail -n 1 | cut -f2)
  log_info "Success. ibb/ibb-injector is now on version $INJECTOR_VERSION"
}

install_k9s () {
  # Install Argo. Requires helm
  if [ "$INSTALL_K9S" != true ]; then 
    log_info "Install k9s flag is not true. Skipping..."
    return 0
  fi

  log_info "Installing K9s. This will take a moment"
  curl -fsSLo "/tmp/k9s.deb" https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.deb
  dpkg -i /tmp/k9s.deb
}

install_kubernetes_dashboard() {
  # Install the Kubernetes Dashboard. Requires helm
  #
  # TODO: Tunneling with ktunnel ADuss 2024-10-11
  #
  if [ "$INSTALL_K8S_DASHBOARD" != true ]; then 
    log_info "Install Kubernetes Dashboard flag is not true. Skipping..."
    return 0
  fi

  if [ ! -d "$IBB_K8S_DASHBOARD_PATH" ]; then
    mkdir "$IBB_K8S_DASHBOARD_PATH"
  fi

  log_info "Adding Kubernetes Dashboard Helm repository"
  helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/ > /dev/null
  log_info "Updating Helm repositories"
  helm repo update > /dev/null

  if [ ! -f "$IBB_K8S_DASHBOARD_PATH/service-account.yaml" ]; then
    log_info "Writing Kubernetes Dashboard service-account.yaml"
    tee "$IBB_K8S_DASHBOARD_PATH/service-account.yaml" > /dev/null <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: $K8S_DASHBOARD_NS
EOF
  fi

  if [ ! -f "$IBB_K8S_DASHBOARD_PATH/cluster-role-binding.yaml" ]; then
    log_info "Writing Kubernetes Dashboard cluster-role-binding.yaml"
    tee "$IBB_K8S_DASHBOARD_PATH/cluster-role-binding.yaml" > /dev/null <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: $K8S_DASHBOARD_NS
EOF
  fi

  log_info "Installing Kubernetes Dashboard"
  helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
    --create-namespace --namespace $K8S_DASHBOARD_NS \
    --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE

  log_info "Adding Kubernetes Dashboard Service Account"
  k3s kubectl apply -n $K8S_DASHBOARD_NS -f "$IBB_K8S_DASHBOARD_PATH/service-account.yaml" \
    --wait=true >> $IBB_LOG_FILE
  log_info "Adding Kubernetes Dashboard CRB"
  k3s kubectl apply -n $K8S_DASHBOARD_NS -f "$IBB_K8S_DASHBOARD_PATH/cluster-role-binding.yaml" \
    --wait=true >> $IBB_LOG_FILE
  log_info "Generating Kubernetes Dashboard Token"
  KUBERNETES_DASHBOARD_BEARER_TOKEN=$(kubectl -n $K8S_DASHBOARD_NS create token admin-user)
  log_info "Kubernetes Dashboard Bearer Token"
  echo $KUBERNETES_DASHBOARD_BEARER_TOKEN | tee -a "$IBB_K8S_DASHBOARD_PATH/token.txt"
}

do_k3s() {
  if [ "$INSTALL_K3S" != true ]; then 
    log_info "Install K3s flag is not true. Skipping K3S installation..."
    return 0
  fi

  if [ "$DO_UPGRADE" == true ]; then
    log_info "Upgrading K3S..."
    update_k3s
    log_info "Done."
    return 0
  fi

  log_info "Upgrading K3S..."
  install_k3s
  log_info "Done."
}

install_k3s () {
  if command -v k3s &>/dev/null
  then
    log_info "Found k3s binary. No need to reinstall."
    return 0
  else
    upgrade_k3s
  fi

  if [ ! -f "$HOME/.kube/config" ]; then
    log_info "No kubeconfig found. Creating..."
    mkdir -p $HOME/.kube
    cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
    chmod 600 $HOME/.kube/config
  else
    log_info "Kubeconfig found. Skipping."
  fi
}

upgrade_k3s() {
  log_info "Installing K3S Version $K3S_VERSION..."
  K3S_INSTALL_FILE="$IBB_DOWNLOAD_PATH/$K3S_INSTALL_SCRIPT_FILENAME"
  if [[ -f "$K3S_INSTALL_FILE" ]]
  then
    rm "$K3S_INSTALL_FILE"
  fi
  curl -sfL https://get.k3s.io > "$K3S_INSTALL_FILE"
  chmod +x "$K3S_INSTALL_FILE"
  INSTALL_K3S_VERSION=$K3S_VERSION $K3S_INSTALL_FILE | tee -a $IBB_LOG_FILE
}
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
  helm upgrade --install ibb-ktunnel-inejctor ibb/ibb-ktunnel-injector --namespace kube-system --set-file caCrt=$IBB_INSTALL_DIR/ktunnel/ca.crt,sidecarInjectorCrt=$IBB_INSTALL_DIR/ktunnel/sidecar-injector.crt,sidecarInjectorKey=$IBB_INSTALL_DIR/ktunnel/sidecar-injector.key --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE
  
  KTUNNEL_VERSION=$(helm search repo ibb/ibb-ktunnel-injector | tail -n 1 | cut -f2)
  log_info "Success. ibb/ibb-ktunnel-injector is now on version $KTUNNEL_VERSION"
}

link_ibb_to_padi() {
  if [ "$LINK_TO_PADI" != true ]; then 
    log_info "Link to Padi flag is not true. Skipping..."
    return 0
  fi

  if [ -f "$IBB_INSTALL_DIR/padi.json" ]; then
    log_info "Padi Authorization already found. Skipping..."
    return 0
  fi

  if [ -z "$PADI_INSTALL_CODE" ]; then
    PADI_INSTALL_CODE=$(tr -dc A-Z0-9 </dev/urandom | head -c 6; echo)
  fi
  log_info ""
  log_info ""
  log_info "Please log into IBB Zone and install a new IBB Instance using the following code."
  log_info "For step-by-step instructions visit https://ibbproject.github.io/installation/#connect"
  log_info "" 
  log_info "CODE: $PADI_INSTALL_CODE"
  log_info ""
  read -sen 1 -p "$(log_info 'When complete, press any key to continue...')"
  log_info ""

  MAX_RETRIES=6
  RETRY_COUNT=0
  while [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]
  do
    resp_code=$(curl --write-out '%{http_code}' --silent --output /dev/null -H 'content-type: application/json' $PADI_ONBOARDING_URL/$PADI_INSTALL_CODE)
    log_log "Attempt $RETRY_COUNT of $MAX_RETRIES to $PADI_ONBOARDING_URL/$PADI_INSTALL_CODE was HTTP $resp_code"

    # HTTP 200 is success register, HTTP 403 is fail
    if [ $resp_code -eq 200 ]
    then
      curl -fsSL -o $IBB_INSTALL_DIR/padi.json -H 'content-type: application/json' $PADI_ONBOARDING_URL/$PADI_INSTALL_CODE
      chmod 400 $IBB_INSTALL_DIR/padi.json
      log_info "Successfully registered IBB Instance to Padi"
      return 0
    else
      read -s -e -n 1 -p "$(log_info 'Oops something is not quite right. Please press any key to try again...')"
      RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
  done
  log_fail "Too many failed attempts. Please rerun this installer to try again"
}

log_err () {
  # [!!!!] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[!!!!]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
}

log_info () {
  # [***] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[****]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
}

log_log () {
  # [----] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[----]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" >> $IBB_LOG_FILE
}

log_fail () {
  # [FAIL] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[FAIL]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
  exit 1
}

notify_complete () {
  if [ "$NOTIFY_COMPLETE" != true ]; then 
    log_info "Notify Complete flag is not true. Skipping sending completion..."
    return 0
  fi
  log_info "Notifying Padi Installation is complete"
  TKN=$(cat /opt/ibb/padi.json | grep -Po '"padiToken":"[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"' | cut -d ':' -f2 | tr -d '"')
  log_info "Padi token starts with ${TKN:0:8}"
  curl -X POST \
    -H 'content-type: application/json' \
    -H "authorization: bearer $TKN" \
    -d '"online"' \
    https://api.padi.io/thing/client/padi.node/status
  log_info "Notification Complete"
}

port_forward_argocd () {
  # Port-forward ArgoCD for users to log in
  if [ "$INSTALL_ARGOCD" != true ]; then 
    log_info "Port forwarding of ArgoCd is not true. Skipping."
    return 0
  fi
  LOCAL_IP=$(ip route get 8.8.8.8 | head -1 | cut -d' ' -f7)
  PORT=8080

  # Kill any other processes running on port 8080 
  PORT_8080_PID=$(lsof -i tcp:$PORT | awk 'NR!=1 {print $2}')
  if [ ! -z "${PORT_8080_PID}" ]
  then
    echo "[****] Killing $PORT_8080_PID"
    kill $PORT_8080_PID > /dev/null
  fi

  k3s kubectl port-forward --address=0.0.0.0 -n $ARGOCD_NS svc/argocd-server $PORT:80 &
}

# Start the script
while [[ $# -gt 0 ]]; do
  case $1 in
    --install-dir)
      IBB_INSTALL_DIR=$2
      shift
      shift
      ;;
    --install-code)
      PADI_INSTALL_CODE=$2
      shift
      shift
      ;;
    --ktunnel-kubeconfig-secret-file)
      KTUNNEL_KUBECONFIG_SECRET_MANIFEST=$2
      shift
      shift
      ;;
    --no-argocd)
      INSTALL_ARGOCD=false
      shift
      ;;
    --no-cns-dapr)
      INSTALL_CNS_DAPR=false
      shift
      ;;
    --no-cns-kube)
      INSTALL_CNS_KUBE=false
      shift
      ;;
    --no-dapr)
      INSTALL_DAPR=false
      shift
      ;;
    --no-helm)
      INSTALL_HELM=false
      shift
      ;;
    --no-k3s)
      INSTALL_K3S=false
      shift
      ;;
    --no-notify-complete)
      NOTIFY_COMPLETE=false
      shift
      ;;
    --no-link-padi)
      LINK_TO_PADI=false
      shift
      ;;
    --no-install-injector)
      INSTALL_INJECTOR=false
      shift
      ;;
    --no-install-k8s-dashboard)
      INSTALL_K8S_DASHBOARD=false
      shift
      ;;
    --no-install-promstack)
      INSTALL_PROMSTACK=false
      shift
      ;;
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    --update)
      DO_UPDATE=true
      shift
      ;;
    --upgrade)
      DO_UPGRADE=true
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

echo "[****] Installation script version $INSTALL_SCRIPT_VERSION"

# Check the system is compatable
check_root
check_uninstall
create_ibb_install_dir
check_required_binaries

# Install the "IBB" software - Kubernetes and Helm
do_k3s
do_helm
install_k9s

# Link must be done before KTunnel, CNS-Dapr, or CNS-Kube can be installed
link_ibb_to_padi
do_injector
install_dapr

install_cns_dapr
install_cns_kube
notify_complete


# install_argocd
# install_kubernetes_dashboard
# install_promstack

# display_complete
