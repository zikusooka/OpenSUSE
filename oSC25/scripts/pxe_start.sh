#!/bin/sh

# Check who is running this script
if [[ "$(id -u)" != "0" ]];
then
	clear
	echo "ERROR: You need to run [$(basename $0)] as root!
"
exit 1
fi


systemctl stop firewalld.service # Being lazy here - > Secure please!

systemctl restart libvirtd.service
virsh net-start default  > /dev/null 2>&1

systemctl restart kea-dhcp4.service

systemctl restart tftp.service

systemctl restart httpd.service


# Bridge with VM
ip link delete tap0
ip tuntap add dev tap0 mode tap
ip link set tap0 up
brctl addif virbr0 tap0
