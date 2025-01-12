
INSTALL_SCRIPT_VERSION="2.2.3"

# Must be a k3s-io tagged release: https://github.com/k3s-io/k3s/releases
K3S_VERSION="v1.25.16+k3s4"
ARGOCD_VERSION="latest"
DAPR_VERSION=1.13
LOG_LEVEL=info

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
INJECTOR_TOKEN_PATH=$IBB_INJECTOR_PATH/token
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
PADI_ONBOARDING_PIKO_URL="https://api.padi.io/onboarding/config/piko"

# Variables set inside functions that need a global scope
ARGOCD_ADMIN_PW=""
PADI_INSTALL_CODE=""
KUBERNETES_DASHBOARD_BEARER_TOKEN=""
KTUNNEL_INJECTOR_REQUEST="ibb-ktunnel"
INJECTOR_REQUEST="piko-sidecar"

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
