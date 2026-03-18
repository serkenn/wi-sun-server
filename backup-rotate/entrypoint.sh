#!/bin/bash
set -euo pipefail

USB_LABEL="${USB_LABEL:-PI4DATA}"
USB_DEVICE="${USB_DEVICE:-}"
MOUNT_POINT="${USB_MOUNT_POINT:-/mnt/usb}"
BACKUP_DIR="${BACKUP_DIR:-/mnt/usb/backups/mariadb}"
BACKUP_INTERVAL_SEC="${BACKUP_INTERVAL_SEC:-21600}"
BACKUP_RETENTION_COUNT="${BACKUP_RETENTION_COUNT:-14}"
BACKUP_MAX_USAGE_PERCENT="${BACKUP_MAX_USAGE_PERCENT:-85}"
DB_HOST="${DB_HOST:-mariadb}"
DB_NAME="${DB_NAME:-${MYSQL_DATABASE:-zabbix}}"
DB_USER="${DB_USER:-${MYSQL_USER:-zabbix}}"
DB_PASSWORD="${DB_PASSWORD:-${MYSQL_PASSWORD:-${MARIADB_PASSWORD:-}}}"

mkdir -p "${MOUNT_POINT}" "${BACKUP_DIR}"

find_device() {
  if [[ -n "${USB_DEVICE}" && -b "${USB_DEVICE}" ]]; then
    echo "${USB_DEVICE}"
    return 0
  fi

  local by_label="/dev/disk/by-label/${USB_LABEL}"
  if [[ -e "${by_label}" ]]; then
    readlink -f "${by_label}"
    return 0
  fi

  return 1
}

ensure_mount() {
  if mountpoint -q "${MOUNT_POINT}"; then
    return 0
  fi

  local device
  if ! device="$(find_device)"; then
    echo "USB storage with label ${USB_LABEL} not found. Waiting for device."
    return 1
  fi

  echo "Mounting ${device} on ${MOUNT_POINT}"
  if mount "${device}" "${MOUNT_POINT}"; then
    echo "USB storage ready: ${device} -> ${MOUNT_POINT}"
    return 0
  fi

  echo "Failed to mount ${device} on ${MOUNT_POINT}. Waiting before retry."
  return 1
}

wait_for_db() {
  until mariadb-admin ping -h "${DB_HOST}" -u "${DB_USER}" "-p${DB_PASSWORD}" --silent; do
    echo "Waiting for MariaDB at ${DB_HOST}"
    sleep 10
  done
}

create_backup() {
  local timestamp outfile
  timestamp="$(date +%Y%m%d-%H%M%S)"
  outfile="${BACKUP_DIR}/${DB_NAME}-${timestamp}.sql.gz"

  echo "Creating backup ${outfile}"
  mariadb-dump \
    --single-transaction \
    --quick \
    -h "${DB_HOST}" \
    -u "${DB_USER}" \
    "-p${DB_PASSWORD}" \
    "${DB_NAME}" | gzip -1 > "${outfile}"
}

prune_by_count() {
  local count
  count="$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name '*.sql.gz' | wc -l | tr -d ' ')"

  if (( count <= BACKUP_RETENTION_COUNT )); then
    return 0
  fi

  find "${BACKUP_DIR}" -maxdepth 1 -type f -name '*.sql.gz' -print0 \
    | xargs -0 ls -1t \
    | tail -n +"$((BACKUP_RETENTION_COUNT + 1))" \
    | while read -r oldfile; do
        [[ -n "${oldfile}" ]] || continue
        echo "Removing old backup by count: ${oldfile}"
        rm -f "${oldfile}"
      done
}

prune_by_usage() {
  local usage
  usage="$(df -P "${MOUNT_POINT}" | awk 'NR==2 {gsub("%","",$5); print $5}')"

  while (( usage >= BACKUP_MAX_USAGE_PERCENT )); do
    local oldest
    oldest="$(find "${BACKUP_DIR}" -maxdepth 1 -type f -name '*.sql.gz' | sort | head -n 1)"
    if [[ -z "${oldest}" ]]; then
      echo "Usage threshold exceeded but no backup files remain to delete"
      break
    fi

    echo "Removing old backup by usage (${usage}%): ${oldest}"
    rm -f "${oldest}"
    usage="$(df -P "${MOUNT_POINT}" | awk 'NR==2 {gsub("%","",$5); print $5}')"
  done
}

if [[ -z "${DB_PASSWORD}" ]]; then
  echo "DB_PASSWORD or MYSQL_PASSWORD is required" >&2
  exit 1
fi

while true; do
  if ! ensure_mount; then
    sleep 30
    continue
  fi
  mkdir -p "${BACKUP_DIR}"
  wait_for_db
  create_backup
  prune_by_count
  prune_by_usage
  sleep "${BACKUP_INTERVAL_SEC}"
done
