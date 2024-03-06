+++
title = "VMWare view on Steam Deck"
date = 2024-03-06

[taxonomies]
tags = ["steam-deck", "vmware", "linux", "distrobox"]
+++

Using distrobox we are able to install VMware horizon client on the Steam Deck, without it breaking on image updates. Surprisingly, I found using a Arch container image to be the smoothest option. This will also work on Fedora Atomic Desktop.

<!-- more -->

## The set up

* Distrobox with Arch linux
* YAY as AUR helper
* distrobox-export to create desktop shortcut

## How to install

```bash

# exports to make it possible to run GUI apps from distrobox
cat <<EOF >> ~/.distrobox.rc
xhost +si:localuser:\$USER
export PIPEWIRE_RUNTIME_DIR=/dev/null
export PATH=\$PATH:\$HOME/.local/bin
EOF

# Create distrobox Arch container
distrobox create arch --image quay.io/toolbx/arch-toolbox:latest -Y
distrobox enter arch

# Install yay
sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm
yay -Y --gendb

# Install VMware-view dependencies, and vm-ware view from AUR using yay
sudo pacman -S libpulse libxkbfile --noconfirm
yay -S vmware-horizon-client --noconfirm

# Create desktop shortcut for VMware-view
distrobox-export --app vmware-view

# Exit out of distrobox
exit
```

You should now be able to find VMware-view in your desktop environment.
