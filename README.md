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

or if you need args:

```
curl -fsSL https://raw.githubusercontent.com/IBBProject/installation/main/install-ibb.sh | sudo bash -s -- --argument-flag
```

## Flags

`--install-dir` --> The location on disk you want to store IBB files. Default `/opt/ibb`
`--no-argocd` --> Do not install Argo CD
`--no-cns-dapr` --> Do not install CNS Dapr
`--no-dapr` --> Do not install Dapr
`--no-helm` --> Do not install helm
`--no-k3s` --> Do not install K3S
`--no-link-padi` --> Do not prompt to link IBB with Padi
`--uninstall` --> Uninstall K3S and delete the IBB Directory

# Custom Variables

Insert these variables into your bash call between `sudo` and `./install-ibb.sh`:

```
sudo ARGOCD_VERSION=1.14 K3S_VERSION=v1.24.1+k3s DAPR_VERSION=1.13 ./install-ibb.sh
```

See the top of install-ibb.sh for more variables

