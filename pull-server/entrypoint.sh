#!/bin/sh

useradd -m -d /var/lib/syncoid/${USERNAME} -u ${UID:-600} ${USERNAME}
mkdir /var/lib/syncoid/${USERNAME}/.ssh
chmod 700 /var/lib/syncoid/${USERNAME}/.ssh
echo "${PUBKEY}" > /var/lib/syncoid/${USERNAME}/.ssh/authorized_keys
chmod 600 /var/lib/syncoid/${USERNAME}/.ssh/authorized_keys

mkdir /run/sshd
/usr/sbin/sshd