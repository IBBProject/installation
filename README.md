# IBB Setup

A scripted installation to transform an ordinary linux server and transform it into an IBB.

# Known Bugs:

- [ ] Piping curl to bash does not allow the proper wait for the code input.
- [ ] Updating the IBB needs lots of work.
- [ ] KTunnel/Grafana does not work on Digital Ocean Droplets:
    `http: TLS handshake error from 10.42.0.1:60768: remote error: tls: bad certificate`

# Usage

To install an IBB, simply run the following on a linux server:

```
curl -fsSL https://raw.githubusercontent.com/IBBProject/installation/main/install-ibb.sh > install.sh
sudo bash install.sh
```

or if you need to add arguments:

```
curl -fsSL https://raw.githubusercontent.com/IBBProject/installation/main/install-ibb.sh > install.sh
sudo bash install.sh --no-dapr --no-k3s
```

See Known Bugs

~~curl -fsSL https://raw.githubusercontent.com/IBBProject/installation/main/install-ibb.sh | sudo bash -s -- --no-dapr --no-k3s~~

## Arguments

`--install-dir` --> The location on disk you want to store IBB files. Default `/opt/ibb`

`--install-code` --> Use your own installation code during the linking process

`--uninstall` --> Uninstall K3S and delete the IBB Directory on the IBB server

#### Uncommon Arguments

`--no-argocd` --> Do not install Argo CD

`--no-cns-dapr` --> Do not install CNS Dapr

`--no-dapr` --> Do not install Dapr

`--no-helm` --> Do not install helm

`--no-k3s` --> Do not install K3S

`--no-link-padi` --> Do not prompt to link IBB with Padi

`--ktunnel-kubeconfig-secret-file` --> Filepath to the kubernetes secret manifest for ktunnel

`--no-cns-kube` --> Do not install cns-kube

`--no-notify-complete` --> Do not update the linked IBB status in Padi

`--no-install-ktunnel` --> Do not install ktunnel

## Development

To add a new feature and/or change existing features, edit the scripts inside the `lib/` directory. Each of these `*.sh` files are dynamically loaded into the `install-ibb.sh` file when you build it. Any changes to initial or global variables should be made to `header.sh` so they're included at the top of the compiled script. Command line arguments should be changed in the `footer.sh` file, where the start of the actual script resides.

## Building

The `install-ibb.sh` is dynamically generated from all the files inside the `lib/` directory. To build the latest `install-ibb.sh` file, simply run `./build-install-file.sh`. This will overwrite the existing `install-ibb.sh` file with the latest version.

