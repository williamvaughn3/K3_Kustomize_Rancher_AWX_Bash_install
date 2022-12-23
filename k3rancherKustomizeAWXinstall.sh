#!/bin/bash

DEFAULT_GW='x.x.x.x'

useradd testuser -m -U -s /bin/bash
usermod -aG sudo,adm testuser
echo "testuser:testpassword" | chpasswd
sed -i 's/%sudo/%sudo ALL=(ALL:ALL) NOPASSWD:ALL #&/' /etc/sudoers

sysctl -w net.ipv6.conf.all.disable_ipv6=0
sysctl -w net.ipv6.conf.default.disable_ipv6=0
apt update
apt upgrade -y

systemctl stop ssh
systemctl disable ssh
route add default gw $DEFAULT_GW

echo 'export PATH=$PATH:/usr/local/go/bin' > /home/testuser/.profile

apt install -y openssh-server ntp net-tools git iptables shellinaboxd \
              python3 \
              pip \
              python3-pip \
              build-essential

apt -y install python-is-python3 -y
python3 -m pip install --upgrade pip
python3 -m pip install --user setuptools -y
python3 -m pip install --user ansible-tower-cli -y
python3 -m pip install --user ansible-core==2.12.3 -y
python3 -m pip install --user argcomplete -y
activate-global-python-argcomplete

echo '[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local
[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/rc-local.service
sudo systemctl enable rc-local
echo  -e 'syslog.target_network'
printf '%s\n' '#!/bin/bash' 'exit 0' | sudo tee -a /etc/rc.local
sudo chmod +x /etc/rc.local
sed -i 's/exit 0//g' /etc/rc.local &&
echo "service shellinaboxd enable
service shellinaboxd startmanager
exit 0
" >> /etc/rc.local

wget https://go.dev/dl/go1.19.linux-amd64.tar.gz && tar -C /usr/local -xvf go1.19.linux-amd64.tar.gz && rm go1.19.linux-amd64.tar.gz
ln -s /usr/local/go/bin/go /usr/bin/go
export PATH=$PATH:/usr/local/go/bin

cd /opt/
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
curl -sfL https://get.k3s.io | sudo bash -
chmod 644 /etc/rancher/k3s/k3s.yaml

kubectl get nodes | tee -a /home/awx_install.log
ln -s /opt/kustomize /usr/local/bin/kustomize

export NAMESPACE=awx
kubectl create ns ${NAMESPACE}
kubectl config set-context --current --namespace=$NAMESPACE

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

kustomize build . | kubectl apply -f -

echo '
    =======================
        AWX INSALL LOG 
    =======================' >> /home/testuser/awx_install.log
RN=$(kubectl get pods | grep awx | cut -d ' ' -f1)
export $RN
for i in {1..10}
  do
    kubectl logs $RN -c awx-manager | tee /home/testuser/awx_install.log
    sleep 10
  done
  
echo 'inital login secret' | tee /home/testuser/login.txt
kubectl get secret awx-admin-password -o jsonpath="{.data.password}" | base64 --decode | tee -a /home/testuser/login.txt

sed d -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config

systemctl enable ssh
systemctl start ssh
systemctl restart sshd

