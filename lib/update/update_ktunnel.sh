update_ktunnel () {
  log_info "Updating Helm repositories"
  helm repo update > /dev/null
  log_info "Updating ktunnel sidecar injector"
  helm upgrade --install ibb-ktunnel-inejctor ibb/ibb-ktunnel-injector --namespace kube-system --set-file caCrt=$IBB_INSTALL_DIR/ktunnel/ca.crt,sidecarInjectorCrt=$IBB_INSTALL_DIR/ktunnel/sidecar-injector.crt,sidecarInjectorKey=$IBB_INSTALL_DIR/ktunnel/sidecar-injector.key --wait >> $IBB_LOG_FILE 2>> $IBB_LOG_FILE
  KTUNNEL_VERSION=$(helm search repo ibb/ibb-ktunnel-injector | tail -n 1 | cut -f2)
  log_info "Success. ibb/ibb-ktunnel-injector is now on version $KTUNNEL_VERSION"
}