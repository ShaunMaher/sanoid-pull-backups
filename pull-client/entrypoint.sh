#!/usr/bin/bash

SSH_USERNAME="${SSH_USERNAME:-"syncoid"}"
SSHD_PORT="${SSHD_PORT:-768}"
CHISEL_REMOTE_URL="${CHISEL_REMOTE_URL:-"https://lu.ghanima.net/.well-known/chisel"}"
CHISEL_REMOTES="${CHISEL_REMOTES:-"R:0.0.0.0:10022:localhost:768/tcp"}"
CHISEL_AUTH="${CHISEL_AUTH:-"user:password"}"
SSH_UID="${USER_UID:-"600"}"

mkdir -p /var/lib/syncoid/
if [ $(getent passwd "${SSH_USERNAME}" || echo $?) -ne 0 ]; then
  printf '%b\n' "Creating user '${SSH_USERNAME}'."
  useradd -m -d /var/lib/syncoid/${SSH_USERNAME} -u ${SSH_UID} ${SSH_USERNAME}
fi
mkdir -p /var/lib/syncoid/${SSH_USERNAME}/.ssh
chmod 700 /var/lib/syncoid/${SSH_USERNAME}/.ssh
if [ "${SSH_PUBKEY}" != "" ]; then
  echo "${SSH_PUBKEY}" > /var/lib/syncoid/${SSH_USERNAME}/.ssh/authorized_keys
  chmod 600 /var/lib/syncoid/${SSH_USERNAME}/.ssh/authorized_keys
fi
chown -R ${SSH_USERNAME}:${SSH_USERNAME} /var/lib/syncoid/${SSH_USERNAME}/.ssh/

mkdir -p /run/sshd

# Start the SSH daemon
if [ $(pgrep sshd >/dev/null; echo $?) -eq 0 ]; then
  kill $(pgrep sshd)
fi
setsid --fork /usr/sbin/sshd -p ${SSHD_PORT} -o LogLevel=DEBUG -e

# Start the chisel tunnel
/usr/bin/chisel client -v --auth "${CHISEL_AUTH}" "${CHISEL_REMOTE_URL}" ${CHISEL_REMOTES}