log_err () {
  # [!!!!] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[!!!!]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
}

log_info () {
  # [***] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[****]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
}

log_log () {
  # [----] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[----]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
}

log_fail () {
  # [FAIL] <TAB> 2024-12-31T23:59:59-0600 <TAB> ARG1 ARG2
  echo -e "[FAIL]\t$(date +%Y-%m-%dT%H:%M:%S%z)\t$@" | tee -a $IBB_LOG_FILE
  exit 1
}
