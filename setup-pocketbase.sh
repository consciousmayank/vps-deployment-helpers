#!/bin/bash

# PocketBase VPS Deployment Script
# Usage: ./setup-pocketbase.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }
echo_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Function to validate domain format
validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to validate port number
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1024 ] && [ $port -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Function to check if port is available
check_port_available() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        return 1
    else
        return 0
    fi
}

# Function to get latest PocketBase version
get_latest_pocketbase_version() {
    local version=$(curl -s https://api.github.com/repos/pocketbase/pocketbase/releases/latest | grep -Po '"tag_name": "v\K[^"]*' 2>/dev/null || echo "0.22.0")
    echo $version
}

echo_step "🚀 PocketBase VPS Deployment Script"
echo "This script will deploy PocketBase on your VPS with SSL and domain configuration."
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo_error "This script should not be run as root."
   exit 1
fi

# Interactive Configuration
echo_step "🔧 Configuration Setup"

# Get domain
while true; do
    read -p "Enter your domain name (e.g., example.com): " DOMAIN
    if validate_domain "$DOMAIN"; then
        break
    else
        echo_error "Invalid domain format. Please enter a valid domain (e.g., example.com)"
    fi
done

# Get subdomain for PocketBase
while true; do
    read -p "Enter subdomain for PocketBase (e.g., 'api' for api.$DOMAIN): " SUBDOMAIN
    if [[ $SUBDOMAIN =~ ^[a-zA-Z0-9_-]+$ ]]; then
        break
    else
        echo_error "Subdomain should contain only letters, numbers, underscores, and hyphens"
    fi
done

# Get port
while true; do
    default_port=8090
    read -p "Port for PocketBase (default: $default_port): " PORT
    PORT=${PORT:-$default_port}
    
    if validate_port "$PORT"; then
        if check_port_available "$PORT"; then
            break
        else
            echo_warn "Port $PORT appears to be in use. Continue anyway? (y/n)"
            read -p "" continue_anyway
            if [[ $continue_anyway =~ ^[Yy]$ ]]; then
                break
            fi
        fi
    else
        echo_error "Port must be a number between 1024 and 65535"
    fi
done

# Get admin email
while true; do
    read -p "Admin email for initial setup (optional, press Enter to skip): " ADMIN_EMAIL
    if [[ -z "$ADMIN_EMAIL" ]] || [[ $ADMIN_EMAIL =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        break
    else
        echo_error "Please enter a valid email address or press Enter to skip"
    fi
done

# Confirmation
echo ""
echo_step "🔍 Configuration Summary"
echo "Domain: $DOMAIN"
echo "PocketBase URL: https://$SUBDOMAIN.$DOMAIN"
echo "Port: $PORT"
echo "Admin Email: ${ADMIN_EMAIL:-"Not specified (will be set during first run)"}"
echo ""
read -p "Does this look correct? (y/n): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo_error "Setup cancelled by user"
    exit 1
fi

# Step 1: Install Prerequisites
echo_step "📦 Installing Prerequisites"

# Update system
echo_info "Updating system packages..."
sudo apt update

# Install required packages
sudo apt install -y curl wget unzip nginx certbot python3-certbot-nginx

# Step 2: Download and Install PocketBase
echo_step "⬇️ Downloading PocketBase"

POCKETBASE_VERSION=$(get_latest_pocketbase_version)
echo_info "Latest PocketBase version: $POCKETBASE_VERSION"

# Create PocketBase directory
sudo mkdir -p /var/www/pocketbase
cd /tmp

# Download PocketBase
ARCH=$(uname -m)
if [[ $ARCH == "x86_64" ]]; then
    POCKETBASE_ARCH="amd64"
elif [[ $ARCH == "aarch64" ]] || [[ $ARCH == "arm64" ]]; then
    POCKETBASE_ARCH="arm64"
else
    echo_error "Unsupported architecture: $ARCH"
    exit 1
fi

DOWNLOAD_URL="https://github.com/pocketbase/pocketbase/releases/download/v${POCKETBASE_VERSION}/pocketbase_${POCKETBASE_VERSION}_linux_${POCKETBASE_ARCH}.zip"

echo_info "Downloading PocketBase from: $DOWNLOAD_URL"
if ! wget -q "$DOWNLOAD_URL" -O pocketbase.zip; then
    echo_error "Failed to download PocketBase"
    exit 1
fi

# Extract and install
unzip -q pocketbase.zip
sudo mv pocketbase /var/www/pocketbase/
sudo chmod +x /var/www/pocketbase/pocketbase
rm pocketbase.zip

echo_info "PocketBase installed successfully"

# Step 3: Create PocketBase directories and set permissions
echo_step "📁 Setting up directories"

sudo mkdir -p /var/www/pocketbase/{data,logs,backups}
sudo chown -R $USER:$USER /var/www/pocketbase

# Step 4: Create PocketBase configuration
echo_step "⚙️ Creating PocketBase configuration"

# Create environment file
cat > /var/www/pocketbase/.env << EOF
# PocketBase Configuration
PB_DATA_DIR=/var/www/pocketbase/data
PB_HOOKS_DIR=/var/www/pocketbase/hooks
PB_PUBLIC_DIR=/var/www/pocketbase/public
PB_MIGRATIONS_DIR=/var/www/pocketbase/migrations
EOF

# Create a simple hook example (optional)
mkdir -p /var/www/pocketbase/hooks
cat > /var/www/pocketbase/hooks/main.pb.js << 'EOF'
// PocketBase hooks example
// Uncomment and modify as needed

/*
onRecordAfterCreateRequest((e) => {
    console.log("New record created:", e.record.id)
}, "users")

onRecordAfterUpdateRequest((e) => {
    console.log("Record updated:", e.record.id)
}, "users")
*/
EOF

# Step 5: Create systemd service
echo_step "🔄 Creating systemd service"

sudo tee /etc/systemd/system/pocketbase.service > /dev/null << EOF
[Unit]
Description=PocketBase Backend Service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=5
User=$USER
WorkingDirectory=/var/www/pocketbase
Environment=PB_DATA_DIR=/var/www/pocketbase/data
Environment=PB_HOOKS_DIR=/var/www/pocketbase/hooks
Environment=PB_PUBLIC_DIR=/var/www/pocketbase/public
Environment=PB_MIGRATIONS_DIR=/var/www/pocketbase/migrations
ExecStart=/var/www/pocketbase/pocketbase serve --http=127.0.0.1:$PORT --dir=/var/www/pocketbase/data
StandardOutput=append:/var/www/pocketbase/logs/pocketbase.log
StandardError=append:/var/www/pocketbase/logs/error.log

[Install]
WantedBy=multi-user.target
EOF

# Step 6: Configure Nginx
echo_step "🌐 Configuring Nginx"

# Check if multi-projects nginx config exists, if not create a basic one
if [ ! -f /etc/nginx/sites-available/multi-projects ]; then
    echo_info "Creating base Nginx configuration..."
    sudo tee /etc/nginx/sites-available/multi-projects > /dev/null << EOF
# Rate limiting
limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
EOF
    sudo ln -sf /etc/nginx/sites-available/multi-projects /etc/nginx/sites-enabled/
fi

# Add PocketBase configuration to existing nginx config
echo_info "Adding PocketBase to Nginx configuration..."

# Create a temporary file with PocketBase config
cat > /tmp/pocketbase-nginx.conf << EOF

# Upstream for PocketBase
upstream pocketbase {
    server 127.0.0.1:$PORT;
    keepalive 2;
}

# PocketBase server block
server {
    listen 80;
    server_name $SUBDOMAIN.$DOMAIN;
    
    # Increase client max body size for file uploads
    client_max_body_size 100M;
    
    location / {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://pocketbase;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # WebSocket support
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
        
        # Optimize for low resource usage
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
    }
    
    # Special handling for PocketBase admin UI
    location /_/ {
        proxy_pass http://pocketbase;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Append PocketBase config to existing nginx config
sudo sh -c "cat /tmp/pocketbase-nginx.conf >> /etc/nginx/sites-available/multi-projects"
rm /tmp/pocketbase-nginx.conf

# Test Nginx configuration
if sudo nginx -t; then
    echo_info "Nginx configuration is valid"
    sudo systemctl reload nginx
else
    echo_error "Nginx configuration has errors!"
    exit 1
fi

# Step 7: Create management scripts
echo_step "📜 Creating management scripts"

# PocketBase management script
cat > /var/www/pocketbase/manage.sh << EOF
#!/bin/bash

case "\$1" in
    start)
        echo "Starting PocketBase..."
        sudo systemctl start pocketbase
        ;;
    stop)
        echo "Stopping PocketBase..."
        sudo systemctl stop pocketbase
        ;;
    restart)
        echo "Restarting PocketBase..."
        sudo systemctl restart pocketbase
        ;;
    status)
        sudo systemctl status pocketbase
        ;;
    logs)
        echo "Recent logs:"
        tail -n 50 /var/www/pocketbase/logs/pocketbase.log
        ;;
    backup)
        echo "Creating backup..."
        BACKUP_NAME="pocketbase-backup-\$(date +%Y%m%d-%H%M%S).tar.gz"
        tar -czf "/var/www/pocketbase/backups/\$BACKUP_NAME" -C /var/www/pocketbase/data .
        echo "Backup created: /var/www/pocketbase/backups/\$BACKUP_NAME"
        ;;
    update)
        echo "Updating PocketBase..."
        sudo systemctl stop pocketbase
        cd /tmp
        LATEST_VERSION=\$(curl -s https://api.github.com/repos/pocketbase/pocketbase/releases/latest | grep -Po '"tag_name": "v\K[^"]*' 2>/dev/null || echo "0.22.0")
        wget -q "https://github.com/pocketbase/pocketbase/releases/download/v\${LATEST_VERSION}/pocketbase_\${LATEST_VERSION}_linux_amd64.zip" -O pocketbase.zip
        unzip -q pocketbase.zip
        sudo mv pocketbase /var/www/pocketbase/
        sudo chmod +x /var/www/pocketbase/pocketbase
        rm pocketbase.zip
        sudo systemctl start pocketbase
        echo "PocketBase updated to version \$LATEST_VERSION"
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status|logs|backup|update}"
        exit 1
        ;;
