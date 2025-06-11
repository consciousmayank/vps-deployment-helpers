#!/bin/bash

# Multi-PocketBase VPS Deployment Script
# Usage: ./setup-multi-pocketbase.sh

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

echo_step "🚀 Multi-PocketBase VPS Deployment Script"
echo "This script will deploy multiple PocketBase instances on your VPS with SSL and domain configuration."
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

# Get number of PocketBase instances
while true; do
    read -p "How many PocketBase instances do you want to deploy? (1-10): " NUM_INSTANCES
    if [[ $NUM_INSTANCES =~ ^[0-9]+$ ]] && [ $NUM_INSTANCES -ge 1 ] && [ $NUM_INSTANCES -le 10 ]; then
        break
    else
        echo_error "Please enter a number between 1 and 10"
    fi
done

# Initialize arrays
INSTANCE_NAMES=()
SUBDOMAINS=()
PORTS=()
DESCRIPTIONS=()

# Get instance details
echo ""
echo_info "Now let's configure each PocketBase instance:"
for ((i=1; i<=NUM_INSTANCES; i++)); do
    echo ""
    echo "--- PocketBase Instance $i ---"
    
    # Get instance name
    while true; do
        read -p "Instance $i name (e.g., main-api, blog-backend, auth): " instance_name
        if [[ $instance_name =~ ^[a-zA-Z0-9_-]+$ ]]; then
            # Check if instance name already exists
            name_conflict=false
            for existing_name in "${INSTANCE_NAMES[@]}"; do
                if [ "$instance_name" = "$existing_name" ]; then
                    echo_error "Instance name '$instance_name' is already used. Please choose a different one."
                    name_conflict=true
                    break
                fi
            done
            if [ "$name_conflict" = false ]; then
                INSTANCE_NAMES+=("$instance_name")
                break
            fi
        else
            echo_error "Instance name should contain only letters, numbers, underscores, and hyphens"
        fi
    done
    
    # Get subdomain
    while true; do
        read -p "Subdomain for $instance_name (will create ${instance_name}.${DOMAIN}): " subdomain
        subdomain=${subdomain:-$instance_name}
        if [[ $subdomain =~ ^[a-zA-Z0-9_-]+$ ]]; then
            # Check if subdomain already exists
            subdomain_conflict=false
            for existing_subdomain in "${SUBDOMAINS[@]}"; do
                if [ "$subdomain" = "$existing_subdomain" ]; then
                    echo_error "Subdomain '$subdomain' is already used. Please choose a different one."
                    subdomain_conflict=true
                    break
                fi
            done
            if [ "$subdomain_conflict" = false ]; then
                SUBDOMAINS+=("$subdomain")
                break
            fi
        else
            echo_error "Subdomain should contain only letters, numbers, underscores, and hyphens"
        fi
    done
    
    # Get port
    while true; do
        default_port=$((8090 + i - 1))
        read -p "Port for $instance_name (default: $default_port): " port
        port=${port:-$default_port}
        
        if validate_port "$port"; then
            # Check if port is already in use
            port_in_use=false
            for existing_port in "${PORTS[@]}"; do
                if [ "$port" -eq "$existing_port" ]; then
                    echo_error "Port $port is already used by another instance. Please choose a different port."
                    port_in_use=true
                    break
                fi
            done
            
            if [ "$port_in_use" = false ]; then
                if check_port_available "$port"; then
                    PORTS+=("$port")
                    break
                else
                    echo_warn "Port $port appears to be in use by another service. Continue anyway? (y/n)"
                    read -p "" continue_anyway
                    if [[ $continue_anyway =~ ^[Yy]$ ]]; then
                        PORTS+=("$port")
                        break
                    fi
                fi
            fi
        else
            echo_error "Port must be a number between 1024 and 65535"
        fi
    done
    
    # Get description (optional)
    read -p "Description for $instance_name (optional): " description
    DESCRIPTIONS+=("${description:-"PocketBase instance for $instance_name"}")
done

# Get admin email
while true; do
    read -p "Admin email for SSL certificates (optional, press Enter to skip): " ADMIN_EMAIL
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
echo "Number of PocketBase instances: $NUM_INSTANCES"
echo ""
for ((i=0; i<NUM_INSTANCES; i++)); do
    echo "Instance $((i+1)): ${INSTANCE_NAMES[i]}"
    echo "  URL: https://${SUBDOMAINS[i]}.${DOMAIN}"
    echo "  Port: ${PORTS[i]}"
    echo "  Description: ${DESCRIPTIONS[i]}"
    echo ""
