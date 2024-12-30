#!/bin/sh

echo 'deb http://download.opensuse.org/repositories/home:/alvistack/xUbuntu_24.04/ /' | sudo tee /etc/apt/sources.list.d/home:alvistack.list
curl -fsSL https://download.opensuse.org/repositories/home:alvistack/xUbuntu_24.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_alvistack.gpg > /dev/null
sudo apt update
sudo apt install cri-o cri-o-runc fuse-overlayfs
sudo systemctl enable crio
sudo systemctl start crio

