# Codespaces and Docker host

This repository can run in GitHub Codespaces with an isolated Docker Engine.
Create a codespace for the repository and wait for the devcontainer rebuild to
finish. The default Docker context is the Docker-in-Docker engine inside that
codespace; verify it with:

```bash
docker info
docker compose version
```

Project dependencies are deliberately not installed from unreviewed manifests
by default. To install the detected Node, Python, and Go dependencies during a
rebuild, add the Codespaces secret `DEVCONTAINER_INSTALL_PROJECT_DEPS=1`.

## Optional external Docker host

Use an external daemon only when it is owned or explicitly authorized. Configure
these repository- or account-level Codespaces secrets:

- `DOCKER_REMOTE_HOST`: a TLS endpoint such as `tcp://docker.example:2376`
- `DOCKER_REMOTE_CA_B64`: base64-encoded CA certificate
- `DOCKER_REMOTE_CERT_B64`: base64-encoded client certificate
- `DOCKER_REMOTE_KEY_B64`: base64-encoded client key

On startup, `.devcontainer/docker-host.sh --auto` writes the certificates outside
the Git checkout with restrictive permissions, creates the `codespace-external`
Docker context, makes it active, and verifies the server. Plaintext remote Docker
sockets are rejected. Do not commit certificates, API keys, `.env` files, case
data, or Docker registry credentials.

To return to the Codespace-local Docker engine:

```bash
unset DOCKER_REMOTE_HOST DOCKER_REMOTE_CA_B64 DOCKER_REMOTE_CERT_B64 DOCKER_REMOTE_KEY_B64
docker context use default
docker info
```

GitHub Codespaces is a development host, not a durable production service. Keep
state in managed storage, back up named volumes deliberately, and use an actual
deployment platform for always-on workloads.
