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
