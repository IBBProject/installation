# IBB Setup

Script to take a new machine and install an IBB onto it.

# TODO:

- [x] Write builder script to compile all helper functions into one script
- [ ] Fix KTunnel Install where prompts for user input during Certificate Generation
- [ ] Write checks in ktunnel to check if certs are already installed
- [ ] Write checks for all files to not install again if not needed
- [ ] Write flag to update IBB

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
curl -fsSL https://raw.githubusercontent.com/IBBProject/installation/main/install-ibb.sh | sudo bash -s -- --no-dapr --no-k3s
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

## Development

To add a new feature and/or change existing features, edit the scripts inside the `lib/` directory. Each of these `*.sh` files are dynamically loaded into the `install-ibb.sh` file when you build it. Any changes to the initial variables or flags should be changed in the heredocs inside the `build.sh` file.

## Building

The `install-ibb.sh` is dynamically generated from all the files inside the `lib/` directory. To build the latest `install-ibb.sh` file, simply run `./build.sh`. This will overwrite the existing `install-ibb.sh` file with the latest version.
