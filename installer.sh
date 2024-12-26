sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

VERSION=1.32
NVIDIA_VERSION=535-server


sudo apt-get install -y nvidia-driver-$NVIDIA_VERSION nvidia-utils-$NVIDIA_VERSION apt-transport-https ca-certificates curl software-properties-common make  

PACKAGES="nvtop kubectl nvidia-container-toolkit-base docker-ce sudo apt-get install -y nvidia-container-toolkit"

curl -fsSL https://pkgs.k8s.io/core:/stable:/v$VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

sudo add-apt-repository ppa:longsleep/golang-backports
sudo apt-get install golang

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list


curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

wget https://github.com/derailed/k9s/releases/download/v0.32.7/k9s_linux_amd64.deb
yes | sudo dpkg -i k9s_linux_amd64.deb

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 --output /tmp/get-helm-3
chmod +x /tmp/get-helm-3
sudo /tmp/get-helm-3

[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.26.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

sudo apt-get update 
sudo apt-get install -y $PACKAGES 
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker
sudo usermod -aG docker ${USER}

sudo nvidia-ctk runtime configure --runtime=docker --set-as-default --cdi.enabled
sudo nvidia-ctk config --set accept-nvidia-visible-devices-as-volume-mounts=true --in-place
sudo systemctl restart docker

git clone https://github.com/NVIDIA/nvkind.git
cd nvkind
make
sudo cp nvkind /usr/local/bin/
