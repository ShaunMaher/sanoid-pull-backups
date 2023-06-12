#!/usr/bin/bash

SSH_REMOTE_HOST="ph3.local"
SSH_USERNAME="${SSH_USERNAME:-"syncoid"}"
SSH_PORT="${SSH_PORT:-10022}"
SSH_PRIVKEY="${SSH_PRIVKEY}"

# Don't assume that these normal environment variables are set.
if [ "${USER}" == "" ]; then
  export USER=$(id -un)
fi
if [ "${HOME}" == "" ]; then
  export HOME=$(getent passwd "${USER}" | awk 'BEGIN{FS=":"}{print $6}')
fi

#TODO: Start gitlab runner

#TODO: Then what?
while [ true ]; do

# Create and populate a ~/.ssh/config file
# TODO: This need to be expandable to multiple remote targets
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  cat >${HOME}/.ssh/config <<-EOF
Host ${SSH_REMOTE_HOST}
  HostName      chisel
  User          ${SSH_USERNAME}
  Port          ${SSH_PORT}
  IdentityFile  ${HOME}/.ssh/${SSH_USERNAME}@${SSH_REMOTE_HOST}
EOF

  echo "${SSH_PRIVKEY}" >${HOME}/.ssh/${SSH_USERNAME}@${SSH_REMOTE_HOST}

  # TODO: The following should move to a gitlab runner job I think
  syncoid

  sleep 3600
done