esac
EOF

chmod +x /var/www/pocketbase/manage.sh

# Backup script
cat > /var/www/pocketbase/backup-cron.sh << EOF
#!/bin/bash
# Auto backup script for PocketBase
# Add to crontab: 0 2 * * * /var/www/pocketbase/backup-cron.sh

BACKUP_DIR="/var/www/pocketbase/backups"
DATA_DIR="/var/www/pocketbase/data"
BACKUP_NAME="pocketbase-auto-backup-\$(date +%Y%m%d-%H%M%S).tar.gz"

# Create backup
tar -czf "\$BACKUP_DIR/\$BACKUP_NAME" -C "\$DATA_DIR" .

# Keep only last 7 days of backups
find "\$BACKUP_DIR" -name "pocketbase-auto-backup-*" -mtime +7 -delete

echo "\$(date): Backup created: \$BACKUP_NAME" >> "\$BACKUP_DIR/backup.log"
EOF

chmod +x /var/www/pocketbase/backup-cron.sh

# Step 8: Configure firewall
echo_step "🔒 Configuring firewall"

if command -v ufw &> /dev/null; then
    # Allow HTTP and HTTPS if not already allowed
    sudo ufw allow 80/tcp  >/dev/null 2>&1 || true
    sudo ufw allow 443/tcp >/dev/null 2>&1 || true
    echo_info "Firewall configured"
