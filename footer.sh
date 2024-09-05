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

echo "[****] Installation script version $INSTALL_SCRIPT_VERSION"

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
