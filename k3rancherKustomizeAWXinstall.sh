#!/bin/bash

sudo useradd testuser -m -U -s /bin/bash
sudo usermod -aG sudo,adm testuser
sudo echo "testuser:testpassword" | chpasswd
sudo sed -i 's/%sudo/%sudo ALL=(ALL:ALL) NOPASSWD:ALL #&/' /etc/sudoers

sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0
sudo apt update
sudo apt upgrade -y
sudo 
sudo echo 'export PATH=$PATH:/usr/local/go/bin' > /home/testuser/.profile

sudo apt install -y openssh-server ntp net-tools git iptables shellinabox \
              python3 \
              pip \
              python3-pip \
              build-essential

sudo apt -y install python-is-python3 -y

sudo pip3 install --upgrade pip
sudo pip3 install --user setuptools
sudo pip3 install --user ansible-tower-cli
sudo pip3 install --user ansible-core==2.12.3 
sudo pip3 install --user argcomplete
activate-global-python-argcomplete

cd /opt/
sudo curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | sudo bash -
sudo curl -sfL https://get.k3s.io | sudo bash -
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

sudo kubectl get nodes | tee -a /home/awx_install.log
sudo ln -s /opt/kustomize /usr/local/bin/kustomize

export NAMESPACE=awx
sudo kubectl create ns ${NAMESPACE}
sudo kubectl config set-context --current --namespace=$NAMESPACE

echo "
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - github.com/ansible/awx-operator/config/default?ref=0.18.0
#  - AWX_Y3czd2N2Cg.yaml
images:
  - name: quay.io/ansible/awx-operator
  - newTag: 0.18.0
namespace: awx
" > kustomization.yaml
kustomize build . | kubectl apply -f -
sed -i s/'#'//g kustomization.yaml

echo ' 
---
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
spec:
  service_type: nodeport
  nodeport_port: 30000
  projects_persistence: true
  projects_storage_class: rook-ceph
  projects_storage_size: 50Gi
  secret_key_secret: "Y3czd2N2Cg=="' \
 > AWX_Y3czd2N2Cg.yaml

sudo kustomize build . | kubectl apply -f - && for i in 

echo 'inital login secret' | tee /home/testuser/login.txt

sudo kubectl get secret awx-admin-password -o jsonpath="{.data.password}" | base64 --decode | tee -a /home/testuser/login.txt

sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo systemctl restart sshd

