#!/bin/bash

# Multi-Project VPS Setup Script
# Usage: ./setup-multi-projects.sh

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

# Interactive Configuration
echo_step "🔧 Interactive Configuration Setup"
echo "Let's configure your multi-project VPS environment!"
echo ""

# Get domain
while true; do
    read -p "Enter your domain name (e.g., example.com): " DOMAIN
    if validate_domain "$DOMAIN"; then
        break
    else
        echo_error "Invalid domain format. Please enter a valid domain (e.g., example.com)"
    fi
done

# Get number of projects
while true; do
    read -p "How many projects do you want to deploy? (1-10): " NUM_PROJECTS
    if [[ $NUM_PROJECTS =~ ^[0-9]+$ ]] && [ $NUM_PROJECTS -ge 1 ] && [ $NUM_PROJECTS -le 10 ]; then
        break
    else
        echo_error "Please enter a number between 1 and 10"
    fi
done

# Initialize arrays
PROJECTS=()
SUBDOMAINS=()
PORTS=()

# Get project details
echo ""
echo_info "Now let's configure each project:"
for ((i=1; i<=NUM_PROJECTS; i++)); do
    echo ""
    echo "--- Project $i ---"
    
    # Get project name
    while true; do
        read -p "Project $i name (e.g., portfolio, blog): " project_name
        if [[ $project_name =~ ^[a-zA-Z0-9_-]+$ ]]; then
            PROJECTS+=("$project_name")
            break
        else
            echo_error "Project name should contain only letters, numbers, underscores, and hyphens"
        fi
    done
    
    # Get subdomain
    while true; do
        read -p "Subdomain for $project_name (leave empty to use main domain ${DOMAIN}, or enter subdomain to create ${project_name}.${DOMAIN}): " subdomain
        if [ -z "$subdomain" ]; then
            # Check if main domain is already taken
            domain_conflict=false
            for existing_subdomain in "${SUBDOMAINS[@]}"; do
                if [ -z "$existing_subdomain" ]; then
                    echo_error "Main domain ${DOMAIN} is already assigned to another project"
                    domain_conflict=true
                    break
                fi
            done
            if [ "$domain_conflict" = false ]; then
                SUBDOMAINS+=("")
                break
            fi
        elif [[ $subdomain =~ ^[a-zA-Z0-9_-]+$ ]]; then
            # Check if subdomain conflicts with existing ones
            subdomain_conflict=false
            for existing_subdomain in "${SUBDOMAINS[@]}"; do
                if [ "$subdomain" = "$existing_subdomain" ]; then
                    echo_error "Subdomain '$subdomain' is already used by another project"
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
        default_port=$((3000 + i))
        read -p "Port for $project_name (default: $default_port): " port
        port=${port:-$default_port}
        
        if validate_port "$port"; then
            # Check if port is already in use by another project
            port_in_use=false
            for existing_port in "${PORTS[@]}"; do
                if [ "$port" -eq "$existing_port" ]; then
                    echo_error "Port $port is already used by another project. Please choose a different port."
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
done

