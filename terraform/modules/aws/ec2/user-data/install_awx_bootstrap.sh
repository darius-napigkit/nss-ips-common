#!/usr/bin/env bash
# EC2 user_data bootstrap for installing Docker CE, Ansible, Git, docker-compose,
# and deploying AWX via the docker-compose installer method.
# Tested on Amazon Linux 2/2023, RHEL/CentOS 8/9, and Ubuntu 20.04/22.04.
set -euo pipefail

LOG_FILE="/var/log/awx-bootstrap.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] Starting AWX bootstrap at $(date -Is)"

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] This script must run as root."
    exit 1
  fi
}

detect_os() {
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_VER="${VERSION_ID:-unknown}"
  OS_ID_LIKE="${ID_LIKE:-}"
  echo "[INFO] Detected OS: ID=${OS_ID} VER=${OS_VER} LIKE=${OS_ID_LIKE}"
}

# Return the most likely default login user (UID 1000) or fallback to ec2-user
detect_default_user() {
  local uid1000
  uid1000="$(awk -F: '$3==1000 {print $1}' /etc/passwd || true)"
  if [[ -n "${uid1000:-}" ]]; then
    DEFAULT_USER="$uid1000"
  else
    # common EC2 defaults
    for u in ec2-user ubuntu rocky almalinux centos rhel; do
      if id "$u" &>/dev/null; then DEFAULT_USER="$u"; break; fi
    done
  fi
  DEFAULT_USER="${DEFAULT_USER:-ec2-user}"
  echo "[INFO] Default user resolved to: ${DEFAULT_USER}"
}

enable_start_docker() {
  systemctl enable docker
  systemctl start docker
  # Give Docker a couple of seconds to settle
  sleep 2
  docker --version || true
}

install_common_tools() {
  case "$OS_ID" in
    amzn)
      if [[ "${OS_VER%%.*}" == "2" ]]; then
        yum -y update
        amazon-linux-extras enable docker
        yum -y install docker git python3-pip tar curl openssl
        pip3 install --upgrade pip
        # Ansible + docker-compose via pip on AL2
        pip3 install "ansible>=2.12" docker-compose
      else
        # Amazon Linux 2023
        dnf -y update
        dnf -y install docker git python3-pip tar curl openssl
        pip3 install --upgrade pip
        pip3 install "ansible>=2.12" docker-compose
      fi
      ;;
    rhel|centos|rocky|almalinux|ol)
      dnf -y install epel-release || yum -y install epel-release || true
      dnf -y install dnf-plugins-core || true
      # Use the CentOS-compatible Docker CE repo for RHEL-like systems
      if ! dnf repolist | grep -qi docker-ce; then
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      fi
      # Try to install docker-compose plugin if available; fallback to pip
      dnf -y install docker-ce docker-ce-cli containerd.io git tar curl openssl || {
        # Older platforms might need yum fallback
        yum -y install docker-ce docker-ce-cli containerd.io git tar curl openssl
      }
      # Ansible can come from EPEL/AppStream; fallback to pip if not present
      if ! dnf -y install ansible-core ansible; then
        dnf -y install python3-pip
        pip3 install --upgrade pip
        pip3 install "ansible>=2.12"
      fi
      dnf -y install docker-compose-plugin || true
      # Fallback docker-compose v1 from pip if plugin not present
      if ! command -v docker-compose &>/dev/null; then
        if ! dnf -y install python3-pip; then yum -y install python3-pip; fi
        pip3 install --upgrade pip
        pip3 install docker-compose
      fi
      ;;
    ubuntu|debian)
      apt-get update -y
      apt-get install -y ca-certificates curl gnupg lsb-release git python3-pip tar openssl
      # Docker CE repo
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/${OS_ID}/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS_ID} \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
      apt-get update -y
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      # Ansible
      apt-get install -y ansible || {
        pip3 install --upgrade pip
        pip3 install "ansible>=2.12"
      }
      ;;
    *)
      echo "[ERROR] Unsupported or unrecognized Linux distribution: ${OS_ID} ${OS_VER}"
      exit 2
      ;;
  esac

  # Ensure docker-compose CLI name is available even if only plugin exists
  if ! command -v docker-compose &>/dev/null && command -v docker &>/dev/null; then
    if docker compose version &>/dev/null; then
      echo "[INFO] Creating docker-compose compatibility wrapper"
      cat >/usr/local/bin/docker-compose <<'EOF'
#!/usr/bin/env bash
exec docker compose "$@"
EOF
      chmod +x /usr/local/bin/docker-compose
    fi
  fi

  # Final sanity checks
  docker --version
  if command -v docker-compose &>/dev/null; then
    docker-compose --version || true
  else
    echo "[WARN] docker-compose not found; relying on 'docker compose' subcommand."
  fi
  ansible --version | head -n 1
  git --version
}

add_user_to_docker_group() {
  if id "$DEFAULT_USER" &>/dev/null; then
    usermod -aG docker "$DEFAULT_USER" || true
    echo "[INFO] Added ${DEFAULT_USER} to docker group (new login required to take effect)."
  fi
}

