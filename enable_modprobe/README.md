# Kubernetes Setup Script

This script automates the setup and configuration of a Kubernetes environment on a Linux system. It handles kernel module loading, system configuration, and container runtime adjustments.

## Overview

This script performs the following tasks:
1. **Installs the kernel-devel package**: Ensures compatibility with the current kernel version.
2. **Loads necessary kernel modules**: Modules required for Kubernetes networking and container management.
3. **Creates configuration files**: Sets up Kubernetes-specific configurations in `/etc/modules-load.d` and `/etc/sysctl.d`.
4. **Disables swap**: Updates `/etc/fstab` to prevent swap usage, which is necessary for Kubernetes.
5. **Updates containerd configuration**: Ensures `SystemdCgroup` is set to `true` for containerd.
6. **Reboots the system**: Applies changes by rebooting the machine.

## Prerequisites

- A Linux-based operating system (e.g., RHEL, CentOS).
- `dnf` package manager (for RHEL/CentOS 8 and later).
- Root or sudo access to execute system commands.

## Usage

1. **Clone the Repository**: If you haven't already, clone the repository containing this script.

    ```bash
    git clone <repository-url>
    cd <repository-directory>
    ```

2. **Make the Script Executable**:

    ```bash
    chmod +x setup-kubernetes.sh
    ```

3. **Run the Script**:

    ```bash
    sudo ./setup-kubernetes.sh
    ```

   The script will prompt you with progress messages and verify each step's success.

## Script Details

### Install kernel-devel Package

Installs the kernel development package matching the current kernel version to ensure compatibility.

### Load Kernel Modules

Loads necessary kernel modules required for Kubernetes. These include:
- `br_netfilter`
- `ip_vs`
- `ip_vs_rr`
- `ip_vs_wrr`
- `ip_vs_sh`
- `overlay`

### Create Configuration Files

- **/etc/modules-load.d/kubernetes.conf**: Specifies kernel modules to load at boot.
- **/etc/sysctl.d/kubernetes.conf**: Configures sysctl settings for Kubernetes networking.

### Disable Swap

Disables swap immediately and comments out swap entries in `/etc/fstab` to prevent swap usage, which is required for Kubernetes.

### Update Containerd Configuration

Updates the containerd configuration to set `SystemdCgroup` to `true`, ensuring proper cgroup management for containers.

### Reboot System

Reboots the system to apply changes and ensure all configurations are active.

