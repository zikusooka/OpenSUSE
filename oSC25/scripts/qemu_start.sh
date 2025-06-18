#!/bin/sh

TYPE=$1

REPO_IMAGES_ISO="https://download.opensuse.org/repositories/systemsmanagement:/Agama:/Devel/images/iso"

USER_HOME=$(eval echo "~${SUDO_USER}")
VM_DIR=${USER_HOME}/VMs
SCRIPTS_DIR=${USER_HOME}/Scripts
DOWNLOADS_DIR=${USER_HOME}/Downloads

OS_IMAGE_ISO_NAME=agama-installer.x86_64-openSUSE.iso
OS_IMAGE_ISO_FILE=${DOWNLOADS_DIR}/${OS_IMAGE_ISO_NAME}
DISK_FILE_SIZE=20g
DISK_FILE_FORMAT=qcow2
DISK_FILE=${VM_DIR}/openSUSE-agama.${DISK_FILE_FORMAT}

FLOPPY_FILE_FORMAT=raw
FLOPPY_FILE=${VM_DIR}/floppy.img

PXE_START_SCRIPT=${SCRIPTS_DIR}/pxe_start.sh



clear
cat <<ET
      ____   ____ ____  ____                 _                               
  ___/ ___| / ___|___ \| ___|               / \   __ _  __ _ _ __ ___   __ _ 
 / _ \___ \| |     __) |___ \    _____     / _ \ / _\` |/ _\` | '_ \` _ \ / _\` |
| (_) |__) | |___ / __/ ___) |  |_____|   / ___ \ (_| | (_| | | | | | | (_| |
 \___/____/ \____|_____|____/            /_/   \_\__, |\__,_|_| |_| |_|\__,_|
                                                 |___/                       


This script is available at: https://github.com/zikusooka/OpenSUSE/tree/main/oSC25/scripts/$(basename $0)

Free free to use and modify as you see fit

Press enter to proceed ...

ET
read


# Start TFTP/PXE, DHCP, HTTP ... 
clear
echo "

Starting PXE and VM services, please wait ....
"
${PXE_START_SCRIPT} 
PXE=$?
[[ "$PXE" = "0" ]] || exit 1


# Download ISO
echo "
Downloading ${OS_IMAGE_ISO_NAME} ...
"
[[ -d ${DOWNLOADS_DIR} ]] || mkdir -p ${DOWNLOADS_DIR}
wget -c ${REPO_IMAGES_ISO}/${OS_IMAGE_ISO_NAME} -P ${DOWNLOADS_DIR} 

# Create directory to store vms
[[ -d ${VM_DIR} ]] || mkdir -p ${VM_DIR}

# Create disk image if non-existent
[[ -s ${DISK_FILE} ]] || \
	qemu-img create -f ${DISK_FILE_FORMAT} ${DISK_FILE} ${DISK_FILE_SIZE}

# Create floppy image if non-existent
[[ -s ${FLOPPY_FILE} ]] || \
qemu-img create -f ${FLOPPY_FILE_FORMAT} ${FLOPPY_FILE} 1.44M


# Start VM
case ${TYPE} in
pxe)
	# PXE
	qemu-system-x86_64 \
		-cpu host \
		-accel kvm \
		-m 3072 \
		-smp 2 \
		-netdev user,id=net0,net=192.168.124.0/24,tftp=/var/lib/tftpboot/,bootfile=/pxelinux.0 \
		-device virtio-net-pci,netdev=net0 \
		-serial stdio \
		-boot n \
		-drive file=${DISK_FILE},format=${DISK_FILE_FORMAT} \
		-drive file=${FLOPPY_FILE},format=${FLOPPY_FILE_FORMAT},if=floppy
;;

iso)
	# ISO
	qemu-system-x86_64 \
		-cpu host \
		-accel kvm \
		-m 3072 \
		-smp 2 \
		-cdrom ${OS_IMAGE_ISO_FILE} \
		-netdev tap,id=net0,ifname=tap0,script=no,downscript=no \
		-device virtio-net,netdev=net0 \
		-serial stdio \
		-boot d \
		-drive file=${DISK_FILE},format=${DISK_FILE_FORMAT},media=disk \
		-drive file=${FLOPPY_FILE},format=${FLOPPY_FILE_FORMAT},if=floppy
	;;
*)
	clear
	cat <<ET
Usage: $(basename $0)  [iso|pxe]

ET
;;

esac
