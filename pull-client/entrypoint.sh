#!/usr/bin/bash

SSHD_PORT="${SSHD_PORT:-768}"
CHISEL_REMOTE_URL="${CHISEL_REMOTE_URL:-"https://lu.ghanima.net/.chisel"}"
CHISEL_REMOTES="${CHISEL_REMOTES:-"R:10022:localhost:10022"}"
CHISEL_AUTH="${CHISEL_AUTH:-"user:password"}"

# Start the SSH daemon
/usr/sbin/sshd -p ${SSHD_PORT} -D -d -e &

# Start the chisel tunnel
/usr/bin/chisel client -v --auth "${CHISEL_AUTH}" "${CHISEL_REMOTE_URL}" ${CHISEL_REMOTES}