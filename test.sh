#!/bin/bash

#
# A shortcut to run install-ibb during the development process
#
#   Usage: sudo ./test.sh
#

# ./install-ibb.sh --no-argocd --no-dapr --no-helm --no-k3s 

# Test that cns-kube is installable
./install-ibb.sh --no-argocd --no-dapr --no-helm --no-k3s  --no-link-padi --no-cns-kube
