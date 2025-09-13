install_cockpit() {
  if [ "$INSTALL_COCKPIT" != true ]; then 
    log_info "Install cockpit flag is not true. Skipping..."
    return 0
  fi

  log_info "Adding Cockpit apt repository"
  . /etc/os-release
  echo "deb http://deb.debian.org/debian ${VERSION_CODENAME}-backports main" > \
    /etc/apt/sources.list.d/backports.list
  apt update
  log_info "Installing Cockpit"
  apt install -yt ${VERSION_CODENAME}-backports cockpit
  log_info "Installed Cockpit"
  echo << EOF > /etc/cockpit/cockpit.conf
[WebService]
Origins = https://*.staging.padi.io
EOF
  systemctl restart cockpit.socket
}
