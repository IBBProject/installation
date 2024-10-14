notify_complete () {
  if [ "$NOTIFY_COMPLETE" != true ]; then 
    log_info "Notify Complete flag is not true. Skipping sending completion..."
    return 0
  fi
  log_info "Notifying Padi Installation is complete"
  TKN=$(cat /opt/ibb/padi.json | grep -Po '"padiToken":"[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+"' | cut -d ':' -f2 | tr -d '"')
  log_info "Padi token starts with ${TKN:0:8}"
  curl -X POST \
    -H 'content-type: application/json' \
    -H "authorization: bearer $TKN" \
    -d '"online"' \
    https://api.padi.io/thing/client/padi.node/status
  log_info "Notification Complete"
}
