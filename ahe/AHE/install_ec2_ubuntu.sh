#!/usr/bin/env bash
set -Eeuo pipefail

# Run this from the copied project directory as the normal EC2 login user.
APP_DIR="${APP_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
ENV_FILE="$APP_DIR/.env"
SERVICE_NAME="ahe-global"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
APP_USER="${SUDO_USER:-$(id -un)}"
APP_GROUP="$(id -gn "$APP_USER")"

if [[ ! -f "$APP_DIR/app.py" || ! -f "$APP_DIR/requirements.txt" ]]; then
  echo "Run this script from the AHE Global project folder (app.py and requirements.txt must be present)." >&2
  exit 1
fi
if [[ "$APP_DIR" == *" "* ]]; then
  echo "Please place the project in a path without spaces, such as ~/ahe-global." >&2
  exit 1
fi

if [[ "$(. /etc/os-release && echo "${ID:-}")" != "ubuntu" ]]; then
  echo "This installer supports Ubuntu EC2 images." >&2
  exit 1
fi

if [[ "$EUID" -eq 0 ]]; then
  SUDO=()
else
  command -v sudo >/dev/null || { echo "Please install sudo or run as root." >&2; exit 1; }
  SUDO=(sudo)
fi

env_value() {
  local key="$1"
  if [[ -f "$ENV_FILE" ]]; then
    sed -n "s/^${key}=//p" "$ENV_FILE" | head -n 1
  fi
}

echo "Installing system packages..."
"${SUDO[@]}" apt-get update
DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y python3 python3-venv python3-pip mysql-server openssl
"${SUDO[@]}" systemctl enable --now mysql

SECRET_KEY="$(env_value SECRET_KEY)"
if [[ -z "$SECRET_KEY" || "$SECRET_KEY" == "replace-with-a-long-random-value" ]]; then
  SECRET_KEY="$(openssl rand -hex 32)"
fi

DB_USER="ahe_app"
DB_PASSWORD="$(env_value DB_PASSWORD)"
if [[ -z "$DB_PASSWORD" || "$DB_PASSWORD" == "replace-with-a-strong-password" || ! "$DB_PASSWORD" =~ ^[A-Za-z0-9_-]+$ ]]; then
  DB_PASSWORD="$(openssl rand -hex 24)"
fi

echo "Preparing the AHE Global MySQL database..."
"${SUDO[@]}" mysql <<SQL
CREATE DATABASE IF NOT EXISTS ahe_global CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ahe_global.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

if [[ ! -f "$ENV_FILE" ]]; then
  cat > "$ENV_FILE" <<ENV
SECRET_KEY=${SECRET_KEY}
FLASK_DEBUG=false
HOST=127.0.0.1
PORT=8000
DB_HOST=localhost
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=ahe_global
ENV
else
  # Rewrite only the settings this demo uses; never display the generated secrets.
  cat > "$ENV_FILE" <<ENV
SECRET_KEY=${SECRET_KEY}
FLASK_DEBUG=false
HOST=127.0.0.1
PORT=8000
DB_HOST=localhost
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=ahe_global
ENV
fi
chmod 600 "$ENV_FILE"

echo "Installing Python packages..."
python3 -m venv "$APP_DIR/.venv"
"$APP_DIR/.venv/bin/pip" install --upgrade pip
"$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"

echo "Creating the persistent web service..."
"${SUDO[@]}" tee "$SERVICE_FILE" >/dev/null <<UNIT
[Unit]
Description=AHE Global demo website
After=network.target mysql.service
Requires=mysql.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${APP_DIR}
EnvironmentFile=${ENV_FILE}
ExecStart=${APP_DIR}/.venv/bin/gunicorn --workers 2 --bind 0.0.0.0:8000 app:app
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

if command -v ufw >/dev/null 2>&1 && "${SUDO[@]}" ufw status | grep -q 'Status: active'; then
  "${SUDO[@]}" ufw allow 8000/tcp
fi

"${SUDO[@]}" systemctl daemon-reload
"${SUDO[@]}" systemctl enable --now "$SERVICE_NAME"
"${SUDO[@]}" systemctl restart "$SERVICE_NAME"

echo
echo "AHE Global is running as a systemd service on port 8000."
echo "In the EC2 security group, allow inbound TCP 8000 from your reviewer's IP."
echo "Then open: http://EC2_PUBLIC_IP:8000"
echo "Service status: sudo systemctl status ${SERVICE_NAME}"
echo "Live logs:      sudo journalctl -u ${SERVICE_NAME} -f"
