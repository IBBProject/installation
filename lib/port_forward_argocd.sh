port_forward_argocd () {
  # Port-forward ArgoCD for users to log in
  if [ "$INSTALL_ARGOCD" != true ]; then 
    log_info "Port forwarding of ArgoCd is not true. Skipping."
    return 1
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
