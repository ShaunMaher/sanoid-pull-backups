#!/usr/bin/bash

SSH_USERNAME="${SSH_USERNAME:-"syncoid"}"
SSHD_PORT="${SSHD_PORT:-768}"
CHISEL_REMOTE_URL="${CHISEL_REMOTE_URL:-"https://lu.ghanima.net/.chisel"}"
CHISEL_REMOTES="${CHISEL_REMOTES:-"R:10022:localhost:10022"}"
CHISEL_AUTH="${CHISEL_AUTH:-"user:password"}"

useradd -m -d /var/lib/syncoid/${SSH_USERNAME} -u ${UID:-600} ${SSH_USERNAME}
mkdir /var/lib/syncoid/${SSH_USERNAME}/.ssh
chmod 700 /var/lib/syncoid/${SSH_USERNAME}/.ssh
if [ "${SSH_PUBKEY}" != "" ]; then
  echo "${SSH_PUBKEY}" > /var/lib/syncoid/${SSH_USERNAME}/.ssh/authorized_keys
  chmod 600 /var/lib/syncoid/${SSH_USERNAME}/.ssh/authorized_keys
fi

mkdir /run/sshd

# Start the SSH daemon
/usr/sbin/sshd -p ${SSHD_PORT} -D -d -e &

# Start the chisel tunnel
/usr/bin/chisel client -v --auth "${CHISEL_AUTH}" "${CHISEL_REMOTE_URL}" ${CHISEL_REMOTES}