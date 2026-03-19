#!/bin/sh
set -eu

PLUGIN_DIR="/var/lib/grafana/plugins/alexanderzobnin-zabbix-app"
EXPECTED_VERSION="${GRAFANA_ZABBIX_PLUGIN_VERSION:-5.2.1}"

current_version() {
  if [ ! -f "${PLUGIN_DIR}/plugin.json" ]; then
    return 1
  fi

  sed -n 's/.*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "${PLUGIN_DIR}/plugin.json" | head -n1
}

installed_version="$(current_version || true)"
if [ -n "${installed_version}" ] && [ "${installed_version}" != "${EXPECTED_VERSION}" ]; then
  echo "Removing incompatible Zabbix plugin version ${installed_version}; expected ${EXPECTED_VERSION}"
  rm -rf "${PLUGIN_DIR}"
fi

if [ ! -f "${PLUGIN_DIR}/plugin.json" ]; then
  echo "Installing Zabbix plugin ${EXPECTED_VERSION}"
  grafana cli --pluginsDir /var/lib/grafana/plugins plugins install alexanderzobnin-zabbix-app "${EXPECTED_VERSION}"
fi

exec /run.sh
