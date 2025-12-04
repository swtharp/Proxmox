#!/bin/bash                                                                                                               >
# run script /usr/bin/back.sh my-pbs-bucket-daily  
# my-pbs-bucket-daily
# my-pbs-bucket-monthly
# my-pbs-bucket-weekly
# my-pbs-bucket-yearly

# --- Configuration ---
# Proxmox Backup Server (PBS) details
echo "$2"
PBS_SERVER="192.168.3.76"
PBS_USER="root@pam" # Or @pbs if using PBS realm
PBS_PASSWORD="sherw00d" # Consider using a keyfile for better security
PBS_DATASTORE="$2"
PBS_FINGERPRINT="e5:81:8b:4d:fb:38:be:7d:fc:af:fd:9e:6d:5a:df:68:3d:20:3c:cd:2c:fc:40:06:c8:84:cd:f0:4a:1e:36:77" 
# Backup content (e.g., specific directories or archives)
# Example: backup /etc and /var/log
BACKUP_CONTENT="root.pxar:/"
REPO="root@pam@192.168.3.76:$2"
echo "$REPO"
# Encryption key (if using client-side encryption)
# PVE_ENCRYPTION_KEY_FILE="/path/to/your/encryption_keyfile" # Uncomment and set if needed

# --- Backup Command ---
# Export password for non-interactive login (use with caution, consider keyfiles)
export PBS_PASSWORD="$PBS_PASSWORD"
export PBS_FINGERPRINT="$PBS_FINGERPRINT"

# Execute the proxmox-backup-client command
proxmox-backup-client backup \
    --repository "$REPO" \
    $BACKUP_CONTENT \
    # --keyfile "$PVE_ENCRYPTION_KEY_FILE" \ # Uncomment if using encryption
    # Add any other desired options like --exclude, --include-dev etc.
# Unset password for security
unset PBS_PASSWORD

# --- Error Handling (Optional) ---
if [ $? -eq 0 ]; then
    echo "Proxmox Backup Client backup completed successfully."
else
    echo "Proxmox Backup Client backup failed." >&2
    exit 1
fi
