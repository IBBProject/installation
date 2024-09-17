link_ibb_to_padi() {
  if [ "$LINK_TO_PADI" != true ]; then 
    log_info "Link to Padi flag is not true. Skipping..."
    return 1
  fi

  if [ -f "$IBB_INSTALL_DIR/padi.json" ]; then
    log_info "Padi Authorization already found. Skipping..."
    return 0
  fi

  if [ -z "$PADI_INSTALL_CODE" ]; then
    PADI_INSTALL_CODE=$(tr -dc A-Z0-9 </dev/urandom | head -c 6; echo)
  fi
  log_info ""
  log_info ""
  log_info "Please log into IBB Zone and install a new IBB Instance using the following code."
  log_info "For step-by-step instructions visit https://ibbproject.github.io/installation/#connect"
  log_info "" 
  log_info "CODE: $PADI_INSTALL_CODE"
  log_info ""
  read -sen 1 -p "$(log_info 'When complete, press any key to continue...')"
  log_info ""

  MAX_RETRIES=6
  RETRY_COUNT=0
  while [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]
  do
    resp_code=$(curl --write-out '%{http_code}' --silent --output /dev/null -H 'content-type: application/json' $PADI_ONBOARDING_URL/$PADI_INSTALL_CODE)
    log_log "Attempt $RETRY_COUNT of $MAX_RETRIES to $PADI_ONBOARDING_URL/$PADI_INSTALL_CODE was HTTP $resp_code"

    # HTTP 200 is success register, HTTP 403 is fail
    if [ $resp_code -eq 200 ]
    then
      curl -fsSL -o $IBB_INSTALL_DIR/padi.json -H 'content-type: application/json' $PADI_ONBOARDING_URL/$PADI_INSTALL_CODE
      chmod 400 $IBB_INSTALL_DIR/padi.json
      log_info "Successfully registered IBB Instance to Padi"
      return 0
    else
      read -s -e -n 1 -p "$(log_info 'Oops something is not quite right. Please press any key to try again...')"
      RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
  done
  log_fail "Too many failed attempts. Please rerun this installer to try again"
}
