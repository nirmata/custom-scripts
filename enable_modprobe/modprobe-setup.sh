#!/bin/bash

# Exit on error
set -e

# Retry function with verification and output capture
retry_command() {
    local cmd="$1"
    local verification_cmd="$2"
    local verification_msg="$3"
    local retries=2
    local count=0
    local success=0

    while [ $count -lt $retries ]; do
        echo "Attempt $((count + 1)) for command: $cmd"
        if eval "$cmd"; then
            echo "Verification: $verification_cmd"
            local verification_output
            verification_output=$(eval "$verification_cmd" 2>&1)
            if [ $? -eq 0 ]; then
                echo "$verification_msg"
                success=1
                break
            else
                echo "Verification failed. Output:"
                echo "$verification_output"
                echo "Retrying..."
            fi
        else
            echo "Command failed. Retrying..."
        fi
        count=$((count + 1))
        sleep 2
    done

    if [ $success -ne 1 ]; then
        echo "Command failed after $retries attempts. Please try this manually: $cmd"
        exit 1
    fi
}

# Install kernel-devel package for the current kernel version
echo "===================="
echo "Installing kernel-devel package..."
echo "===================="
retry_command "sudo dnf install -y kernel-devel-$(uname -r)" "rpm -q kernel-devel-$(uname -r)" "Kernel-devel package installed successfully."
echo "--------------------"

# Load necessary kernel modules
echo "===================="
echo "Loading kernel modules..."
echo "===================="
retry_command "sudo modprobe br_netfilter" "lsmod | grep br_netfilter" "Module br_netfilter loaded successfully."
retry_command "sudo modprobe ip_vs" "lsmod | grep ip_vs" "Module ip_vs loaded successfully."
retry_command "sudo modprobe ip_vs_rr" "lsmod | grep ip_vs_rr" "Module ip_vs_rr loaded successfully."
retry_command "sudo modprobe ip_vs_wrr" "lsmod | grep ip_vs_wrr" "Module ip_vs_wrr loaded successfully."
retry_command "sudo modprobe ip_vs_sh" "lsmod | grep ip_vs_sh" "Module ip_vs_sh loaded successfully."
retry_command "sudo modprobe overlay" "lsmod | grep overlay" "Module overlay loaded successfully."
echo "--------------------"

# Create configuration files for Kubernetes
echo "===================="
echo "Creating /etc/modules-load.d/kubernetes.conf..."
echo "===================="
retry_command "cat > /etc/modules-load.d/kubernetes.conf << EOF
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
overlay
EOF" "grep 'br_netfilter' /etc/modules-load.d/kubernetes.conf && grep 'ip_vs' /etc/modules-load.d/kubernetes.conf && grep 'ip_vs_rr' /etc/modules-load.d/kubernetes.conf && grep 'ip_vs_wrr' /etc/modules-load.d/kubernetes.conf && grep 'ip_vs_sh' /etc/modules-load.d/kubernetes.conf && grep 'overlay' /etc/modules-load.d/kubernetes.conf" "Configuration file /etc/modules-load.d/kubernetes.conf created successfully."
echo "--------------------"

echo "===================="
echo "Creating /etc/sysctl.d/kubernetes.conf..."
echo "===================="
retry_command "cat > /etc/sysctl.d/kubernetes.conf << EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF" "grep 'net.ipv4.ip_forward = 1' /etc/sysctl.d/kubernetes.conf && grep 'net.bridge.bridge-nf-call-ip6tables = 1' /etc/sysctl.d/kubernetes.conf && grep 'net.bridge.bridge-nf-call-iptables = 1' /etc/sysctl.d/kubernetes.conf" "Configuration file /etc/sysctl.d/kubernetes.conf created successfully."
echo "--------------------"

# Disable swap by commenting out the swap line in /etc/fstab
echo "===================="
echo "Disabling swap..."
echo "===================="
# Disable swap immediately
sudo swapoff -a
echo   "Swap disabled successfully."
# Comment out swap entries in /etc/fstab
#retry_command "sudo sed -i '/swap/s/^/#/' /etc/fstab" "grep '^#' /etc/fstab" "Swap disabled successfully."
echo "--------------------"

# Update containerd config
echo "===================="
echo "Updating containerd configuration..."
echo "===================="
# Remove existing systemd_cgroup setting if present
retry_command "sudo sed -i '/systemd_cgroup/d' /etc/containerd/config.toml" "grep 'systemd_cgroup' /etc/containerd/config.toml || true" "Existing systemd_cgroup setting removed successfully."
# Set SystemdCgroup = true
retry_command "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml" "grep 'SystemdCgroup = true' /etc/containerd/config.toml" "Containerd configuration updated successfully."
echo "--------------------"

# Reboot the system
echo "===================="
echo "Rebooting the system..."
echo "===================="
retry_command "sudo systemctl reboot" "systemctl is-system-running --quiet" "System reboot initiated successfully."
