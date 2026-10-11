#!/usr/bin/env bash
set -euo pipefail
umask 077

context_name="codespace-external"
state_dir="${DOCKER_HOST_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/osint-docker-host}"
cert_dir="${state_dir}/certs"

use_local_dind() {
  docker context use default >/dev/null
  docker info --format 'Docker host: {{.Name}} / server {{.ServerVersion}}'
}

if [[ -z "${DOCKER_REMOTE_HOST:-}" ]]; then
  use_local_dind
  exit 0
fi

if [[ ! "${DOCKER_REMOTE_HOST}" =~ ^tcp://([A-Za-z0-9][A-Za-z0-9.-]*|\[[0-9A-Fa-f:]+\]):([0-9]{1,5})$ ]]; then
  echo "DOCKER_REMOTE_HOST must be a credential-free tcp://host:port endpoint with mutual TLS." >&2
  exit 2
fi
port="${BASH_REMATCH[2]}"
if (( 10#$port < 1 || 10#$port > 65535 )); then
  echo "DOCKER_REMOTE_HOST port must be between 1 and 65535." >&2
  exit 2
fi

for name in DOCKER_REMOTE_CA_B64 DOCKER_REMOTE_CERT_B64 DOCKER_REMOTE_KEY_B64; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required Codespaces secret: ${name}" >&2
    exit 2
  fi
done

if [[ -L "${state_dir}" || -L "${cert_dir}" ]]; then
  echo "Docker state/certificate directory must not be a symlink." >&2
  exit 2
fi
install -d -m 0700 "${cert_dir}"
for filename in ca.pem cert.pem key.pem; do
  if [[ -L "${cert_dir}/${filename}" ]]; then
    echo "Docker certificate files must not be symlinks." >&2
    exit 2
  fi
done
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
