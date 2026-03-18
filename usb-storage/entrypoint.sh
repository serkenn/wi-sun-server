#!/usr/bin/env bash
set -euo pipefail

USB_LABEL="${USB_LABEL:-PI4DATA}"
USB_DEVICE="${USB_DEVICE:-}"
MOUNT_POINT="${USB_MOUNT_POINT:-/mnt/usb}"
CHECK_INTERVAL="${USB_CHECK_INTERVAL:-30}"

mkdir -p "${MOUNT_POINT}"

find_device() {
  if [ -n "${USB_DEVICE}" ] && [ -b "${USB_DEVICE}" ]; then
    echo "${USB_DEVICE}"
    return 0
  fi

  local by_label="/dev/disk/by-label/${USB_LABEL}"
  if [ -e "${by_label}" ]; then
    readlink -f "${by_label}"
    return 0
  fi

  if device="$(blkid -L "${USB_LABEL}" 2>/dev/null)"; then
    if [ -n "${device}" ] && [ -b "${device}" ]; then
      echo "${device}"
      return 0
    fi
  fi

  return 1
}

mount_device() {
  local device="$1"

  if mountpoint -q "${MOUNT_POINT}"; then
    return 0
  fi

  echo "Mounting ${device} on ${MOUNT_POINT}"
  mount "${device}" "${MOUNT_POINT}"
}

while true; do
  if device="$(find_device)"; then
    if mount_device "${device}"; then
      echo "USB storage ready: ${device} -> ${MOUNT_POINT}"
    fi
  else
    echo "USB storage with label ${USB_LABEL} not found"
  fi

  sleep "${CHECK_INTERVAL}"
done
