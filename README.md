# Nagios Checks for Debian 12

This repository contains various custom Nagios checks for Debian 12 systems, intended to work with the `check_ssh` Nagios plugin. These checks allow you to monitor critical system components, services, and resources on Debian 12 servers remotely via SSH.

## Requirements

- **Nagios Core** (v4 or higher)
- **check_ssh** Nagios plugin installed on the Nagios server (comes with Nagios Plugins package)
- **Debian 12** target machines
- **SSH Access**: Nagios server must have SSH access to the target machines using key-based authentication or proper credentials.

## Repository Structure

- `check_memory.sh`: Script to monitor memory usage (including swap).
- `check_cpu.sh`: Script to monitor CPU usage across all cores.
- `check_swap.sh`: Script to monitor swap usage.
- `check_nfs.sh`: Script to verify if NFS mounts are available and writable.
- `check_ntp.sh`: Script to check if the NTP service is synchronized.
- `check_disk.sh`: Script to monitor disk space usage.
- `check_docker_containers.sh`: Script to monitor Docker container status and resource usage.
- `check_network.sh`: Script to monitor network interface traffic and speed.
  
## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/nagios-checks-debian12.git
