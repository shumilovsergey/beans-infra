#!/usr/bin/env bash
set -euo pipefail

### ---- CONFIG ----
PORT="${PORT:-8080}"
UPSTREAM_BASE_URL="https://api.telegram.org"
SERVICE_NAME="proxy"
BIN_NAME="proxy"
INSTALL_DIR="/opt/proxy"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}${PORT}.service"
USER="proxy"
### ----------------

echo "[*] Using port: $PORT"

echo "[*] Checking binary..."
if [ ! -f "./${BIN_NAME}" ]; then
    echo "ERROR: ./tg-proxy not found. Put binary next to this script."
    exit 1
fi

echo "[*] Creating user '${USER}' (if not exists)..."
if ! id "${USER}" &>/dev/null; then
    useradd --system --no-create-home --shell /usr/sbin/nologin "${USER}"
fi

echo "[*] Creating directory ${INSTALL_DIR}..."
mkdir -p "${INSTALL_DIR}"

echo "[*] Copying binary..."
cp "./${BIN_NAME}" "${INSTALL_DIR}/${BIN_NAME}"
chmod 755 "${INSTALL_DIR}/${BIN_NAME}"
chown -R "${USER}:${USER}" "${INSTALL_DIR}"

echo "[*] Creating systemd service..."
cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Minimal Telegram API proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${USER}
Group=${USER}
Environment=PORT=${PORT}
Environment=UPSTREAM_BASE_URL=${UPSTREAM_BASE_URL}
ExecStart=${INSTALL_DIR}/${BIN_NAME}
WorkingDirectory=${INSTALL_DIR}
Restart=on-failure
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

echo "[*] Reloading systemd..."
systemctl daemon-reload

echo "[*] Enabling service..."
systemctl enable "${SERVICE_NAME}"

echo "[*] Starting service..."
systemctl restart "${SERVICE_NAME}"

echo "✅ Installation complete!"
echo "Service status:"
systemctl status "${SERVICE_NAME}" --no-pager
echo
echo "📌 Logs: journalctl -u ${SERVICE_NAME} -f"
echo "📌 Service running on port ${PORT}"
