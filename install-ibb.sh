#!/bin/bash
set -e
set -o noglob

# Must be a k3s-io tagged release: https://github.com/k3s-io/k3s/releases
K3S_VERSION="v1.25.16+k3s4"
ARGOCD_VERSION="latest"

# Set some Variables you probably will not need to change
IBB_INSTALL_DIR="/opt/ibb"
REQUIRED_BINARIES="curl"
K3S_INSTALL_SCRIPT_FILENAME="ibb-install-k3s.sh"
HELM_INSTALL_SCRIPT_FILENAME="ibb-install-helm.sh"
ARGOCD_NS="argocd"

# Check run as root
if [ "$EUID" -ne 0 ]
then
  echo "[!] Setup must be ran as root. Exiting..."
  exit 1
fi

# Create IBB Install Directory
if [ ! -d "$IBB_INSTALL_DIR" ]; then
  echo "[****] Creating IBB Directory at $IBB_INSTALL_DIR"
  mkdir "$IBB_INSTALL_DIR"
fi

# Check binaries exist on system
for BINARY in $REQUIRED_BINARIES
do
  if [[!  command -v BINARY &> /dev/null ]]
  then
    echo "[!] $BINARY not found. Exiting..."
    exit 1
  fi
done

# Install K3S
if command -v k3s &>/dev/null
then
  echo "[****] Found k3s binary. No need to reinstall."
else
  echo "[****] Installing K3S Version $K3S_VERSION..."
  K3S_INSTALL_FILE="$IBB_INSTALL_DIR/$K3S_INSTALL_SCRIPT_FILENAME"
  if [[ -f "$K3S_INSTALL_FILE" ]]
  then
    rm "$K3S_INSTALL_FILE"
  fi

  curl -sfL https://get.k3s.io > "$K3S_INSTALL_FILE"
  chmod +x "$K3S_INSTALL_FILE"
  INSTALL_K3S_VERSION=$K3S_VERSION $K3S_INSTALL_FILE
fi


# Install Helm
if command -v helm &> /dev/null
then
  echo "[****] found helm binary. No need to reinstall."
else
  echo "[****] Installing helm..."
  HELM_INSTALL_SCRIPT="$IBB_INSTALL_DIR/$HELM_INSTALL_SCRIPT_FILENAME"

  if [[ -f "$HELM_INSTALL_SCRIPT" ]]
  then
    rm "$HELM_INSTALL_SCRIPT"
  fi
  curl -fsSL -o $HELM_INSTALL_SCRIPT https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 $HELM_INSTALL_SCRIPT
  $HELM_INSTALL_SCRIPT
fi

# Install Argo. Requires helm
if [[ "$ARGOCD_VERSION" == "latest" ]]; then
  curl -fsSLo "$IBB_INSTALL_DIR/argocd-install.yaml" https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
else
  echo "[!!!!] Versioning of Argo not yet implemented. Exiting."
  exit 1
fi

k3s kubectl create namespace $ARGOCD_NS --dry-run=client -o yaml | k3s kubectl apply -f -
k3s kubectl apply -n argocd -f "$IBB_INSTALL_DIR/argocd-install.yaml" --wait=true

# Port-forward ArgoCD for users to log in
LOCAL_IP=$(ip route get 8.8.8.8 | head -1 | cut -d' ' -f7)
ARGOCD_INITIAL_PW=$(k3s kubectl get secrets -n $ARGOCD_NS argocd-initial-admin-secret -o json | grep "password" | cut -d'"' -f4 | base64 -d)

PORT_8080_PID=$(lsof -i tcp:8080 | awk 'NR!=1 {print $2}')
if [ ! -z "${PORT_8080_PID}" ]
then
  echo "[****] Killing $PORT_8080_PID"
  kill $PORT_8080_PID > /dev/null
fi

k3s kubectl port-forward --address=0.0.0.0 -n $ARGOCD_NS svc/argocd-server 8080:80 &

echo "[****]"
echo "[****]"
echo "[****] INSTALLATION COMPLETE"
echo "[****] ArgoCD Should be accessable at  https://$LOCAL_IP:8080"
echo "[****]     Username: admin"
echo "[****]     Password: $ARGOCD_INITIAL_PW"
echo "[****]"
echo "[****]"

