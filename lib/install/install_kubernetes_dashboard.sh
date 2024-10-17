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