done
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

# Detect architecture
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

# Download PocketBase once
cd /tmp
echo_info "Downloading PocketBase from: $DOWNLOAD_URL"
if ! wget -q "$DOWNLOAD_URL" -O pocketbase.zip; then
    echo_error "Failed to download PocketBase"
    exit 1
fi

unzip -q pocketbase.zip
chmod +x pocketbase
echo_info "PocketBase downloaded successfully"

# Step 3: Setup Each PocketBase Instance
echo_step "📁 Setting up PocketBase instances"

for ((i=0; i<NUM_INSTANCES; i++)); do
    instance_name="${INSTANCE_NAMES[i]}"
    port="${PORTS[i]}"
    description="${DESCRIPTIONS[i]}"
    
    echo_info "Setting up instance: $instance_name"
    
    # Create directories
    sudo mkdir -p "/var/www/pocketbase-$instance_name"/{data,logs,backups,hooks}
    sudo chown -R $USER:$USER "/var/www/pocketbase-$instance_name"
    
    # Copy PocketBase binary
    cp pocketbase "/var/www/pocketbase-$instance_name/"
    
    # Create environment file
    cat > "/var/www/pocketbase-$instance_name/.env" << EOF
# PocketBase Configuration for $instance_name
PB_DATA_DIR=/var/www/pocketbase-$instance_name/data
PB_HOOKS_DIR=/var/www/pocketbase-$instance_name/hooks
PB_PUBLIC_DIR=/var/www/pocketbase-$instance_name/public
PB_MIGRATIONS_DIR=/var/www/pocketbase-$instance_name/migrations
EOF

    # Create hooks example
    cat > "/var/www/pocketbase-$instance_name/hooks/main.pb.js" << 'EOF'
// PocketBase hooks for this instance
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

    # Create systemd service
    sudo tee "/etc/systemd/system/pocketbase-$instance_name.service" > /dev/null << EOF
[Unit]
Description=$description
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=5
User=$USER
WorkingDirectory=/var/www/pocketbase-$instance_name
Environment=PB_DATA_DIR=/var/www/pocketbase-$instance_name/data
Environment=PB_HOOKS_DIR=/var/www/pocketbase-$instance_name/hooks
Environment=PB_PUBLIC_DIR=/var/www/pocketbase-$instance_name/public
Environment=PB_MIGRATIONS_DIR=/var/www/pocketbase-$instance_name/migrations
ExecStart=/var/www/pocketbase-$instance_name/pocketbase serve --http=127.0.0.1:$port --dir=/var/www/pocketbase-$instance_name/data
StandardOutput=append:/var/www/pocketbase-$instance_name/logs/pocketbase.log
StandardError=append:/var/www/pocketbase-$instance_name/logs/error.log

[Install]
WantedBy=multi-user.target
EOF

    # Create management script
    cat > "/var/www/pocketbase-$instance_name/manage.sh" << EOF
#!/bin/bash

INSTANCE_NAME="$instance_name"
SERVICE_NAME="pocketbase-$instance_name"

