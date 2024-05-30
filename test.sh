#!/bin/bash

#
# A shortcut to run install-ibb during the development process
#
#   Usage: sudo ./test.sh
#

# ./install-ibb.sh --no-argocd --no-dapr --no-helm --no-k3s 

# ./install-ibb.sh \
#   --ktunnel-kubeconfig-secret-file $HOME/ktunnel-kubeconfig.yaml \
#   --no-argocd \
#   --no-cns-dapr \
#   --no-cns-kube \
#   --no-dapr \
#   --no-helm \
#   --no-k3s  \
#   --no-link-padi

./install-ibb.sh \
  --ktunnel-kubeconfig-secret-file $HOME/ktunnel-kubeconfig.yaml
