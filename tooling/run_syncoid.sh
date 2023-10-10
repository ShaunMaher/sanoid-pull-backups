#!/usr/bin/env bash

# Load boilerplate functions
function Source() { local ScriptName="$1" ; shift ; source "$ScriptName" ; }
Source "$(dirname "$(readlink -f "${0}")")/bash-boilerplate/source" || exit 1

SSH_REMOTE_HOST="${SSH_REMOTE_HOST:-"ph3.local"}"
SSH_USERNAME="${SSH_USERNAME:-"syncoid"}"
SSH_PORT="${SSH_PORT:-10022}"
SSH_PRIVKEY="${SSH_PRIVKEY}"
SSH_KNOWN_HOSTS="${SSH_KNOWN_HOSTS}"
SOURCE_DATASET="${SOURCE_DATASET}"
DESTINATION_DATASET="${DESTINATION_DATASET}"
MINIMUM_COUNT_OF_BACKUPS_TO_KEEP="${MINIMUM_COUNT_OF_BACKUPS_TO_KEEP:-14}"
MINIMUM_AGE_OF_BACKUP_TO_DELETE="${MINIMUM_AGE_OF_BACKUP_TO_DELETE:-1209600}" # 14 days
start_time=$(date +%s)

# Don't assume that these normal environment variables are set.
if [ "${USER}" == "" ]; then
  export USER=$(id -un)
fi
if [ "${HOME}" == "" ]; then
  export HOME=$(getent passwd "${USER}" | awk 'BEGIN{FS=":"}{print $6}')
fi

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

#printf '%b' $(printf '%b' "${SSH_PRIVKEY}") >${HOME}/.ssh/${SSH_USERNAME}@${SSH_REMOTE_HOST}
printf '%b' "${SSH_PRIVKEY}" >${HOME}/.ssh/${SSH_USERNAME}@${SSH_REMOTE_HOST}
chmod 600 "${HOME}/.ssh/${SSH_USERNAME}@${SSH_REMOTE_HOST}"
printf '%b' "${SSH_KNOWN_HOSTS}" >${HOME}/.ssh/known_hosts
chmod 600 ${HOME}/.ssh/known_hosts
cat ${HOME}/.ssh/known_hosts

syncoid_log="/tmp/${SSH_REMOTE_HOST}.log"
syncoid --debug --dumpsnaps --create-bookmark --no-sync-snap --no-privilege-elevation --sendoptions="w" "${SSH_USERNAME}@${SSH_REMOTE_HOST}:${SOURCE_DATASET}" "${DESTINATION_DATASET}" | tee "${syncoid_log}"

# Cleanup oldest snapshots on the destination
all_snapshots=$(zfs list -H -t snapshot -o name -d 1 "${DESTINATION_DATASET}")
all_snapshots_count=$(printf '%s' "${all_snapshots}" | wc -l)
if [ $all_snapshots_count -gt $MINIMUM_COUNT_OF_BACKUPS_TO_KEEP ]; then
  echo "More than ${MINIMUM_COUNT_OF_BACKUPS_TO_KEEP} snapshots exist on the destination dataset.  Looking for candidates to prune."
  while read object_name; do
    object_date=$(date +%s -d "$(printf '%s' "${object_name}" | sed 's/_[^0-9].*$//g' | awk 'BEGIN{FS="_"}{print $(NF-1)" "$NF}')")
    echo "Snapshot: ${object_name} - ${object_date}"
  done < <(printf '%s' "${all_snapshots}")

  #old_objects=$(printf '%s' "${all_remote_objects}" | jq "[ .[] | select((.UnixTime | tonumber) < $minimum_timestamp_of_backup) ]")
  #old_objects_count=$(printf '%s' "${old_objects}" | jq "length")
  #for (( i=0; i<$old_objects_count; i++ )) do
  #  object_name=$(printf '%s' "${old_objects}" | jq -r ".[$i].Name")
  #  object_path=$(printf '%s' "${old_objects}" | jq -r ".[$i].Path")
  #  object_date=$(printf '%s' "${old_objects}" | jq -r ".[$i].UnixTime")
  #  echo "Backup '${object_name}', created $(date -d "@${object_date}") is more than ${MINIMUM_AGE_OF_BACKUP_TO_DELETE} seconds old.  It can be pruned." | info
  #  echo "rclone rm \"wasabi:${S3_BUCKET}/${object_path}\"" | debug
  #done
fi

send_size=$(cat "${syncoid_log}" | grep '^DEBUG: sendsize = ' | awk 'BEGIN{FS=" = ";total=0}{total=total+$2}END{print total}')
result_json=$(echo "{}" | jq ".sendsize=${send_size}")
resumed=$(cat "${syncoid_log}" | grep -c "^Resuming interrupted zfs send/receive")
result_json=$(printf '%s' "${result_json}" | jq ".resumed=${resumed}")
duration=$(( $(date +%s) - $start_time ))
result_json=$(printf '%s' "${result_json}" | jq ".resumed=${duration}")
error_msg=$(cat "${syncoid_log}" | grep -B 1 "CRITICAL ERROR:")
result_json=$(printf '%s' "${result_json}" | jq ".resumed=${error_msg}")
error_count=$(cat "${syncoid_log}" | grep -c "CRITICAL ERROR:")
result_json=$(printf '%s' "${result_json}" | jq ".resumed=${error_count}")
error_out_of_space=$(cat "${syncoid_log}" | grep -c "out of space")
result_json=$(printf '%s' "${result_json}" | jq ".commonIssues={destinationOutOfSpace:${error_out_of_space}}")
error_connection_refused=$((cat "${syncoid_log}" | grep -c 'ssh: connect to host chisel port.*Connection refused')
result_json=$(printf '%s' "${result_json}" | jq ".commonIssues={connectionToSourceRefused:${error_connection_refused}}")

printf '%s' "${result_json}" | jq -C
printf '%s' "${result_json}" > backup_result.json