case "\$1" in
    start)
        echo "Starting PocketBase instance: \$INSTANCE_NAME..."
        sudo systemctl start "\$SERVICE_NAME"
        ;;
    stop)
        echo "Stopping PocketBase instance: \$INSTANCE_NAME..."
        sudo systemctl stop "\$SERVICE_NAME"
        ;;
    restart)
        echo "Restarting PocketBase instance: \$INSTANCE_NAME..."
        sudo systemctl restart "\$SERVICE_NAME"
        ;;
    status)
        sudo systemctl status "\$SERVICE_NAME"
        ;;
    logs)
        echo "Recent logs for \$INSTANCE_NAME:"
        tail -n 50 "/var/www/pocketbase-\$INSTANCE_NAME/logs/pocketbase.log"
        ;;
    backup)
        echo "Creating backup for \$INSTANCE_NAME..."
        BACKUP_NAME="pocketbase-\$INSTANCE_NAME-backup-\$(date +%Y%m%d-%H%M%S).tar.gz"
        tar -czf "/var/www/pocketbase-\$INSTANCE_NAME/backups/\$BACKUP_NAME" -C "/var/www/pocketbase-\$INSTANCE_NAME/data" .
        echo "Backup created: /var/www/pocketbase-\$INSTANCE_NAME/backups/\$BACKUP_NAME"
        ;;
    update)
        echo "Updating PocketBase instance: \$INSTANCE_NAME..."
        sudo systemctl stop "\$SERVICE_NAME"
        cd /tmp
        LATEST_VERSION=\$(curl -s https://api.github.com/repos/pocketbase/pocketbase/releases/latest | grep -Po '"tag_name": "v\K[^"]*' 2>/dev/null || echo "0.22.0")
        wget -q "https://github.com/pocketbase/pocketbase/releases/download/v\${LATEST_VERSION}/pocketbase_\${LATEST_VERSION}_linux_$POCKETBASE_ARCH.zip" -O pocketbase.zip
        unzip -q pocketbase.zip
        cp pocketbase "/var/www/pocketbase-\$INSTANCE_NAME/"
        chmod +x "/var/www/pocketbase-\$INSTANCE_NAME/pocketbase"
        rm pocketbase.zip pocketbase
        sudo systemctl start "\$SERVICE_NAME"
        echo "PocketBase instance \$INSTANCE_NAME updated to version \$LATEST_VERSION"
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status|logs|backup|update}"
        echo "Managing PocketBase instance: \$INSTANCE_NAME"
        exit 1
        ;;
esac
EOF

    chmod +x "/var/www/pocketbase-$instance_name/manage.sh"
    
    # Create backup script
    cat > "/var/www/pocketbase-$instance_name/backup-cron.sh" << EOF
#!/bin/bash
# Auto backup script for PocketBase instance: $instance_name
# Add to crontab: 0 2 * * * /var/www/pocketbase-$instance_name/backup-cron.sh

BACKUP_DIR="/var/www/pocketbase-$instance_name/backups"
DATA_DIR="/var/www/pocketbase-$instance_name/data"
BACKUP_NAME="pocketbase-$instance_name-auto-backup-\$(date +%Y%m%d-%H%M%S).tar.gz"

# Create backup
tar -czf "\$BACKUP_DIR/\$BACKUP_NAME" -C "\$DATA_DIR" .

# Keep only last 7 days of backups
find "\$BACKUP_DIR" -name "pocketbase-$instance_name-auto-backup-*" -mtime +7 -delete

echo "\$(date): Backup created for $instance_name: \$BACKUP_NAME" >> "\$BACKUP_DIR/backup.log"
EOF

    chmod +x "/var/www/pocketbase-$instance_name/backup-cron.sh"
done

# Cleanup
rm pocketbase pocketbase.zip

# Step 4: Configure Nginx
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

# Generate nginx configuration for all instances
echo_info "Adding PocketBase instances to Nginx configuration..."

# Create temporary file with all PocketBase configurations
cat > /tmp/multi-pocketbase-nginx.conf << EOF