# Ask about PocketBase
echo ""
echo_step "🎒 PocketBase Integration"
read -p "Would you like to also deploy PocketBase as your backend? (y/n): " DEPLOY_POCKETBASE
if [[ $DEPLOY_POCKETBASE =~ ^[Yy]$ ]]; then
    # Ask if they want multiple instances
    read -p "Do you want multiple PocketBase instances? (y/n): " MULTI_POCKETBASE
    if [[ $MULTI_POCKETBASE =~ ^[Yy]$ ]]; then
        while true; do
            read -p "How many PocketBase instances? (1-5): " NUM_PB_INSTANCES
            if [[ $NUM_PB_INSTANCES =~ ^[0-9]+$ ]] && [ $NUM_PB_INSTANCES -ge 1 ] && [ $NUM_PB_INSTANCES -le 5 ]; then
                break
            else
                echo_error "Please enter a number between 1 and 5"
            fi
        done
        
        # Initialize arrays for multiple instances
        POCKETBASE_NAMES=()
        POCKETBASE_SUBDOMAINS=()
        POCKETBASE_PORTS=()
        
        for ((pb_i=1; pb_i<=NUM_PB_INSTANCES; pb_i++)); do
            echo ""
            echo "--- PocketBase Instance $pb_i ---"
            
            # Get instance name
            while true; do
                read -p "Instance $pb_i name (e.g., main-api, auth, blog-backend): " pb_name
                if [[ $pb_name =~ ^[a-zA-Z0-9_-]+$ ]]; then
                    # Check if name conflicts with existing names
                    name_conflict=false
                    for existing_name in "${POCKETBASE_NAMES[@]}"; do
                        if [ "$pb_name" = "$existing_name" ]; then
                            echo_error "Name '$pb_name' is already used. Please choose a different one."
                            name_conflict=true
                            break
                        fi
                    done
                    if [ "$name_conflict" = false ]; then
                        POCKETBASE_NAMES+=("$pb_name")
                        break
                    fi
                else
                    echo_error "Name should contain only letters, numbers, underscores, and hyphens"
                fi
            done
            
            # Get subdomain
            while true; do
                read -p "Subdomain for $pb_name (e.g., 'api' for api.$DOMAIN): " pb_subdomain
                if [[ $pb_subdomain =~ ^[a-zA-Z0-9_-]+$ ]]; then
                    # Check conflicts with projects and other PocketBase instances
                    subdomain_conflict=false
                    for existing_subdomain in "${SUBDOMAINS[@]}" "${POCKETBASE_SUBDOMAINS[@]}"; do
                        if [ "$pb_subdomain" = "$existing_subdomain" ]; then
                            echo_error "Subdomain '$pb_subdomain' is already used. Please choose a different one."
                            subdomain_conflict=true
                            break
                        fi
                    done
                    if [ "$subdomain_conflict" = false ]; then
                        POCKETBASE_SUBDOMAINS+=("$pb_subdomain")
                        break
                    fi
                else
                    echo_error "Subdomain should contain only letters, numbers, underscores, and hyphens"
                fi
            done
            
            # Get port
            while true; do
                default_pb_port=$((8090 + pb_i - 1))
                read -p "Port for $pb_name (default: $default_pb_port): " pb_port
                pb_port=${pb_port:-$default_pb_port}
                
                if validate_port "$pb_port"; then
                    # Check conflicts with projects and other PocketBase instances
                    port_conflict=false
                    for existing_port in "${PORTS[@]}" "${POCKETBASE_PORTS[@]}"; do
                        if [ "$pb_port" -eq "$existing_port" ]; then
                            echo_error "Port $pb_port is already used. Please choose a different port."
                            port_conflict=true
                            break
                        fi
                    done
                    if [ "$port_conflict" = false ]; then
                        POCKETBASE_PORTS+=("$pb_port")
                        break
                    fi
                else
                    echo_error "Port must be a number between 1024 and 65535"
                fi
            done
        done
    else
        # Single PocketBase instance (existing logic)
    while true; do
        read -p "Enter subdomain for PocketBase (e.g., 'api' for api.$DOMAIN): " POCKETBASE_SUBDOMAIN
        if [[ $POCKETBASE_SUBDOMAIN =~ ^[a-zA-Z0-9_-]+$ ]]; then
            # Check if subdomain conflicts with existing projects
            subdomain_conflict=false
            for existing_subdomain in "${SUBDOMAINS[@]}"; do
                if [ "$POCKETBASE_SUBDOMAIN" = "$existing_subdomain" ]; then
                    echo_error "Subdomain '$POCKETBASE_SUBDOMAIN' is already used by another project. Please choose a different one."
                    subdomain_conflict=true
                    break
                fi
            done
            if [ "$subdomain_conflict" = false ]; then
                break
            fi
        else
            echo_error "Subdomain should contain only letters, numbers, underscores, and hyphens"
        fi
    done
    
    while true; do
        default_pb_port=8090
        read -p "Port for PocketBase (default: $default_pb_port): " POCKETBASE_PORT
        POCKETBASE_PORT=${POCKETBASE_PORT:-$default_pb_port}
        
        if validate_port "$POCKETBASE_PORT"; then
            # Check if port conflicts with existing projects
            port_conflict=false
            for existing_port in "${PORTS[@]}"; do
                if [ "$POCKETBASE_PORT" -eq "$existing_port" ]; then
                    echo_error "Port $POCKETBASE_PORT is already used by another project. Please choose a different port."
                    port_conflict=true
                    break
                fi
            done
            if [ "$port_conflict" = false ]; then
                break
            fi
        else
            echo_error "Port must be a number between 1024 and 65535"
        fi
    done
    fi # End of single PocketBase instance setup
