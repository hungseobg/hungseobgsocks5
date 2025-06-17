#!/usr/bin/env bash
# Auto-install SOCKS5 proxy (Dante) on Ubuntu 25.04 with fixed port 1080
# 100% automatic: install, configure, firewall, service start, then display connection URL with branding

set -e

# 1. Ensure script is run as root
if [[ "$EUID" -ne 0 ]]; then
  echo "Vui lòng chạy script với quyền root (sudo)."
  exit 1
fi

# 2. Fetch public IP
PUBLIC_IP=$(curl -4s https://api.ipify.org)
if [[ -z "$PUBLIC_IP" ]]; then
  echo "Không lấy được IP công khai. Vui lòng kiểm tra kết nối." >&2
  exit 1
fi

# 3. Generate random credentials and set fixed port 1080
USERNAME="socks_$(tr -dc 'a-z0-9' </dev/urandom | head -c6)"
PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c12)"
PORT=1080

# 4. Install required packages
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y dante-server ufw curl

# 5. Configure UFW firewall
ufw allow ssh
ufw allow ${PORT}/tcp
ufw --force enable

# 6. Create system user for Dante
useradd -M -N -s /usr/sbin/nologin "$USERNAME" || true
echo "${USERNAME}:${PASSWORD}" | chpasswd

# 7. Backup old config and write /etc/danted.conf
if [[ -f /etc/danted.conf ]]; then
  cp /etc/danted.conf /etc/danted.conf.bak.$(date +%Y%m%d%H%M%S)
fi

cat > /etc/danted.conf <<EOF
# Dante SOCKS5 server configuration

# Logging to syslog
logoutput: syslog;

# Network interfaces
internal: 0.0.0.0 port = ${PORT};
external: $(ip route | awk '/default/ {print $5; exit}');

# Authentication method (username = system user)
socksmethod: username;

# Privileged and unprivileged users
user.privileged: root;
user.notprivileged: nobody;

# Allow all clients to connect
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0;
    log: error;
}

# Allow SOCKS commands
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0;
    command: bind connect udpassociate;
    log: error;
}
EOF

# 8. Restart and enable Dante service
systemctl restart danted
systemctl enable danted

# 9. Display connection information
echo "========================================"
echo "SOCKS5 proxy đã sẵn sàng!"
echo "URL kết nối:"
echo "  socks5://${USERNAME}:${PASSWORD}@${PUBLIC_IP}:${PORT}"
echo "Hùng Sẹo BG"
echo "========================================"
