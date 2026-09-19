#!/usr/bin/env bash
set -euo pipefail

context_name="codespace-external"
state_dir="/workspaces/.docker-host"
cert_dir="${state_dir}/certs"

use_local_dind() {
  docker context use default >/dev/null
  docker info --format 'Docker host: {{.Name}} / server {{.ServerVersion}}'
}

if [[ -z "${DOCKER_REMOTE_HOST:-}" ]]; then
  use_local_dind
  exit 0
fi

if [[ "${DOCKER_REMOTE_HOST}" != tcp://* ]]; then
  echo "DOCKER_REMOTE_HOST must use tcp:// with mutual TLS." >&2
  exit 2
fi

for name in DOCKER_REMOTE_CA_B64 DOCKER_REMOTE_CERT_B64 DOCKER_REMOTE_KEY_B64; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required Codespaces secret: ${name}" >&2
    exit 2
  fi
done

install -d -m 0700 "${cert_dir}"
printf '%s' "${DOCKER_REMOTE_CA_B64}" | base64 --decode > "${cert_dir}/ca.pem"
printf '%s' "${DOCKER_REMOTE_CERT_B64}" | base64 --decode > "${cert_dir}/cert.pem"
printf '%s' "${DOCKER_REMOTE_KEY_B64}" | base64 --decode > "${cert_dir}/key.pem"
chmod 0600 "${cert_dir}"/*.pem

docker_context=(
  "host=${DOCKER_REMOTE_HOST}"
  "ca=${cert_dir}/ca.pem"
  "cert=${cert_dir}/cert.pem"
  "key=${cert_dir}/key.pem"
  "skip-tls-verify=false"
)
docker_endpoint="$(IFS=,; echo "${docker_context[*]}")"

if docker context inspect "${context_name}" >/dev/null 2>&1; then
  docker context update "${context_name}" --docker "${docker_endpoint}" >/dev/null
else
  docker context create "${context_name}" --docker "${docker_endpoint}" >/dev/null
fi

docker context use "${context_name}" >/dev/null
docker --context "${context_name}" info --format 'Docker host: {{.Name}} / server {{.ServerVersion}}'
