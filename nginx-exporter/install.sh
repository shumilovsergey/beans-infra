#!/bin/bash
set -e

# Configuration
BIN_NAME="nginx-prometheus-exporter"
BIN_PATH="/etc/${BIN_NAME}"
BIN_FULL_PATH="${BIN_PATH}/${BIN_NAME}"
SERVICE_PORT=9113
STUB_STATUS_PORT=9114
STUB_STATUS_PATH="/etc/nginx/conf.d/stub_status.conf"
SERVICE_NAME="${BIN_NAME}-${SERVICE_PORT}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
USER="${BIN_NAME}"
GROUP="${BIN_NAME}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Installing ${BIN_NAME}..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Check that binary exists
if [ ! -f "./${BIN_NAME}" ]; then
    echo "Error: ${BIN_NAME} binary not found in current directory"
    exit 1
fi
echo "✓ Binary found"

# Check and create group
if ! getent group "${GROUP}" > /dev/null 2>&1; then
    groupadd --system "${GROUP}"
    echo "✓ Group ${GROUP} created"
else
    echo "✓ Group ${GROUP} already exists"
fi

# Check and create user
if ! id -u "${USER}" > /dev/null 2>&1; then
    useradd --system --no-create-home --shell /bin/false -g "${GROUP}" "${USER}"
    echo "✓ User ${USER} created"
else
    echo "✓ User ${USER} already exists"
fi

# Create directory and copy binary
mkdir -p "${BIN_PATH}"
cp "./${BIN_NAME}" "${BIN_FULL_PATH}"
chmod +x "${BIN_FULL_PATH}"
chown "${USER}:${GROUP}" "${BIN_FULL_PATH}"
echo "✓ Binary copied to ${BIN_FULL_PATH}"

# Create nginx stub_status configuration
cat > "${STUB_STATUS_PATH}" <<EOF
server {
    listen 127.0.0.1:${STUB_STATUS_PORT};
    server_name localhost;

    location /stub_status {
        stub_status;
        allow 127.0.0.1;
        deny all;
    }
}
EOF

echo "✓ NGINX stub_status config created at ${STUB_STATUS_PATH}"

# Test and reload nginx
if nginx -t > /dev/null 2>&1; then
    systemctl reload nginx
    echo "✓ NGINX configuration tested and reloaded"
else
    echo "Warning: NGINX configuration test failed. Please check manually:"
    nginx -t
fi

# Create systemd service
cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=NGINX Prometheus Exporter
After=network.target

[Service]
Type=simple
User=${USER}
Group=${GROUP}
ExecStart=${BIN_FULL_PATH} -web.listen-address=0.0.0.0:${SERVICE_PORT} -nginx.scrape-uri=http://127.0.0.1:${STUB_STATUS_PORT}/stub_status
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Service file created at ${SERVICE_FILE}"

# Reload systemd, enable and start service
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl start "${SERVICE_NAME}"
echo "✓ Service enabled and started"

# Check service status
sleep 2
if systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo -e "${GREEN}✓ Service is running${NC}"
else
    echo "Warning: Service may not be running properly"
    systemctl status "${SERVICE_NAME}" --no-pager
    exit 1
fi

# Success message
echo -e "\n${GREEN}Installation complete!${NC}"
echo -e "\nMetrics are available at: http://0.0.0.0:${SERVICE_PORT}/metrics (accessible from any interface)"

# Post-installation instructions
echo -e "\n${YELLOW}Next steps:${NC}"
echo
echo "Useful commands:"
echo "  Check status:  sudo systemctl status ${SERVICE_NAME}"
echo "  View logs:     sudo journalctl -u ${SERVICE_NAME} -f"
echo "  Restart:       sudo systemctl restart ${SERVICE_NAME}"
echo
echo "UFW"
echo "sudo ufw allow from [prometheus ip] to any port ${SERVICE_PORT} proto tcp"
