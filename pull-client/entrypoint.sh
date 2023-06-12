#!/usr/bin/bash

SSH_USERNAME="${SSH_USERNAME:-"syncoid"}"
SSHD_PORT="${SSHD_PORT:-768}"
CHISEL_REMOTE_URL="${CHISEL_REMOTE_URL:-"https://lu.ghanima.net/.well-known/chisel"}"
CHISEL_REMOTES="${CHISEL_REMOTES:-"R:0.0.0.0:10022:localhost:768/tcp"}"
CHISEL_AUTH="${CHISEL_AUTH:-"user:password"}"
SSH_UID="${USER_UID:-"600"}"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
GRAY='\033[1;90m'
NC='\033[0m' # No Color

function verbose() {
  if test ! -t 0; then
    while read LINE; do
      printf '%b\n' "${YELLOW}${1}${LINE}${NC}"
    done < <(cat </dev/stdin)
  elif test -n "$1"; then
    printf '%b\n' "${YELLOW}${1}${NC}"
  fi
}

function debug() {
  if test ! -t 0; then
    while read LINE; do
      printf '%b\n' "${GRAY}${1}${LINE}${NC}"
    done < <(cat </dev/stdin)
  elif test -n "$1"; then
    printf '%b\n' "${GRAY}${1}${NC}"
  fi
}

function info() {
  if test ! -t 0; then
    while read LINE; do
      printf '%b\n' "${GREEN}${1}${LINE}${NC}"
    done < <(cat </dev/stdin)
  elif test -n "$1"; then
    printf '%b\n' "${GREEN}${1}${NC}"
  fi
}

function error() {
  if test ! -t 0; then
    while read LINE; do
      printf '%b\n' "${RED}${1}${LINE}${NC}"
    done < <(cat </dev/stdin)
  elif test -n "$1"; then
    printf '%b\n' "${RED}${1}${NC}"
  fi
}

mkdir -p /var/lib/syncoid/
if [ $(getent passwd "${SSH_USERNAME}" || echo $?) -ne 0 ]; then
  info "Creating user '${SSH_USERNAME}'."
  useradd -m -d /var/lib/syncoid/${SSH_USERNAME} -u ${SSH_UID} ${SSH_USERNAME}
fi
mkdir -p /var/lib/syncoid/${SSH_USERNAME}/.ssh
chmod 700 /var/lib/syncoid/${SSH_USERNAME}/.ssh
if [ "${SSH_PUBKEY}" != "" ]; then
  info "Creating 'authorized_keys' for ${SSH_USERNAME}."
  echo "${SSH_PUBKEY}" > /var/lib/syncoid/${SSH_USERNAME}/.ssh/authorized_keys
  chmod 600 /var/lib/syncoid/${SSH_USERNAME}/.ssh/authorized_keys
fi
chown -R ${SSH_USERNAME}:${SSH_USERNAME} /var/lib/syncoid/${SSH_USERNAME}/.ssh/

mkdir -p /run/sshd

# Start the SSH daemon
if [ $(pgrep sshd >/dev/null; echo $?) -eq 0 ]; then
  info "Stopping the existing sshd instance."
  kill $(pgrep sshd)
fi
info "Starting sshd."
setsid --fork /usr/sbin/sshd -p ${SSHD_PORT} -o LogLevel=DEBUG -e 2> >(debug)

# Start the chisel tunnel
/usr/bin/chisel client -v --auth "${CHISEL_AUTH}" "${CHISEL_REMOTE_URL}" ${CHISEL_REMOTES} 2> >(error "chisel: " 1>&2) | debug "chisel: "