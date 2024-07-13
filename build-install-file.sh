#!/bin/bash
set -e

#
# Automated script to generate a standalone install file.
#

THIS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

INSTALL_FILENAME=install-ibb.sh

# Wrapping 'EOF' in quotes negates variable expansion
cat <<-'EOF' > $INSTALL_FILENAME
#!/bin/bash
set -e
set -o noglob

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This `install-ibb.sh` file is dynamically generated. Do not overwrite anything
# in here unless you know what you are doing!
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


# Must be a k3s-io tagged release: https://github.com/k3s-io/k3s/releases
K3S_VERSION="v1.25.16+k3s4"
ARGOCD_VERSION="latest"
DAPR_VERSION=1.13

# Set some Variables you probably will not need to change
IBB_INSTALL_DIR="/opt/ibb"
IBB_LOG_PATH="$IBB_INSTALL_DIR/logs"
IBB_LOG_FILE="$IBB_LOG_PATH/install.log"
IBB_DOWNLOAD_PATH="$IBB_INSTALL_DIR/downloads"
IBB_KTUNNEL_PATH="$IBB_INSTALL_DIR/ktunnel"
REQUIRED_BINARIES="base64 curl cut git grep openssl tr"
K3S_INSTALL_SCRIPT_FILENAME="ibb-install-k3s.sh"
HELM_INSTALL_SCRIPT_FILENAME="ibb-install-helm.sh"
ARGOCD_NS="argocd"
DAPR_NS="dapr-system"
IBB_NS="ibb"
IBB_AUTH_SECRET_NAME="ibb-authorization"
PADI_ONBOARDING_URL="https://api.padi.io/onboarding"
PADI_ONBOARDING_CONFIG_URL="https://api.padi.io/onboarding/config/ktunnel"
KTUNNEL_KUBECONFIG_SECRET_MANIFEST="$IBB_KTUNNEL_PATH/ktunnel-auth.yaml"

# Variables set inside functions that need a global scope
ARGOCD_ADMIN_PW=""
PADI_INSTALL_CODE=""

# Set default installations
INSTALL_ARGOCD=false
INSTALL_CNS_DAPR=true
INSTALL_CNS_KUBE=true
INSTALL_DAPR=true
INSTALL_HELM=true
INSTALL_K3S=true
INSTALL_KTUNNEL=true
LINK_TO_PADI=true
NOTIFY_COMPLETE=true
PORT_FORWARD_ARGOCD=true

EOF


# Cat all the lib/*.sh files into `install-ibb.sh`
for f in $THIS_SCRIPT_DIR/lib/*.sh ; do
  cat $f >> $INSTALL_FILENAME
  echo "" >> $INSTALL_FILENAME
done


# Wrapping 'EOF' in quotes negates variable expansion
cat <<-'EOF' >> $INSTALL_FILENAME
# Start the script
while [[ $# -gt 0 ]]; do
  case $1 in
    --install-dir)
      IBB_INSTALL_DIR=$2
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
    --no-install-ktunnel)
      INSTALL_KTUNNEL=false
      shift
      ;;
    --uninstall)
      UNINSTALL=true
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

check_root
check_uninstall
create_ibb_install_dir
check_required_binaries

install_k3s
install_helm

# Link must be done before KTunnel, CNS-Dapr, or CNS-Kube can be installed
link_ibb_to_padi
install_ktunnel
install_dapr

install_cns_dapr
install_cns_kube
notify_complete

display_complete
EOF

echo "[*] Successfully created $INSTALL_FILENAME file."