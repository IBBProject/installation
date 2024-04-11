# IBB Setup

Script to take a new machine and install an IBB onto it.


# Usage

Download this file and run

```
sudo ./install-ibb.sh
```

or if you live on the edge

```
curl -fsSL https://raw.githubusercontent.com/IBBProject/installation/main/install-ibb.sh | sudo bash
```

# Custom Variables

Insert these variables into your bash call between `sudo` and `./install-ibb.sh`:

```
sudo ARGOCD_VERSION=1.14 K3S_VERSION=v1.24.1+k3s ./install-ibb.sh
```

```
ARGOCD_NS         --> The Kubernetes namespace in which to install ArgoCD into. Note: ArgoCD installer creates some resources that default to the `argocd` namespace and cannot be changed here.
ARGOCD_VERSION    --> TODO: Install a specific version of ArgoCD onto the IBB Cluster
K3S_VERSION       --> The version of K3S you wish to install. Must be a valid release [1]
IBB_INSTALL_DIR   --> The directory where all the IBB installation files will be downloaded and saved
REQUIRED_BINARIES --> A space-separated list of binary names that must be installed. The list is checked and fails if the specific binary is not found
```

Notes:

[1]: See releases at https://github.com/k3s-io/k3s/releases