generate_secure_value() {
  # Generates a URL-safe random string of given length
  local length="${1:-32}"
  # Prefer openssl; fallback to /dev/urandom
  if command -v openssl &>/dev/null; then
    # Filter to alnum to avoid YAML/compose quoting pitfalls
    openssl rand -base64 $((length*2)) | tr -dc 'A-Za-z0-9' | head -c "${length}"
  else
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${length}"
  fi
}

install_awx() {
  local AWX_VERSION="${AWX_VERSION:-17.1.0}"      # docker-compose era
  local AWX_SRC_DIR="/opt/awx"
  local AWX_INSTALLER_DIR="${AWX_SRC_DIR}/installer"

  if docker ps --format '{{.Names}}' | grep -q '^awx_web$'; then
    echo "[INFO] AWX appears to be running (awx_web container found). Skipping AWX install."
    return 0
  fi

  # Clone AWX source at the specified version tag/branch
  if [[ ! -d "${AWX_SRC_DIR}/.git" ]]; then
    echo "[INFO] Cloning AWX source (${AWX_VERSION}) into ${AWX_SRC_DIR}"
    git clone -b "${AWX_VERSION}" --depth 1 https://github.com/ansible/awx.git "${AWX_SRC_DIR}"
  else
    echo "[INFO] AWX source already present at ${AWX_SRC_DIR}; ensuring correct version/tag"
    (cd "${AWX_SRC_DIR}" && git fetch --tags --depth 1 && git checkout "${AWX_VERSION}")
  fi

  # Ensure installer directory exists
  if [[ ! -d "${AWX_INSTALLER_DIR}" ]]; then
    echo "[ERROR] AWX installer directory not found at ${AWX_INSTALLER_DIR}"
    exit 3
  fi

  # Prepare secure credentials (generated at runtime)
  local ADMIN_USER="${ADMIN_USER:-admin}"
  local ADMIN_PASSWORD="${ADMIN_PASSWORD:-$(generate_secure_value 24)}"
  local PG_PASSWORD="${PG_PASSWORD:-$(generate_secure_value 32)}"
  local SECRET_KEY="${SECRET_KEY:-$(generate_secure_value 64)}"

  # Persist credentials for operator reference (permissions restricted)
  local CREDS_FILE="/root/awx-credentials.txt"
  umask 077
  cat >"${CREDS_FILE}" <<EOF
AWX admin_user: ${ADMIN_USER}
AWX admin_password: ${ADMIN_PASSWORD}
PostgreSQL password: ${PG_PASSWORD}
Django secret_key: ${SECRET_KEY}
Generated at: $(date -Is)
EOF
  echo "[INFO] Generated AWX credentials stored at ${CREDS_FILE} (root-readable only)."

  # Write extra vars for the installer
  local VARS_YML="${AWX_INSTALLER_DIR}/vars.yml"
  cat >"${VARS_YML}" <<EOF
admin_user: "${ADMIN_USER}"
admin_password: "${ADMIN_PASSWORD}"
pg_password: "${PG_PASSWORD}"
secret_key: "${SECRET_KEY}"
# Optional overrides:
# awx_image: "ansible/awx"
# awx_version: "${AWX_VERSION}"
# project_data_dir: "/var/lib/awx/projects"
# docker_compose_dir: "/var/lib/awx"
EOF

  # Ensure Ansible can find and run docker-compose
  if ! command -v docker-compose &>/dev/null; then
    if ! docker compose version &>/dev/null; then
      echo "[ERROR] Neither 'docker-compose' nor 'docker compose' is available."
      exit 4
    fi
  fi

  # Some AWX installer versions reference community.docker; attempt to satisfy if defined
  if [[ -f "${AWX_INSTALLER_DIR}/requirements.yml" ]]; then
    echo "[INFO] Installing Ansible Galaxy requirements for the AWX installer (if any)."
    ansible-galaxy collection install -r "${AWX_INSTALLER_DIR}/requirements.yml" || true
  fi

  # Run the AWX installer playbook
  echo "[INFO] Running AWX installer via Ansible..."
  ANSIBLE_FORCE_COLOR=1 \
  ansible-playbook -i "${AWX_INSTALLER_DIR}/inventory" \
                   "${AWX_INSTALLER_DIR}/install.yml" \
                   -e @"${VARS_YML}"

  echo "[INFO] AWX installation playbook completed."

  # Basic health hint
  echo "[INFO] If your Security Group allows it, AWX should be reachable on http://<instance-public-ip>/"
  echo "[INFO] Login with user '${ADMIN_USER}'. The password is stored in ${CREDS_FILE}."
}

main() {
  require_root
  detect_os
  detect_default_user
  install_common_tools
  enable_start_docker
  add_user_to_docker_group
  install_awx
  echo "[INFO] AWX bootstrap completed at $(date -Is)"
}

main "$@"