# PocketBase instances configuration
$(for ((i=0; i<NUM_INSTANCES; i++)); do
    instance_name="${INSTANCE_NAMES[i]}"
    subdomain="${SUBDOMAINS[i]}"
    port="${PORTS[i]}"
    cat << SERVEREOF

# Upstream for PocketBase instance: $instance_name
upstream pocketbase-$instance_name {
    server 127.0.0.1:$port;
    keepalive 2;
}

# Server block for $instance_name
server {
    listen 80;
    server_name $subdomain.$DOMAIN;
    
    # Increase client max body size for file uploads
    client_max_body_size 100M;
    
    location / {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://pocketbase-$instance_name;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # WebSocket support
        proxy_read_timeout 86400;
        
        # Optimize for low resource usage
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
    }
    
    # Special handling for PocketBase admin UI
    location /_/ {
        proxy_pass http://pocketbase-$instance_name;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
SERVEREOF
done)
EOF

# Append PocketBase configs to existing nginx config
sudo sh -c "cat /tmp/multi-pocketbase-nginx.conf >> /etc/nginx/sites-available/multi-projects"
rm /tmp/multi-pocketbase-nginx.conf

# Test Nginx configuration
if sudo nginx -t; then
    echo_info "Nginx configuration is valid"
    sudo systemctl reload nginx
else
    echo_error "Nginx configuration has errors!"
    exit 1
fi

# Step 5: Configure firewall
echo_step "🔒 Configuring firewall"

if command -v ufw &> /dev/null; then
    # Allow HTTP and HTTPS if not already allowed
    sudo ufw allow 80/tcp  >/dev/null 2>&1 || true
    sudo ufw allow 443/tcp >/dev/null 2>&1 || true
    echo_info "Firewall configured"
fi

# Step 6: Enable and start services
echo_step "🚀 Starting PocketBase instances"

# Enable and start all PocketBase instances
for ((i=0; i<NUM_INSTANCES; i++)); do
    instance_name="${INSTANCE_NAMES[i]}"
    
    echo_info "Starting instance: $instance_name"
    sudo systemctl daemon-reload
    sudo systemctl enable "pocketbase-$instance_name"
    sudo systemctl start "pocketbase-$instance_name"
    
    # Wait a moment for service to start
    sleep 2
    
    # Check if instance is running
    if sudo systemctl is-active --quiet "pocketbase-$instance_name"; then
        echo_info "PocketBase instance '$instance_name' started successfully"
    else
        echo_error "Failed to start PocketBase instance '$instance_name'"
        echo "Check logs with: sudo journalctl -u pocketbase-$instance_name -f"
    fi
done

# Step 7: Setup SSL certificates
echo_step "🔒 Setting up SSL certificates"

# Build certbot command with all domains
CERT_DOMAINS=""
for ((i=0; i<NUM_INSTANCES; i++)); do
    subdomain="${SUBDOMAINS[i]}"
    CERT_DOMAINS="$CERT_DOMAINS -d ${subdomain}.${DOMAIN}"
done

echo_info "Setting up SSL certificates for all instances..."
if sudo certbot --nginx $CERT_DOMAINS --non-interactive --agree-tos --email "${ADMIN_EMAIL:-admin@$DOMAIN}" --redirect; then
    echo_info "SSL certificates installed successfully"
else
    echo_warn "SSL certificate setup failed. You can set it up manually later with:"
    echo "sudo certbot --nginx $CERT_DOMAINS"
fi

# Step 8: Create global management script
echo_step "📜 Creating global management script"

cat > /var/www/manage-all-pocketbase.sh << EOF
#!/bin/bash

# Global PocketBase instances management script

INSTANCES=($(printf '"%s" ' "${INSTANCE_NAMES[@]}"))

show_help() {
    echo "Usage: \$0 {start|stop|restart|status|logs|backup|update} [instance-name]"
    echo ""
    echo "Commands:"
    echo "  start [instance]   - Start all instances or specific instance"
    echo "  stop [instance]    - Stop all instances or specific instance"
    echo "  restart [instance] - Restart all instances or specific instance"
    echo "  status [instance]  - Show status of all instances or specific instance"
    echo "  logs [instance]    - Show logs of all instances or specific instance"
    echo "  backup [instance]  - Backup all instances or specific instance"
    echo "  update [instance]  - Update all instances or specific instance"
    echo "  list              - List all instances"
    echo ""
    echo "Available instances:"
    for instance in "\${INSTANCES[@]}"; do
        echo "  - \$instance"
    done
}

list_instances() {
    echo "PocketBase Instances:"
    for instance in "\${INSTANCES[@]}"; do
        echo "  \$instance:"
        echo "    Service: pocketbase-\$instance"
        echo "    Directory: /var/www/pocketbase-\$instance"
        echo "    Management: /var/www/pocketbase-\$instance/manage.sh"
        if sudo systemctl is-active --quiet "pocketbase-\$instance"; then
            echo "    Status: ✅ Running"
        else
            echo "    Status: ❌ Stopped"
        fi
        echo ""
    done
}

execute_command() {
    local cmd=\$1
    local target_instance=\$2
    
    if [ -n "\$target_instance" ]; then
        # Execute on specific instance
        if [[ " \${INSTANCES[@]} " =~ " \$target_instance " ]]; then
            echo "Executing \$cmd on instance: \$target_instance"
            "/var/www/pocketbase-\$target_instance/manage.sh" "\$cmd"
        else
            echo "Error: Instance '\$target_instance' not found"
            echo "Available instances: \${INSTANCES[*]}"
            exit 1
        fi
    else
        # Execute on all instances
        echo "Executing \$cmd on all instances..."
        for instance in "\${INSTANCES[@]}"; do
            echo "--- \$instance ---"
            "/var/www/pocketbase-\$instance/manage.sh" "\$cmd"
            echo ""
        done
    fi
}

case "\$1" in
    start|stop|restart|status|logs|backup|update)
        execute_command "\$1" "\$2"
        ;;
    list)
        list_instances
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo "Unknown command: \$1"
        show_help
        exit 1
        ;;
