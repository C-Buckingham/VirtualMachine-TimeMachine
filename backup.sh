#!/bin/bash

# Load the config file if provided
CONFIG_FILE="$1"

if [[ -n "${CONFIG_FILE}" ]]; then
    if [[ -f "${CONFIG_FILE}" ]]; then
        source "${CONFIG_FILE}"
    else
        echo "Config file ${CONFIG_FILE} not found. Exiting."
        exit 1
    fi
fi

# Main backup directory
MAIN_BACKUP_DIR="${MAIN_BACKUP_DIR:-/mnt/remote/backups}"
LOG_FILE="${LOG_FILE:-/var/log/kvm_backup.log}"
MAX_JOBS="${MAX_JOBS:-$(nproc)}"

# Lock file
LOCKFILE="${LOCKFILE:-/var/lock/$(basename $0)}"

# Function to log messages
log() {
    echo "$(date): $1" | tee -a ${LOG_FILE}
}

# Check if another instance of the script is running
if [ -e ${LOCKFILE} ] && kill -0 `cat ${LOCKFILE}`; then
    log "Another instance of this script is running. Exiting."
    exit 1
fi

# Make sure the lockfile is removed when we exit and when we receive a signal
trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT
echo $$ > ${LOCKFILE}

# Function to perform backup
backup() {
    VM=$1

    # Exclude VMs with prefix "Test" and "test"
    if [[ ${VM} =~ ^(Test|test).* ]]; then
        log "Skipping VM: ${VM}"
        return
    fi

    # Check the disk spec
    DISK_PATH=$(virsh domblklist ${VM} --details | grep 'disk' | awk '{print $4}')
    DISK_TYPE=$(virsh domblklist ${VM} --details | grep 'disk' | awk '{print $3}')

    # If disk type is not detected properly, skip the VM
    if [[ -z "${DISK_TYPE}" ]]; then
        log "Could not detect disk type for ${VM}. Skipping..."
        return
    fi

    # Create a backup directory for this VM
    BACKUP_DIR="${MAIN_BACKUP_DIR}/${VM}"
    mkdir -p ${BACKUP_DIR}

    # Check if VM is running
    if virsh domstate "${VM}" | grep -q running; then
        log "Starting backup of running VM: $VM..."

        # Create a snapshot
        SNAPSHOT_PATH="${BACKUP_DIR}/${VM}_snapshot.qcow2"
        virsh snapshot-create-as --domain ${VM} --name backup_snapshot --no-metadata --atomic --disk-only --diskspec ${DISK_TYPE},snapshot=external,file=${SNAPSHOT_PATH}

        if [ $? -eq 0 ]; then
            # Backup the original disk
            BACKUP_FILENAME="${BACKUP_DIR}/${VM}.qcow2"
            qemu-img convert -O qcow2 ${DISK_PATH} ${BACKUP_FILENAME}

            if [ $? -eq 0 ]; then
                log "Backup created at ${BACKUP_FILENAME}"
            else
                log "Failed to create backup for ${VM}."
            fi

            # Merge changes into VM disk, delete snapshot
            virsh blockcommit ${VM} ${DISK_TYPE} --active --verbose --pivot

            # Remove the external snapshot
            rm -f ${SNAPSHOT_PATH}

            log "Backup of $VM completed."
        else
            log "Failed to create a snapshot of $VM."
        fi
    else
        log "Creating a copy of non-running VM: $VM..."

        # Copy the original disk
        BACKUP_FILENAME="${BACKUP_DIR}/${VM}.qcow2"
        cp ${DISK_PATH} ${BACKUP_FILENAME}

        if [ $? -eq 0 ]; then
            log "Copy created at ${BACKUP_FILENAME}"
        else
            log "Failed to create a copy for ${VM}."
        fi
    fi
}

# Create main backup directory if it doesn't exist
if [[ ! -e ${MAIN_BACKUP_DIR} ]]; then
    mkdir -p ${MAIN_BACKUP_DIR}
elif [[ ! -d ${MAIN_BACKUP_DIR} ]]; then
    log "${MAIN_BACKUP_DIR} already exists but is not a directory. Exiting."
    exit 1
fi

# Get list of all VMs
VM_LIST=$(virsh list --name --all)

if [[ -z "${VM_LIST}" ]]; then
    log "No VMs detected. Exiting."
    exit 0
fi

# For each VM
for VM in $VM_LIST; do
    # If the number of background jobs is equal to MAX_JOBS, wait
    while (( $(jobs | wc -l) >= MAX_JOBS )); do
        wait -n
    done

    # Start backup in the background
    backup ${VM} &
done

# Wait for all background jobs to finish
wait

log "All backups completed."

# Remove the lockfile
rm -f ${LOCKFILE}
