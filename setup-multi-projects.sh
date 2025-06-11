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

# Configuration
DOMAIN="mayankjoshi.in"
PROJECTS=("portfolio" "blog" "dashboard")
SUBDOMAINS=("project1" "project2" "project3")
PORTS=(3001 3002 3003)

echo_step "🚀 Setting up Multi-Project VPS Environment"
echo "Domain: $DOMAIN"
echo "Projects: ${PROJECTS[@]}"
echo "Subdomains: ${SUBDOMAINS[@]}"
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

sudo mkdir -p /var/www/{portfolio,blog,dashboard,pm2}
sudo chown -R $USER:$USER /var/www/

echo_info "Directory structure created:"
tree /var/www/ 2>/dev/null || ls -la /var/www/

# Step 3: Create PM2 Ecosystem Configuration
echo_step "⚙️ Creating PM2 Configuration"

cat > /var/www/pm2/ecosystem.config.js << 'EOF'
module.exports = {
  apps: [
    {
      name: 'portfolio',
      script: '/var/www/portfolio/build/index.js',
      cwd: '/var/www/portfolio',
      instances: 1,
      exec_mode: 'fork',
      env_production: {
        NODE_ENV: 'production',
        PORT: 3001,
        HOSTNAME: '0.0.0.0'
      },
      max_memory_restart: '400M',
      error_file: '/var/www/portfolio/logs/error.log',
      out_file: '/var/www/portfolio/logs/out.log',
      log_file: '/var/www/portfolio/logs/combined.log',
      time: true
    },
    {
      name: 'blog',
      script: '/var/www/blog/build/index.js',
      cwd: '/var/www/blog',
      instances: 1,
      exec_mode: 'fork',
      env_production: {
        NODE_ENV: 'production',
        PORT: 3002,
        HOSTNAME: '0.0.0.0'
      },
      max_memory_restart: '300M',
      error_file: '/var/www/blog/logs/error.log',
      out_file: '/var/www/blog/logs/out.log',
      log_file: '/var/www/blog/logs/combined.log',
      time: true
    },
    {
      name: 'dashboard',
      script: '/var/www/dashboard/build/index.js',
      cwd: '/var/www/dashboard',
      instances: 1,
      exec_mode: 'fork',
      env_production: {
        NODE_ENV: 'production',
        PORT: 3003,
        HOSTNAME: '0.0.0.0'
      },
      max_memory_restart: '300M',
      error_file: '/var/www/dashboard/logs/error.log',
      out_file: '/var/www/dashboard/logs/out.log',
      log_file: '/var/www/dashboard/logs/combined.log',
      time: true
    }
  ]
};
EOF

echo_info "PM2 ecosystem configuration created"

# Step 4: Create Nginx Configuration
echo_step "🌐 Creating Nginx Configuration"

sudo tee /etc/nginx/sites-available/multi-projects > /dev/null << EOF
# Rate limiting
limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;

# Upstream definitions
upstream portfolio {
    server 127.0.0.1:3001;
    keepalive 2;
}

upstream blog {
    server 127.0.0.1:3002;
    keepalive 2;
}

upstream dashboard {
    server 127.0.0.1:3003;
    keepalive 2;
}

# HTTP Server (will be updated by certbot for HTTPS)
server {
    listen 80;
    server_name project1.$DOMAIN;
    
    location / {
        limit_req zone=api burst=10 nodelay;
        proxy_pass http://portfolio;
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

server {
    listen 80;
    server_name project2.$DOMAIN;
    
    location / {
        limit_req zone=api burst=10 nodelay;
        proxy_pass http://blog;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}

server {
    listen 80;
    server_name project3.$DOMAIN;
    
    location / {
        limit_req zone=api burst=10 nodelay;
        proxy_pass http://dashboard;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/multi-projects /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
if sudo nginx -t; then
    echo_info "Nginx configuration is valid"
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
echo_info "🌐 Access your project at: http://project1.mayankjoshi.in (adjust subdomain as needed)"
echo_info "📊 Monitor with: pm2 logs $PROJECT_NAME"
EOF

chmod +x /var/www/deploy-project.sh

# Create deployment script for all projects
cat > /var/www/deploy-all.sh << 'EOF'
#!/bin/bash

echo "Deploying all projects..."

PROJECTS=("portfolio" "blog" "dashboard")

for project in "${PROJECTS[@]}"; do
    echo "========================"
    echo "Deploying $project..."
    echo "========================"
    
    /var/www/deploy-project.sh "$project"
    
    if [ $? -eq 0 ]; then
        echo "✅ $project deployed successfully"
    else
        echo "❌ $project deployment failed"
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

# Step 9: Create monitoring script
cat > /var/www/monitor.sh << 'EOF'
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

echo "=== Recent Errors (Portfolio) ==="
tail -n 5 /var/www/portfolio/logs/error.log 2>/dev/null || echo "No error logs found"
echo ""
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
echo "   /var/www/portfolio/     - Project 1 (project1.$DOMAIN)"
echo "   /var/www/blog/          - Project 2 (project2.$DOMAIN)"
echo "   /var/www/dashboard/     - Project 3 (project3.$DOMAIN)"
echo "   /var/www/pm2/           - PM2 configuration"
echo ""
echo "🔗 Your Subdomains:"
echo "   http://project1.$DOMAIN  - Portfolio"
echo "   http://project2.$DOMAIN  - Blog"
echo "   http://project3.$DOMAIN  - Dashboard"
echo ""
echo "📜 Available Scripts:"
echo "   /var/www/deploy-project.sh <name> [repo-url] - Deploy single project"
echo "   /var/www/deploy-all.sh                       - Deploy all projects"
echo "   /var/www/monitor.sh                          - System monitoring"
echo ""
echo "⚡ Next Steps:"
echo "1. Deploy your first project:"
echo "   /var/www/deploy-project.sh portfolio https://github.com/user/portfolio.git"
echo ""
echo "2. Set up SSL certificates:"
echo "   sudo certbot --nginx -d project1.$DOMAIN -d project2.$DOMAIN -d project3.$DOMAIN"
echo ""
echo "3. Monitor your applications:"
echo "   pm2 monit"
echo "   /var/www/monitor.sh"
echo ""
echo "💡 Tips:"
echo "- Each project runs on ports 3001, 3002, 3003"
echo "- PM2 manages all processes automatically"
echo "- Nginx handles SSL and routing"
echo "- Total estimated RAM usage: ~800MB"
echo ""
echo "🆘 Troubleshooting:"
echo "- Check logs: pm2 logs <project-name>"
echo "- Restart all: pm2 restart all"
echo "- Monitor resources: htop or /var/www/monitor.sh"
echo ""
echo_info "Happy deploying! 🚀"