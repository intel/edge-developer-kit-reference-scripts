#!/bin/bash

function die() 
{
    echo >&2 -e "\nERROR: $*\n"
    exit 1
}

function run() 
{ 
    eval "$*"
    code=$?; [ $code -ne 0 ] && die "command [$*] failed with error code $code"; 
}

function resizepartition()
{
    # Identify the root partition (mounted as /)
    root_partition=$(lsblk -nr -o NAME,MOUNTPOINT | grep -w '/' | awk '{print $1}')
    if [ -z "$root_partition" ]; then
        echo "ERROR: Could not identify the root partition."
        exit 1
    fi

    # Identify the disk containing the root partition
    if [[ "$root_partition" == *p* ]]; then
        # Handle nvme naming convention (e.g., nvme0n1p2 -> nvme0n1)
        disk="${root_partition%p*}"
    else
        # Handle standard naming convention (e.g., sda2 -> sda)
        disk="${root_partition%[0-9]*}"
    fi

    echo "Detected disk: /dev/$disk"
    echo "Detected root partition: /dev/$root_partition"

    # Resize the partition to take all unallocated space
    echo "Resizing /dev/$root_partition to take all unallocated space..."
    run "sudo growpart /dev/$disk ${root_partition##*[a-z]}"
    run "sudo resize2fs /dev/$root_partition"

    echo "Successfully resized /dev/$root_partition to take all unallocated space."
}

function add_user_docker()
{
    # Add docker proxy in user account
    run "mkdir -p /home/user/.docker"
    cat > /home/user/.docker/config.json <<'EOF'
{
  "proxies": {
    "default": {
      "httpProxy": "http://proxy-dmz.intel.com:912",
      "httpsProxy": "http://proxy-dmz.intel.com:912",
      "noProxy": "localhost,127.0.0.1,*.intel.com,.intel.com"
    }
  }
}
EOF
    run "chown -R user:user /home/user/.docker"

    # Add user into docker group
    if ! id -nG "user" | grep -qw "docker"; then
        echo "Add user to docker group."
        run "sudo usermod -aG docker user"
        exit 0
    else
        echo "user is already in the docker group."
        exit 0
    fi
}

resizepartition
add_user_docker