esac
EOF

chmod +x /var/www/manage-all-pocketbase.sh

# Final Steps
echo_step "✅ Multi-PocketBase Setup Complete!"

echo ""
echo "====================================================="
echo "🎉 Multiple PocketBase Instances Deployed Successfully!"
echo "====================================================="
echo ""
echo "📍 Access Information:"
for ((i=0; i<NUM_INSTANCES; i++)); do
    instance_name="${INSTANCE_NAMES[i]}"
    subdomain="${SUBDOMAINS[i]}"
    port="${PORTS[i]}"
    description="${DESCRIPTIONS[i]}"
    echo "  Instance: $instance_name"
    echo "    URL: https://$subdomain.$DOMAIN"
    echo "    Admin: https://$subdomain.$DOMAIN/_/"
    echo "    Port: $port (internal)"
    echo "    Description: $description"
    echo ""
done

echo "📁 Directory Structure:"
for ((i=0; i<NUM_INSTANCES; i++)); do
    instance_name="${INSTANCE_NAMES[i]}"
    echo "   /var/www/pocketbase-$instance_name/        - Instance directory"
    echo "   /var/www/pocketbase-$instance_name/data/   - Database and files"
    echo "   /var/www/pocketbase-$instance_name/logs/   - Application logs"
done
echo ""

echo "🛠️ Management Commands:"
echo "   /var/www/manage-all-pocketbase.sh              - Manage all instances"
echo "   /var/www/manage-all-pocketbase.sh list         - List all instances"
echo "   /var/www/manage-all-pocketbase.sh start [name] - Start instance(s)"
echo "   /var/www/manage-all-pocketbase.sh logs [name]  - View logs"
echo ""
echo "   Individual instance management:"
for ((i=0; i<NUM_INSTANCES; i++)); do
    instance_name="${INSTANCE_NAMES[i]}"
    echo "   /var/www/pocketbase-$instance_name/manage.sh - Manage $instance_name"
done
echo ""

echo "⚡ Next Steps:"
echo "1. Visit each admin panel to set up admin users:"
for ((i=0; i<NUM_INSTANCES; i++)); do
    instance_name="${INSTANCE_NAMES[i]}"
    subdomain="${SUBDOMAINS[i]}"
    echo "   $instance_name: https://$subdomain.$DOMAIN/_/"
done
echo ""
echo "2. Configure automatic backups for each instance:"
echo "   crontab -e"
for ((i=0; i<NUM_INSTANCES; i++)); do
    instance_name="${INSTANCE_NAMES[i]}"
    echo "   Add: 0 2 * * * /var/www/pocketbase-$instance_name/backup-cron.sh"
done
echo ""

echo "💡 Tips:"
PORTS_STRING=""
for port in "${PORTS[@]}"; do
    PORTS_STRING="$PORTS_STRING$port, "
done
PORTS_STRING=${PORTS_STRING%, }
echo "- PocketBase instances run on ports: $PORTS_STRING"
echo "- Each instance has its own database and admin panel"
echo "- All instances run as systemd services"
echo "- WebSocket support is enabled for real-time features"
echo "- Use the global management script for bulk operations"
ESTIMATED_RAM=$((NUM_INSTANCES * 100 + 200))
echo "- Total estimated RAM usage: ~${ESTIMATED_RAM}MB"
echo ""

echo "🆘 Troubleshooting:"
echo "- Check all instances: /var/www/manage-all-pocketbase.sh status"
echo "- View specific logs: /var/www/manage-all-pocketbase.sh logs [instance-name]"
echo "- Check service logs: sudo journalctl -u pocketbase-[instance-name] -f"
echo "- Check Nginx logs: sudo tail -f /var/log/nginx/error.log"
echo ""
echo_info "All PocketBase instances are ready to use! 🚀" 