fi

# Confirmation
echo ""
echo_step "🔍 Configuration Summary"
echo "Domain: $DOMAIN"
echo "Number of projects: $NUM_PROJECTS"
echo ""
for ((i=0; i<NUM_PROJECTS; i++)); do
    echo "Project $((i+1)): ${PROJECTS[i]}"
    echo "  Subdomain: ${SUBDOMAINS[i]}.${DOMAIN}"
    echo "  Port: ${PORTS[i]}"
done

if [[ $DEPLOY_POCKETBASE =~ ^[Yy]$ ]]; then
    echo ""
    if [[ $MULTI_POCKETBASE =~ ^[Yy]$ ]]; then
        echo "PocketBase Instances:"
        for ((pb_i=0; pb_i<${#POCKETBASE_NAMES[@]}; pb_i++)); do
            echo "  ${POCKETBASE_NAMES[pb_i]}:"
            echo "    Subdomain: ${POCKETBASE_SUBDOMAINS[pb_i]}.${DOMAIN}"
            echo "    Port: ${POCKETBASE_PORTS[pb_i]}"
        done
    else
        echo "PocketBase Backend:"
        echo "  Subdomain: ${POCKETBASE_SUBDOMAIN}.${DOMAIN}"
        echo "  Port: ${POCKETBASE_PORT}"
    fi
fi

echo ""
read -p "Does this look correct? (y/n): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo_error "Setup cancelled by user"
    exit 1
fi

echo_step "🚀 Setting up Multi-Project VPS Environment"
echo "Domain: $DOMAIN"
echo "Projects: ${PROJECTS[@]}"
echo "Subdomains: ${SUBDOMAINS[@]}"
echo "Ports: ${PORTS[@]}"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo_error "This script should not be run as root."
   exit 1
fi

# Step 1: Install Prerequisites
echo_step "📦 Installing Prerequisites"

# Update system
echo_info "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Node.js 18
if ! command -v node &> /dev/null; then
    echo_info "Installing Node.js 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo_info "Node.js is already installed ($(node --version))"
fi

# Install PM2
if ! command -v pm2 &> /dev/null; then
    echo_info "Installing PM2..."
    sudo npm install -g pm2
else
    echo_info "PM2 is already installed ($(pm2 --version))"
fi

# Install Nginx
if ! command -v nginx &> /dev/null; then
    echo_info "Installing Nginx..."
    sudo apt install nginx -y
else
    echo_info "Nginx is already installed"
fi

# Install certbot
if ! command -v certbot &> /dev/null; then
    echo_info "Installing Certbot..."
    sudo apt install certbot python3-certbot-nginx -y
else
    echo_info "Certbot is already installed"
fi

# Install additional tools
sudo apt install -y htop curl wget git

# Step 2: Create Directory Structure
echo_step "📁 Creating Directory Structure"

# Create directories for all projects dynamically
PROJECT_DIRS="/var/www/pm2"
for project in "${PROJECTS[@]}"; do
    PROJECT_DIRS="$PROJECT_DIRS /var/www/$project"
done

sudo mkdir -p $PROJECT_DIRS
sudo chown -R $USER:$USER /var/www/

echo_info "Directory structure created:"
tree /var/www/ 2>/dev/null || ls -la /var/www/

# Step 3: Create PM2 Ecosystem Configuration
echo_step "⚙️ Creating PM2 Configuration"

# Generate PM2 ecosystem configuration dynamically
cat > /var/www/pm2/ecosystem.config.js << EOF
module.exports = {
  apps: [
$(for ((i=0; i<${#PROJECTS[@]}; i++)); do
    project="${PROJECTS[i]}"
    port="${PORTS[i]}"
    cat << APPEOF
    {
      name: '$project',
      script: '/var/www/$project/build/index.js',
      cwd: '/var/www/$project',
      instances: 1,
      exec_mode: 'fork',
      env_production: {
        NODE_ENV: 'production',
        PORT: $port,
        HOSTNAME: '0.0.0.0'
      },
      max_memory_restart: '400M',
      error_file: '/var/www/$project/logs/error.log',
      out_file: '/var/www/$project/logs/out.log',
      log_file: '/var/www/$project/logs/combined.log',
      time: true
    }$([ $i -lt $((${#PROJECTS[@]} - 1)) ] && echo ",")
APPEOF
done)
  ]
};
EOF

echo_info "PM2 ecosystem configuration created"

# Step 4: Create Nginx Configuration
echo_step "🌐 Creating Nginx Configuration"

# Generate Nginx configuration dynamically
sudo tee /etc/nginx/sites-available/multi-projects > /dev/null << EOF
# Rate limiting
limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;

# Upstream definitions
$(for ((i=0; i<${#PROJECTS[@]}; i++)); do
    project="${PROJECTS[i]}"
    port="${PORTS[i]}"
    echo "upstream $project {"
    echo "    server 127.0.0.1:$port;"
    echo "    keepalive 2;"
    echo "}"
    echo ""
done)

# HTTP Servers (will be updated by certbot for HTTPS)
$(for ((i=0; i<${#PROJECTS[@]}; i++)); do
    project="${PROJECTS[i]}"
    subdomain="${SUBDOMAINS[i]}"
    cat << SERVEREOF
server {
    listen 80;
    server_name $([ -z "$subdomain" ] && echo "$DOMAIN" || echo "$subdomain.$DOMAIN");
    
    location / {
        limit_req zone=api burst=10 nodelay;
        proxy_pass http://$project;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Optimize for low resource usage
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}

SERVEREOF
done)

$(if [[ $DEPLOY_POCKETBASE =~ ^[Yy]$ ]]; then
    if [[ $MULTI_POCKETBASE =~ ^[Yy]$ ]]; then
        # Multiple PocketBase instances
        for ((pb_i=0; pb_i<${#POCKETBASE_NAMES[@]}; pb_i++)); do
            pb_name="${POCKETBASE_NAMES[pb_i]}"
            pb_subdomain="${POCKETBASE_SUBDOMAINS[pb_i]}"
            pb_port="${POCKETBASE_PORTS[pb_i]}"
            cat << MULTIPBEOF

# Upstream for PocketBase instance: $pb_name
upstream pocketbase-$pb_name {
    server 127.0.0.1:$pb_port;
    keepalive 2;
}

# Server block for $pb_name
server {
    listen 80;
    server_name $pb_subdomain.$DOMAIN;
    
    # Increase client max body size for file uploads
    client_max_body_size 100M;
    
    location / {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://pocketbase-$pb_name;
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
        proxy_pass http://pocketbase-$pb_name;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
MULTIPBEOF
        done
    else
        # Single PocketBase instance
        cat << PBEOF

# Upstream for PocketBase
upstream pocketbase {
    server 127.0.0.1:$POCKETBASE_PORT;
    keepalive 2;
}

# PocketBase server block
server {
    listen 80;
    server_name $POCKETBASE_SUBDOMAIN.$DOMAIN;
    
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

PBEOF
    fi
fi)
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/multi-projects /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
if sudo nginx -t; then
    echo_info "Nginx configuration is valid"
    echo_info "Stopping Bitnami Apache..."
    if [ -f "/opt/bitnami/ctlscript.sh" ]; then
        sudo /opt/bitnami/ctlscript.sh stop apache || echo_warn "Failed to stop Apache, it might not be running"
        echo_info "Disabling Bitnami Apache from starting on boot..."
        sudo mv /opt/bitnami/apache/scripts/ctl.sh /opt/bitnami/apache/scripts/ctl.sh.disabled 2>/dev/null || echo_warn "Failed to disable Apache, it might already be disabled"
    fi
    echo_info "Starting Nginx service..."
    sudo systemctl start nginx
    sudo systemctl reload nginx
else
    echo_error "Nginx configuration has errors!"
    exit 1
fi

# Step 5: Create Deployment Helper Scripts
echo_step "📜 Creating Helper Scripts"

# Create deployment script for individual projects
cat > /var/www/deploy-project.sh << 'EOF'
#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ $# -eq 0 ]; then
    echo_error "Usage: $0 <project-name> [git-repo-url] [branch-name]"
    echo "Examples:"
    echo "  $0 portfolio https://github.com/user/portfolio.git"
    echo "  $0 portfolio https://github.com/user/portfolio.git main"
    echo "  $0 portfolio  # Just redeploy existing project"
    exit 1
fi

PROJECT_NAME=$1
REPO_URL=$2
BRANCH_NAME=$3
PROJECT_PATH="/var/www/$PROJECT_NAME"

echo_info "🚀 Deploying $PROJECT_NAME..."

# Create project directory if it doesn't exist
if [ ! -d "$PROJECT_PATH" ]; then
    echo_info "📁 Creating project directory: $PROJECT_PATH"
    mkdir -p "$PROJECT_PATH"
fi

cd "$PROJECT_PATH" || {
    echo_error "❌ Failed to access project directory: $PROJECT_PATH"
    exit 1
}

# Handle Git operations
if [ -n "$REPO_URL" ]; then
    if [ -d ".git" ]; then
        echo_info "📥 Pulling latest changes from repository..."
        
        # Fetch all branches to get the latest refs
        if ! git fetch origin; then
            echo_error "❌ Failed to fetch from remote repository"
            exit 1
        fi
        
        # Determine which branch to use
        if [ -n "$BRANCH_NAME" ]; then
            # Use specified branch
            CURRENT_BRANCH="$BRANCH_NAME"
        else
            # Auto-detect default branch if not specified
            CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
            if [ "$CURRENT_BRANCH" = "HEAD" ]; then
                # Detached HEAD, try to get default branch from remote
                CURRENT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
            fi
        fi
        
        echo_info "🌿 Using branch: $CURRENT_BRANCH"
        
        # Check if branch exists on remote
        if ! git ls-remote --exit-code --heads origin "$CURRENT_BRANCH" >/dev/null 2>&1; then
            echo_error "❌ Branch '$CURRENT_BRANCH' does not exist on remote repository"
            echo_error "Available branches:"
            git ls-remote --heads origin | sed 's@^.*refs/heads/@@' | sed 's/^/  - /'
            exit 1
        fi
        
        # Switch to the branch and pull
        if ! git checkout "$CURRENT_BRANCH"; then
            echo_error "❌ Failed to checkout branch: $CURRENT_BRANCH"
            exit 1
        fi
        
        if ! git pull origin "$CURRENT_BRANCH"; then
            echo_error "❌ Failed to pull changes from branch: $CURRENT_BRANCH"
            exit 1
        fi
        
    else
        echo_info "📦 Cloning repository..."
        
        # Clone with specific branch if provided
        if [ -n "$BRANCH_NAME" ]; then
            if ! git clone -b "$BRANCH_NAME" "$REPO_URL" .; then
                echo_error "❌ Failed to clone repository with branch: $BRANCH_NAME"
                echo_error "Check if the branch exists and repository URL is correct"
                exit 1
            fi
        else
            if ! git clone "$REPO_URL" .; then
                echo_error "❌ Failed to clone repository: $REPO_URL"
                echo_error "Check if the repository URL is correct and accessible"
                exit 1
            fi
        fi
        
        # Show which branch we're on
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        echo_info "🌿 Cloned on branch: $CURRENT_BRANCH"
    fi
else
    echo_info "📝 No repository URL provided, using existing code..."
    if [ ! -d ".git" ]; then
        echo_warn "⚠️  No Git repository found in $PROJECT_PATH"
    fi
fi

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo_error "❌ No package.json found in project directory"
    echo_error "Make sure this is a valid Node.js project"
    exit 1
fi

echo_info "📦 Installing dependencies..."
if ! npm install --production --silent; then
    echo_error "❌ Failed to install dependencies"
    exit 1
fi

echo_info "🔨 Building project..."
if ! npm run build; then
    echo_error "❌ Build failed"
    echo_error "Check your build configuration and try again"
    exit 1
fi

# Check if build directory exists
if [ ! -d "build" ]; then
    echo_error "❌ Build directory not found after build"
    echo_error "Make sure your build script creates a 'build' directory"
    exit 1
fi

# Create logs directory
mkdir -p logs

# Create environment file if it doesn't exist
if [ ! -f ".env.production" ]; then
    echo_info "📄 Creating default .env.production file..."
    cat > .env.production << ENVEOF
NODE_ENV=production
PORT=300$(($(echo "$PROJECT_NAME" | wc -c) % 3 + 1))
HOSTNAME=0.0.0.0
ENVEOF
    echo_warn "⚠️  Please update .env.production with your actual environment variables"
fi

echo_info "🔄 Managing PM2 process..."
# Try to restart existing process, or it will be started by ecosystem
if pm2 describe "$PROJECT_NAME" >/dev/null 2>&1; then
    echo_info "♻️  Restarting existing PM2 process..."
    pm2 restart "$PROJECT_NAME"
else
    echo_info "🆕 Process will be started with PM2 ecosystem"
fi

echo_info "✅ $PROJECT_NAME deployed successfully!"
echo_info "🌐 Access your project at: http://\$PROJECT_NAME.$DOMAIN (adjust subdomain as needed)"
echo_info "📊 Monitor with: pm2 logs $PROJECT_NAME"
EOF

chmod +x /var/www/deploy-project.sh

# Create deployment script for all projects
cat > /var/www/deploy-all.sh << EOF
#!/bin/bash

echo "Deploying all projects..."

PROJECTS=($(printf '"%s" ' "${PROJECTS[@]}"))

for project in "\${PROJECTS[@]}"; do
    echo "========================"
    echo "Deploying \$project..."
    echo "========================"
    
    /var/www/deploy-project.sh "\$project"
    
    if [ \$? -eq 0 ]; then
        echo "✅ \$project deployed successfully"
    else
        echo "❌ \$project deployment failed"
    fi
    echo ""
done

echo "Starting all processes with PM2..."
cd /var/www/pm2
pm2 start ecosystem.config.js --env production

echo "PM2 Status:"
pm2 status
EOF

chmod +x /var/www/deploy-all.sh

# Step 6: Setup Memory Optimization
echo_step "🔧 Optimizing Memory Usage"

# Create swap file if not exists and system has less than 2GB RAM
TOTAL_RAM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
if [ "$TOTAL_RAM" -lt 2048 ] && [ ! -f /swapfile ]; then
    echo_info "Creating 2GB swap file for better memory management..."
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo_info "Swap file created successfully"
fi

# Step 7: Setup Firewall
echo_step "🔒 Configuring Firewall"

if command -v ufw &> /dev/null; then
    sudo ufw allow 22/tcp  # SSH
    sudo ufw allow 80/tcp  # HTTP
    sudo ufw allow 443/tcp # HTTPS
    sudo ufw --force enable
    echo_info "Firewall configured"
fi

# Step 8: Setup PM2 Startup
echo_step "🔄 Setting up PM2 Auto-start"

pm2 startup | tail -1 | sudo bash
echo_info "PM2 startup configured"

# Step 8.5: Deploy PocketBase if requested
if [[ $DEPLOY_POCKETBASE =~ ^[Yy]$ ]]; then
    echo_step "🎒 Deploying PocketBase"
    
    if [[ $MULTI_POCKETBASE =~ ^[Yy]$ ]]; then
        # Deploy multiple PocketBase instances
        for ((pb_i=0; pb_i<${#POCKETBASE_NAMES[@]}; pb_i++)); do
            pb_name="${POCKETBASE_NAMES[pb_i]}"
            pb_port="${POCKETBASE_PORTS[pb_i]}"
            
            echo_info "Setting up PocketBase instance: $pb_name"
            
            # Create directories for this instance
            sudo mkdir -p "/var/www/pocketbase-$pb_name"/{data,logs,backups}
            sudo chown -R $USER:$USER "/var/www/pocketbase-$pb_name"
        done
    else
        # Create PocketBase directory and setup (single instance)
        sudo mkdir -p /var/www/pocketbase/{data,logs,backups}
        sudo chown -R $USER:$USER /var/www/pocketbase
    fi
    
    # Download and install PocketBase
    echo_info "Downloading PocketBase..."
    cd /tmp
    POCKETBASE_VERSION=$(curl -s https://api.github.com/repos/pocketbase/pocketbase/releases/latest | grep -Po '"tag_name": "v\K[^"]*' 2>/dev/null || echo "0.22.0")
    
    ARCH=$(uname -m)
    if [[ $ARCH == "x86_64" ]]; then
        POCKETBASE_ARCH="amd64"
    elif [[ $ARCH == "aarch64" ]] || [[ $ARCH == "arm64" ]]; then
        POCKETBASE_ARCH="arm64"
    else
        echo_warn "Unknown architecture: $ARCH, defaulting to amd64"
        POCKETBASE_ARCH="amd64"
    fi
    
    DOWNLOAD_URL="https://github.com/pocketbase/pocketbase/releases/download/v${POCKETBASE_VERSION}/pocketbase_${POCKETBASE_VERSION}_linux_${POCKETBASE_ARCH}.zip"
    
    if wget -q "$DOWNLOAD_URL" -O pocketbase.zip; then
        unzip -q pocketbase.zip
        chmod +x pocketbase
        echo_info "PocketBase $POCKETBASE_VERSION downloaded successfully"
        
        if [[ $MULTI_POCKETBASE =~ ^[Yy]$ ]]; then
            # Copy to each instance directory
            for ((pb_i=0; pb_i<${#POCKETBASE_NAMES[@]}; pb_i++)); do
                pb_name="${POCKETBASE_NAMES[pb_i]}"
                cp pocketbase "/var/www/pocketbase-$pb_name/"
                echo_info "PocketBase binary copied to $pb_name instance"
            done
            rm pocketbase
        else
            # Single instance
            sudo mv pocketbase /var/www/pocketbase/
            sudo chmod +x /var/www/pocketbase/pocketbase
        fi
        rm pocketbase.zip
    else
        echo_warn "Failed to download PocketBase, skipping..."
    fi
    
    if [[ $MULTI_POCKETBASE =~ ^[Yy]$ ]]; then
        # Create systemd services for multiple instances
        for ((pb_i=0; pb_i<${#POCKETBASE_NAMES[@]}; pb_i++)); do
            pb_name="${POCKETBASE_NAMES[pb_i]}"
            pb_port="${POCKETBASE_PORTS[pb_i]}"
            
            sudo tee "/etc/systemd/system/pocketbase-$pb_name.service" > /dev/null << EOF
[Unit]
Description=PocketBase Backend Service - $pb_name
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=5
User=$USER
WorkingDirectory=/var/www/pocketbase-$pb_name
Environment=PB_DATA_DIR=/var/www/pocketbase-$pb_name/data
ExecStart=/var/www/pocketbase-$pb_name/pocketbase serve --http=127.0.0.1:$pb_port --dir=/var/www/pocketbase-$pb_name/data
StandardOutput=append:/var/www/pocketbase-$pb_name/logs/pocketbase.log
StandardError=append:/var/www/pocketbase-$pb_name/logs/error.log

[Install]
WantedBy=multi-user.target
EOF
        done
    else
        # Create systemd service for single PocketBase
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
ExecStart=/var/www/pocketbase/pocketbase serve --http=127.0.0.1:$POCKETBASE_PORT --dir=/var/www/pocketbase/data
StandardOutput=append:/var/www/pocketbase/logs/pocketbase.log
StandardError=append:/var/www/pocketbase/logs/error.log

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    # Create PocketBase management script
    cat > /var/www/pocketbase/manage.sh << 'PBMANAGE'
#!/bin/bash

case "$1" in
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
        BACKUP_NAME="pocketbase-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        tar -czf "/var/www/pocketbase/backups/$BACKUP_NAME" -C /var/www/pocketbase/data .
        echo "Backup created: /var/www/pocketbase/backups/$BACKUP_NAME"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|backup}"
        exit 1
        ;;
esac
PBMANAGE
    
    chmod +x /var/www/pocketbase/manage.sh
    
    # Enable and start PocketBase service
    sudo systemctl daemon-reload
    sudo systemctl enable pocketbase
    sudo systemctl start pocketbase
    
    echo_info "PocketBase service started"
fi

# Step 9: Create monitoring script
cat > /var/www/monitor.sh << EOF
#!/bin/bash

echo "=== System Resources ==="
free -h
echo ""

echo "=== PM2 Status ==="
pm2 status
echo ""

echo "=== Nginx Status ==="
sudo systemctl status nginx --no-pager -l
echo ""

echo "=== Disk Usage ==="
df -h /var/www
echo ""

$(for project in "${PROJECTS[@]}"; do
    echo "echo \"=== Recent Errors ($project) ===\""
    echo "tail -n 5 /var/www/$project/logs/error.log 2>/dev/null || echo \"No error logs found for $project\""
    echo "echo \"\""
done)
EOF

chmod +x /var/www/monitor.sh

# Final Steps
echo_step "✅ Setup Complete!"

echo ""
echo "=================================================="
echo "🎉 Multi-Project VPS Setup Completed Successfully!"
echo "=================================================="
echo ""
echo "📁 Directory Structure:"
for ((i=0; i<${#PROJECTS[@]}; i++)); do
    project="${PROJECTS[i]}"
    subdomain="${SUBDOMAINS[i]}"
    echo "   /var/www/$project/     - ${subdomain}.${DOMAIN}"
done
if [[ $DEPLOY_POCKETBASE =~ ^[Yy]$ ]]; then
    echo "   /var/www/pocketbase/    - ${POCKETBASE_SUBDOMAIN}.${DOMAIN}"
fi
echo "   /var/www/pm2/           - PM2 configuration"
echo ""
echo "🔗 Your Domains:"
for ((i=0; i<${#PROJECTS[@]}; i++)); do
    project="${PROJECTS[i]}"
    subdomain="${SUBDOMAINS[i]}"
    if [ -z "$subdomain" ]; then
        echo "   http://${DOMAIN}  - ${project^} (Main Domain)"
    else
        echo "   http://${subdomain}.${DOMAIN}  - ${project^}"
    fi
done
if [[ $DEPLOY_POCKETBASE =~ ^[Yy]$ ]]; then
    echo "   http://${POCKETBASE_SUBDOMAIN}.${DOMAIN}  - PocketBase Backend"
    echo "   http://${POCKETBASE_SUBDOMAIN}.${DOMAIN}/_/  - PocketBase Admin"
fi
echo ""
echo "📜 Available Scripts:"
echo "   /var/www/deploy-project.sh <name> [repo-url] - Deploy single project"
echo "   /var/www/deploy-all.sh                       - Deploy all projects"
echo "   /var/www/monitor.sh                          - System monitoring"
if [[ $DEPLOY_POCKETBASE =~ ^[Yy]$ ]]; then
    echo "   /var/www/pocketbase/manage.sh                - Manage PocketBase"
fi
echo ""
echo "⚡ Next Steps:"
echo "1. Deploy your first project:"
echo "   /var/www/deploy-project.sh ${PROJECTS[0]} https://github.com/user/${PROJECTS[0]}.git"
echo ""
echo "2. Set up SSL certificates:"
CERT_DOMAINS=""
for ((i=0; i<${#PROJECTS[@]}; i++)); do
    subdomain="${SUBDOMAINS[i]}"
    if [ -z "$subdomain" ]; then
        CERT_DOMAINS="$CERT_DOMAINS -d ${DOMAIN}"
    else
        CERT_DOMAINS="$CERT_DOMAINS -d ${subdomain}.${DOMAIN}"
    fi
done
echo "   sudo certbot --nginx$CERT_DOMAINS"
echo ""
echo "3. Monitor your applications:"
echo "   pm2 monit"
echo "   /var/www/monitor.sh"
echo ""
echo "💡 Tips:"
PORTS_STRING=""
for port in "${PORTS[@]}"; do
    PORTS_STRING="$PORTS_STRING$port, "
done
if [[ $DEPLOY_POCKETBASE =~ ^[Yy]$ ]]; then
    PORTS_STRING="$PORTS_STRING$POCKETBASE_PORT, "
fi
PORTS_STRING=${PORTS_STRING%, }
echo "- Projects run on ports: $PORTS_STRING"
echo "- PM2 manages Node.js processes automatically"
if [[ $DEPLOY_POCKETBASE =~ ^[Yy]$ ]]; then
    echo "- PocketBase runs as systemd service"
fi
echo "- Nginx handles SSL and routing"
ESTIMATED_RAM=$((${#PROJECTS[@]} * 200 + 200))
if [[ $DEPLOY_POCKETBASE =~ ^[Yy]$ ]]; then
    ESTIMATED_RAM=$((ESTIMATED_RAM + 100))
fi
echo "- Total estimated RAM usage: ~${ESTIMATED_RAM}MB"
echo ""
echo "🆘 Troubleshooting:"
echo "- Check logs: pm2 logs <project-name>"
echo "- Restart all: pm2 restart all"
echo "- Monitor resources: htop or /var/www/monitor.sh"
echo ""
echo_info "Happy deploying! 🚀"