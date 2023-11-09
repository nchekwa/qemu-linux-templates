#!/bin/bash


root_pasword=root
url="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
file_path=$(basename "$url")

# ### Set Debug in case of troubleshooting
#export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1


echo "[      ] Install local tools necessary to run virt..."
if [ -e /etc/os-release ]; then
    source /etc/os-release
    if [ "$ID" == "ubuntu" ]; then
        echo "[      ] Running on Ubuntu"
        # Your Ubuntu installation commands here
        apt update -y && apt install nano wget curl libguestfs-tools libvirt-login-shell p7zip -y
    else
        echo "[FAILED] Unsupported distribution: $ID"
        exit 1
    fi
else
    echo "Unable to determine distribution."
    exit 1
fi


echo "[   ISO] Download UBUNTU img if not exist"
if [ ! -e "$file_path" ]; then
    echo "[      ] File does not exist. Downloading..."
    wget "$url"
else
    echo "[      ] File already exists."
fi






echo "[    TZ] set timezone UTC"
virt-customize -a $file_path --timezone UTC



echo "[   SSH] enable password auth to yes"
virt-customize -a $file_path --run-command 'sed -i s/^PasswordAuthentication.*/PasswordAuthentication\ yes/ /etc/ssh/sshd_config'
echo "[   SSH] allow root login with ssh-key only"
virt-customize -a $file_path --run-command 'sed -i s/^#PermitRootLogin.*/PermitRootLogin\ yes/ /etc/ssh/sshd_config'
echo "[   SSH] Generate Keys"
virt-customize -a $file_path --run-command '/usr/bin/ssh-keygen -A'

echo "[  DISK] - increase sda disk to 100G (original is 2.2GB)"
qemu-img resize $file_path +98G
echo "[  DISK] - change sda1 partition size"
virt-customize -a $file_path --run-command "growpart /dev/sda 1 &&  resize2fs /dev/sda1"
# virt-filesystems --long --parts --blkdevs -h -a $file_path


echo "[   APT] Add agent to image"
virt-customize -a $file_path --run-command 'apt-get update && apt-get upgrade -y'


echo "[   APT] Uninstall some libs"
#virt-customize -a $file_path --run-command 'apt-get purge -y netplan.io libnetplan0'
virt-customize -a $file_path --run-command 'apt-get purge -y docker.io containerd runc php7.4* php8*'
virt-customize -a $file_path --run-command 'dpkg --configure -a'


echo "[   APT] Install basic tools"
virt-customize -a $file_path --install ifenslave,ntp,unzip,zip,mc,screen,gcc,make,wget,curl,telnet,traceroute,tcptraceroute,sudo,gnupg,ca-certificates,nfs-common,aria2,qemu-utils


echo "[ GUEST] Install guest agents"
virt-customize -a $file_path --install qemu-guest-agent,open-vm-tools

echo "[ACCESS] set root password"
virt-sysprep -a $file_path --root-password password:$root_pasword

echo "[  DONE] Done.."
mv $file_path virtioa.qcow2
