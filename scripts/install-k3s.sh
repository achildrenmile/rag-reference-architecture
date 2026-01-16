#!/bin/bash
# Install k3s on Ubuntu for RAG Reference Architecture
# Run this on rag-node-01

set -e

echo "=========================================="
echo "k3s Installation for RAG Reference Architecture"
echo "=========================================="

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo"
   exit 1
fi

echo ""
echo "[1/5] Configuring system settings..."

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load kernel modules
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Sysctl settings
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
vm.max_map_count                    = 262144
EOF

sysctl --system

echo ""
echo "[2/5] Installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --disable servicelb" sh -

echo ""
echo "[3/5] Waiting for k3s to be ready..."
sleep 10
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo ""
echo "[4/5] Setting up kubeconfig for user..."
SUDO_USER_HOME=$(getent passwd ${SUDO_USER:-$USER} | cut -d: -f6)
mkdir -p "$SUDO_USER_HOME/.kube"
cp /etc/rancher/k3s/k3s.yaml "$SUDO_USER_HOME/.kube/config"
chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$SUDO_USER_HOME/.kube"
chmod 600 "$SUDO_USER_HOME/.kube/config"

echo ""
echo "[5/5] Verifying installation..."
kubectl get nodes
kubectl get pods -A

echo ""
echo "=========================================="
echo "k3s installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Log out and back in (or run: export KUBECONFIG=~/.kube/config)"
echo "  2. Create secrets: cp k8s/overlays/production/secrets.yaml.example k8s/overlays/production/secrets.yaml"
echo "  3. Edit secrets.yaml with real values"
echo "  4. Run: ./scripts/deploy-k3s.sh"
echo "=========================================="
