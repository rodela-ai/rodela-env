#!/bin/bash

# Function to check if the user has root privileges
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
  fi
}

# Function to unmount CRI-O-related filesystems
unmount_crio_filesystems() {
  echo "Searching for CRI-O-related filesystems to unmount..."
  
  # List all mounted filesystems and filter CRI-O-related ones
  mount | grep -E "/var/lib/containers/storage|/var/run" | while read -r line; do
    # Extract the mount point
    mount_point=$(echo "$line" | awk '{print $3}')
    
    # Unmount the filesystem
    echo "Unmounting $mount_point..."
    umount "$mount_point" 2>/dev/null
    
    # Check if unmount was successful
    if [ $? -eq 0 ]; then
      echo "Successfully unmounted: $mount_point"
    else
      echo "Failed to unmount: $mount_point (it might be in use or already unmounted)"
    fi
  done
}

# Main script execution
#check_root
unmount_crio_filesystems
echo "CRI-O unmount process completed."

