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
    --log-level)
      LOG_LEVEL=$2
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
    --install-cns-haystack)
      INSTALL_CNS_HAYSTACK=true
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
    --version|-v)
      echo "$INSTALL_SCRIPT_VERSION"
      exit 0
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

# Link must be done before Injector, CNS-Dapr, or CNS-Kube can be installed
link_ibb_to_padi
do_injector
install_dapr

install_cns_dapr
install_cns_kube
install_cns_haystack


# install_argocd
# install_kubernetes_dashboard
install_promstack

notify_complete
display_complete
