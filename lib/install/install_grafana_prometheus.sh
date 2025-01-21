install_promstack() {
  # Install the Promstack (Prometheus & Grafana). Requires helm

  if [ "$INSTALL_PROMSTACK" != true ]; then 
    log_info "Install Promstack flag is not true. Skipping..."
    return 0
  fi

  if [ ! -d "$PROMSTACK_PATH" ]; then
    mkdir "$PROMSTACK_PATH"
  fi

  if [ ! -f "$IBB_INSTALL_DIR/padi.json" ]; then
    log_err "Padi config not found. Unable to continue with Promstack Install"
    return 0
  fi

  PADI_ID=$(cat $IBB_INSTALL_DIR/padi.json | grep -Po '"padiThing":"([a-zA-Z0-9]+)"' | cut -d ':' -f2 | tr -d '"')
  


  log_info "Adding Prometheus Community Helm repository"
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null
  log_info "Updating Helm repositories"
  helm repo update > /dev/null

  log_info "Writing Promstack Values"
  tee "$PROMSTACK_PATH/values.yaml" > /dev/null <<EOF
grafana:
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default
  dashboards:
    default:
      k3s-cluster-monitoring:
        # Ref: https://grafana.com/grafana/dashboards/15282-k8s-rke-cluster-monitoring/
        gnetId: 15282
        revision: 1
        datasource: Prometheus
      k8s-k3s:
        # Ref: https://grafana.com/grafana/dashboards/15282-k8s-rke-cluster-monitoring/
        gnetId: 16450
        revision: 3
        datasource: Prometheus
  grafana.ini:
    auth.anonymous:
      enabled: true
    dashboards:
      default_home_dashboard_path: "/var/lib/grafana/dashboards/default/k8s-k3s.json"
    security:
      allow_embedding: true
      cookie_secure: true
      cookie_samesite: "none"
  extraContainerVolumes:
    - name: podinfo
      downwardAPI:
        items:
        - path: "annotations"
          fieldRef:
            fieldPath: metadata.annotations
  podAnnotations:
    injector.tunnel.ibbproject.com/request: $INJECTOR_REQUEST
    injector.tunnel.ibbproject.com/tunnelId: "$PADI_ID"
    injector.tunnel.ibbproject.com/tunnelExposePort: "3000"
  extraSecretMounts:
    - name: token
      secretName: piko-token
      mountPath: /etc/piko/mnt
  securityContext:
    runAsNonRoot: false
    runAsUser: 0
    runAsGroup: 0
    fsGroup: 0
EOF


  log_info "Installing Prometheus & Grafana Dashboard"
  helm upgrade --install promstack prometheus-community/kube-prometheus-stack \
    --values $PROMSTACK_PATH/values.yaml \
    --wait | tee -a $IBB_LOG_FILE
}