fi

# Step 9: Enable and start services
echo_step "🚀 Starting services"

# Enable and start PocketBase
sudo systemctl daemon-reload
sudo systemctl enable pocketbase
sudo systemctl start pocketbase

# Wait a moment for service to start
sleep 3

# Check if PocketBase is running
if sudo systemctl is-active --quiet pocketbase; then
    echo_info "PocketBase service started successfully"
else
    echo_error "Failed to start PocketBase service"
    echo "Check logs with: sudo journalctl -u pocketbase -f"
    exit 1
fi

# Step 10: Setup SSL certificate
echo_step "🔒 Setting up SSL certificate"

echo_info "Setting up SSL certificate for $SUBDOMAIN.$DOMAIN..."
if sudo certbot --nginx -d "$SUBDOMAIN.$DOMAIN" --non-interactive --agree-tos --email "${ADMIN_EMAIL:-admin@$DOMAIN}" --redirect; then
    echo_info "SSL certificate installed successfully"
else
    echo_warn "SSL certificate setup failed. You can set it up manually later with:"
    echo "sudo certbot --nginx -d $SUBDOMAIN.$DOMAIN"
fi

# Final Steps
echo_step "✅ PocketBase Setup Complete!"

echo ""
echo "=============================================="
echo "🎉 PocketBase Deployed Successfully!"
echo "=============================================="
echo ""
echo "📍 Access Information:"
echo "   PocketBase URL: https://$SUBDOMAIN.$DOMAIN"
echo "   Admin Panel: https://$SUBDOMAIN.$DOMAIN/_/"
echo "   Port: $PORT (internal)"
echo ""
echo "📁 Directory Structure:"
echo "   /var/www/pocketbase/        - Main directory"
echo "   /var/www/pocketbase/data/   - Database and files"
echo "   /var/www/pocketbase/logs/   - Application logs"
echo "   /var/www/pocketbase/backups/- Backup storage"
echo ""
echo "🛠️ Management Commands:"
echo "   /var/www/pocketbase/manage.sh start    - Start PocketBase"
echo "   /var/www/pocketbase/manage.sh stop     - Stop PocketBase"
echo "   /var/www/pocketbase/manage.sh restart  - Restart PocketBase"
echo "   /var/www/pocketbase/manage.sh status   - Check status"
echo "   /var/www/pocketbase/manage.sh logs     - View logs"
echo "   /var/www/pocketbase/manage.sh backup   - Create backup"
echo "   /var/www/pocketbase/manage.sh update   - Update PocketBase"
echo ""
echo "⚡ Next Steps:"
echo "1. Visit the admin panel to set up your first admin user:"
echo "   https://$SUBDOMAIN.$DOMAIN/_/"
echo ""
echo "2. Configure automatic backups (optional):"
echo "   crontab -e"
echo "   Add: 0 2 * * * /var/www/pocketbase/backup-cron.sh"
echo ""
echo "3. API Documentation will be available at:"
echo "   https://$SUBDOMAIN.$DOMAIN/_/docs"
echo ""
echo "💡 Tips:"
echo "- PocketBase runs as a systemd service"
echo "- Logs are stored in /var/www/pocketbase/logs/"
echo "- Database is stored in /var/www/pocketbase/data/"
echo "- File uploads are handled automatically"
echo "- WebSocket support is enabled for real-time features"
echo ""
echo "🆘 Troubleshooting:"
echo "- Check service status: sudo systemctl status pocketbase"
echo "- View service logs: sudo journalctl -u pocketbase -f"
echo "- Check Nginx logs: sudo tail -f /var/log/nginx/error.log"
echo ""
echo_info "PocketBase is ready to use! 🚀" 