# Complete Usage Guide - VPS Deployment Scripts

This guide provides detailed instructions for using all VPS deployment scripts with every option and configuration choice explained.

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Script 1: setup-multi-projects.sh](#script-1-setup-multi-projectssh)
3. [Script 2: setup-pocketbase.sh](#script-2-setup-pocketbasesh)
4. [Script 3: setup-multi-pocketbase.sh](#script-3-setup-multi-pocketbasesh)
5. [Post-Deployment Management](#post-deployment-management)
6. [Configuration Examples](#configuration-examples)
7. [Troubleshooting Guide](#troubleshooting-guide)

## 🚀 Quick Start

### Prerequisites Checklist
- [ ] Ubuntu/Debian VPS with sudo access
- [ ] Domain name pointed to your VPS IP
- [ ] SSH access to your VPS
- [ ] At least 1GB RAM (2GB+ recommended)
- [ ] Ports 80, 443 open in firewall

### Initial Setup
```bash
# 1. Download scripts to your VPS
git clone <repository-url>
cd vps-deployment-helpers

# 2. Make scripts executable
chmod +x *.sh

# 3. Choose your deployment method:
# Option A: Complete setup with projects + PocketBase
./setup-multi-projects.sh

# Option B: Only PocketBase (single instance)
./setup-pocketbase.sh

# Option C: Multiple PocketBase instances only
./setup-multi-pocketbase.sh
```

---

## Script 1: `setup-multi-projects.sh`

**Purpose**: Complete VPS setup for multiple Node.js projects with optional PocketBase integration.

### Step-by-Step Walkthrough

#### Step 1: Domain Configuration
```
Enter your domain name (e.g., example.com): 
```
**What to enter**: Your root domain without `www` or `https://`
- ✅ Good: `mycompany.com`, `myapp.dev`, `example.org`
- ❌ Bad: `www.mycompany.com`, `https://mycompany.com`, `mycompany.com/`

#### Step 2: Number of Projects
```
How many projects do you want to deploy? (1-10):
```
**What to enter**: Number between 1-10
- Enter `1` for single project
- Enter `3` for typical setup (frontend, admin, api)
- Enter `5+` for complex multi-project setup

#### Step 3: Project Configuration (Repeated for each project)

For each project, you'll be asked:

##### Project Name
```
Project 1 name (e.g., portfolio, blog):
```
**What to enter**: Alphanumeric name with hyphens/underscores
- ✅ Good: `frontend`, `admin-panel`, `blog`, `api-server`
- ❌ Bad: `my project`, `frontend!`, `app@2024`

##### Subdomain
```
Subdomain for frontend (will create frontend.mycompany.com):
```
**What to enter**: Subdomain prefix (auto-suggests project name)
- ✅ Good: `app`, `admin`, `blog`, `api`, `dashboard`
- ❌ Bad: `my-app.subdomain`, `app.com`

**Result**: Creates `subdomain.yourdomain.com`

##### Port
```
Port for frontend (default: 3001):
```
**What to enter**: Port number 1024-65535 (or press Enter for default)
- Default ports: 3001, 3002, 3003, etc.
- Custom ports: `3000`, `8080`, `4000`, etc.
- Script checks for conflicts automatically

#### Step 4: PocketBase Integration Choice
```
Would you like to also deploy PocketBase as your backend? (y/n):
```

**Option A: No PocketBase (n)**
- Skips to final confirmation
- Only deploys Node.js projects

**Option B: Yes PocketBase (y)**
Continues to PocketBase configuration...

##### Single vs Multiple PocketBase
```
Do you want multiple PocketBase instances? (y/n):
```

**Option B1: Single PocketBase (n)**
```
Enter subdomain for PocketBase (e.g., 'api' for api.mycompany.com):
Port for PocketBase (default: 8090):
```

**Option B2: Multiple PocketBase (y)**
```
How many PocketBase instances? (1-5):
```

For each PocketBase instance:
```
Instance 1 name (e.g., main-api, auth, blog-backend):
Subdomain for main-api (e.g., 'api' for api.mycompany.com):
Port for main-api (default: 8090):
```

#### Step 5: Final Confirmation
```
Configuration Summary:
Domain: mycompany.com
Number of projects: 2

Project 1: frontend
  Subdomain: app.mycompany.com
  Port: 3001

Project 2: admin
  Subdomain: admin.mycompany.com
  Port: 3002

PocketBase Backend:
  Subdomain: api.mycompany.com
  Port: 8090

Does this look correct? (y/n):
```

**What happens next**:
- System package updates
- Node.js 18 installation
- PM2 installation
- Nginx configuration
- SSL certificate setup
- Service startup

---

## Script 2: `setup-pocketbase.sh`

**Purpose**: Deploy a single PocketBase instance with full configuration.

### Step-by-Step Walkthrough

#### Step 1: Domain
```
Enter your domain name (e.g., example.com):
```
Same as multi-projects script.

#### Step 2: Subdomain
```
Enter subdomain for PocketBase (e.g., 'api' for api.example.com):
```
**Common choices**:
- `api` → `api.yourdomain.com`
- `backend` → `backend.yourdomain.com`
- `db` → `db.yourdomain.com`
- `pocketbase` → `pocketbase.yourdomain.com`

#### Step 3: Port
```
Port for PocketBase (default: 8090):
```
**Port suggestions**:
- `8090` (default, recommended)
- `8080`, `8000`, `3000` (alternatives)

#### Step 4: Admin Email (Optional)
```
Admin email for initial setup (optional, press Enter to skip):
```
**What to enter**:
- Your email for SSL certificates: `admin@yourdomain.com`
- Press Enter to skip (you'll set admin during first login)

#### Step 5: Confirmation
```
Configuration Summary:
Domain: yourdomain.com
PocketBase URL: https://api.yourdomain.com
Port: 8090
Admin Email: admin@yourdomain.com

Does this look correct? (y/n):
```

**What happens next**:
- Latest PocketBase download
- Systemd service creation
- Nginx reverse proxy setup
- SSL certificate installation
- Service startup

**Access after deployment**:
- **API**: `https://api.yourdomain.com`
- **Admin Panel**: `https://api.yourdomain.com/_/`

---

## Script 3: `setup-multi-pocketbase.sh`

**Purpose**: Deploy multiple PocketBase instances for different use cases.

### Step-by-Step Walkthrough

#### Step 1: Domain
```
Enter your domain name (e.g., example.com):
```
Same as other scripts.

#### Step 2: Number of Instances
```
How many PocketBase instances do you want to deploy? (1-10):
```
**Common scenarios**:
- `2-3` for dev/staging/prod
- `3-5` for microservices
- `5+` for multi-tenant apps

#### Step 3: Instance Configuration (Repeated for each)

##### Instance Name
```
Instance 1 name (e.g., main-api, blog-backend, auth):
```
**Naming conventions**:
- **By function**: `auth`, `users`, `orders`, `analytics`
- **By environment**: `dev`, `staging`, `prod`
- **By tenant**: `tenant1`, `tenant2`, `acme-corp`
- **By project**: `blog-api`, `shop-api`, `portfolio-api`

##### Subdomain
```
Subdomain for auth (will create auth.yourdomain.com):
```
**Subdomain examples**:
- Function-based: `auth`, `users`, `orders`, `files`
- Environment: `dev-api`, `staging-api`, `api`
- Tenant: `tenant1`, `tenant2`, `acme`
- Project: `blog`, `shop`, `portfolio`

##### Port
```
Port for auth (default: 8090):
```
**Port assignment**:
- Instance 1: `8090` (default)
- Instance 2: `8091` (default)
- Instance 3: `8092` (default)
- Custom: Any available port 1024-65535

##### Description (Optional)
```
Description for auth (optional):
```
**Examples**:
- `Authentication and user management service`
- `Blog content management backend`
- `Development environment database`

#### Step 4: Admin Email
```
Admin email for SSL certificates (optional, press Enter to skip):
```
Used for Let's Encrypt SSL certificates.

#### Step 5: Final Confirmation
```
Configuration Summary:
Domain: yourdomain.com
Number of PocketBase instances: 3

Instance 1: auth
  URL: https://auth.yourdomain.com
  Port: 8090
  Description: Authentication service

Instance 2: users
  URL: https://users.yourdomain.com
  Port: 8091
  Description: User management

Instance 3: orders
  URL: https://orders.yourdomain.com
  Port: 8092
  Description: Order processing

Does this look correct? (y/n):
```

**What happens next**:
- PocketBase download
- Multiple directory creation
- Individual systemd services
- Nginx configuration for all instances
- SSL certificates for all domains
- All services startup

---

## 📁 Post-Deployment Management

### Directory Structure After Deployment

```
/var/www/
├── project1/                     # Node.js project directories
│   ├── build/                   # Built application
│   ├── logs/                    # Application logs
│   └── node_modules/            # Dependencies
├── project2/
├── pocketbase/                   # Single PocketBase (if deployed)
│   ├── data/                    # SQLite database
│   ├── logs/                    # PocketBase logs
│   ├── backups/                 # Backup files
│   └── manage.sh               # Management script
├── pocketbase-auth/              # Multi PocketBase instance 1
├── pocketbase-users/             # Multi PocketBase instance 2
├── pm2/                          # PM2 configuration
│   └── ecosystem.config.js      # PM2 app definitions
├── deploy-project.sh             # Project deployment script
├── deploy-all.sh                # Deploy all projects
├── monitor.sh                   # System monitoring
└── manage-all-pocketbase.sh     # Multi-PocketBase management
```

### Management Commands

#### Node.js Projects
```bash
# Deploy/redeploy single project
/var/www/deploy-project.sh project-name
/var/www/deploy-project.sh project-name https://github.com/user/repo.git
/var/www/deploy-project.sh project-name https://github.com/user/repo.git main

# Deploy all projects
/var/www/deploy-all.sh

# PM2 management
pm2 status                    # View all processes
pm2 logs project-name         # View logs
pm2 restart project-name      # Restart specific project
pm2 restart all              # Restart all projects
pm2 stop project-name        # Stop specific project
pm2 delete project-name      # Remove from PM2
```

#### Single PocketBase
```bash
# Service management
sudo systemctl start pocketbase
sudo systemctl stop pocketbase
sudo systemctl restart pocketbase
sudo systemctl status pocketbase

# Custom management script
/var/www/pocketbase/manage.sh start
/var/www/pocketbase/manage.sh stop
/var/www/pocketbase/manage.sh restart
/var/www/pocketbase/manage.sh status
/var/www/pocketbase/manage.sh logs
/var/www/pocketbase/manage.sh backup
/var/www/pocketbase/manage.sh update
```

#### Multiple PocketBase Instances
```bash
# Global management (all instances)
/var/www/manage-all-pocketbase.sh status
/var/www/manage-all-pocketbase.sh start
/var/www/manage-all-pocketbase.sh stop
/var/www/manage-all-pocketbase.sh restart
/var/www/manage-all-pocketbase.sh logs
/var/www/manage-all-pocketbase.sh backup
/var/www/manage-all-pocketbase.sh update
/var/www/manage-all-pocketbase.sh list

# Target specific instance
/var/www/manage-all-pocketbase.sh start auth
/var/www/manage-all-pocketbase.sh logs users
/var/www/manage-all-pocketbase.sh backup orders

# Individual instance management
/var/www/pocketbase-auth/manage.sh status
/var/www/pocketbase-users/manage.sh logs
/var/www/pocketbase-orders/manage.sh backup
```

#### System Monitoring
```bash
# Overall system status
/var/www/monitor.sh

# Service status
sudo systemctl status nginx
sudo systemctl status pocketbase*
pm2 monit

# Log monitoring
sudo journalctl -u pocketbase -f        # Single instance
sudo journalctl -u pocketbase-auth -f   # Specific multi-instance
sudo tail -f /var/log/nginx/error.log   # Nginx errors
```

---

## 🎯 Configuration Examples

### Example 1: E-commerce Setup
```bash
./setup-multi-projects.sh

# Configuration:
Domain: mystore.com
Projects: 3
  1. frontend (app.mystore.com:3001)
  2. admin (admin.mystore.com:3002)  
  3. mobile-api (mobile.mystore.com:3003)
PocketBase: Single (api.mystore.com:8090)
```

**Result**:
- `https://app.mystore.com` - Customer frontend
- `https://admin.mystore.com` - Admin dashboard
- `https://mobile.mystore.com` - Mobile app API
- `https://api.mystore.com` - Backend database
- `https://api.mystore.com/_/` - Admin panel

### Example 2: Multi-Tenant SaaS
```bash
./setup-multi-pocketbase.sh

# Configuration:
Domain: myapp.com
Instances: 4
  1. shared (api.myapp.com:8090) - Shared services
  2. tenant1 (tenant1.myapp.com:8091) - Customer A
  3. tenant2 (tenant2.myapp.com:8092) - Customer B
  4. analytics (analytics.myapp.com:8093) - Analytics
```

**Result**:
- Each tenant has isolated database
- Shared services for common functionality
- Separate analytics instance
- Individual admin panels per tenant

### Example 3: Development Environment
```bash
./setup-multi-projects.sh

# Configuration:
Domain: myproject.dev
Projects: 3
  1. app-dev (dev.myproject.dev:3001)
  2. app-staging (staging.myproject.dev:3002)
  3. app-prod (myproject.dev:3003)
PocketBase: Multiple
  1. dev-db (dev-api.myproject.dev:8090)
  2. staging-db (staging-api.myproject.dev:8091)
  3. prod-db (api.myproject.dev:8092)
```

**Result**:
- Complete isolation between environments
- Separate databases for each environment
- Easy environment-specific testing

### Example 4: Microservices Architecture
```bash
./setup-multi-pocketbase.sh

# Configuration:
Domain: microservices.com
Instances: 5
  1. auth (auth.microservices.com:8090)
  2. users (users.microservices.com:8091)
  3. orders (orders.microservices.com:8092)
  4. payments (payments.microservices.com:8093)
  5. notifications (notify.microservices.com:8094)
```

**Result**:
- Each service has dedicated database
- Service-specific admin panels
- Independent scaling and management

---

## 🔧 Advanced Configuration

### Environment Variables
You can set environment variables to skip prompts:

```bash
# Pre-configure domain
export DOMAIN="mycompany.com"
./setup-multi-projects.sh

# Skip confirmations (use defaults)
export SKIP_CONFIRMATION="true"
./setup-pocketbase.sh
```

### Custom Ports
When prompted for ports, consider:

- **Node.js apps**: 3000-3999 range
- **PocketBase**: 8000-8999 range
- **Avoid**: 22 (SSH), 80 (HTTP), 443 (HTTPS), 25 (SMTP)

### SSL Certificate Management
```bash
# View all certificates
sudo certbot certificates

# Renew certificates
sudo certbot renew

# Add new domain to existing certificate
sudo certbot --nginx -d new.yourdomain.com

# Test renewal
sudo certbot renew --dry-run
```

### Backup Configuration
```bash
# Setup automatic backups for PocketBase
crontab -e

# Add lines for each instance:
0 2 * * * /var/www/pocketbase/backup-cron.sh
0 3 * * * /var/www/pocketbase-auth/backup-cron.sh
0 4 * * * /var/www/pocketbase-users/backup-cron.sh

# Backup retention (automatically keeps 7 days)
# Modify backup-cron.sh to change retention:
# find "$BACKUP_DIR" -name "pocketbase-*-auto-backup-*" -mtime +30 -delete
```

---

## 🚨 Troubleshooting Guide

### Common Issues and Solutions

#### 1. Domain Not Pointing to VPS
**Problem**: `ping yourdomain.com` doesn't return your VPS IP

**Solution**:
```bash
# Check current DNS
dig yourdomain.com

# Update DNS records:
# A record: yourdomain.com → YOUR_VPS_IP
# A record: *.yourdomain.com → YOUR_VPS_IP (for subdomains)
```

#### 2. Port Already in Use
**Problem**: `Port 3001 appears to be in use`

**Solution**:
```bash
# Check what's using the port
sudo netstat -tulpn | grep :3001
sudo lsof -i :3001

# Kill process or choose different port
sudo kill -9 PID
```

#### 3. SSL Certificate Failed
**Problem**: Certbot fails to create certificates

**Solutions**:
```bash
# Check if domain resolves to your server
ping subdomain.yourdomain.com

# Manual certificate creation
sudo certbot --nginx -d subdomain.yourdomain.com

# Check nginx configuration
sudo nginx -t

# Verify firewall allows HTTP/HTTPS
sudo ufw status
sudo ufw allow 80
sudo ufw allow 443
```

#### 4. Service Won't Start
**Problem**: PocketBase or PM2 service fails

**Solutions**:
```bash
# Check service status
sudo systemctl status pocketbase
sudo systemctl status pocketbase-auth

# View detailed logs
sudo journalctl -u pocketbase -f
sudo journalctl -u pocketbase-auth -f

# Check file permissions
ls -la /var/www/pocketbase/
sudo chown -R $USER:$USER /var/www/pocketbase/

# Restart services
sudo systemctl restart pocketbase
pm2 restart all
```

#### 5. Out of Memory
**Problem**: VPS runs out of memory

**Solutions**:
```bash
# Check memory usage
free -h
htop

# Add swap space
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Reduce PM2 instances
pm2 scale app-name 1

# Restart services to free memory
pm2 restart all
sudo systemctl restart pocketbase*
```

#### 6. Can't Access Admin Panel
**Problem**: PocketBase admin panel returns 404

**Solutions**:
```bash
# Check if service is running
sudo systemctl status pocketbase

# Verify nginx configuration
sudo nginx -t
sudo systemctl reload nginx

# Check logs
sudo journalctl -u pocketbase -f

# Try direct port access (if firewall allows)
curl http://localhost:8090/_/
```

#### 7. Project Deployment Fails
**Problem**: `/var/www/deploy-project.sh` fails

**Solutions**:
```bash
# Check if git repository is accessible
git clone https://github.com/user/repo.git /tmp/test

# Verify Node.js and npm
node --version
npm --version

# Check project directory permissions
ls -la /var/www/project-name/

# Manual deployment steps
cd /var/www/project-name
git pull origin main
npm install
npm run build
pm2 restart project-name
```

### Log Locations
```bash
# System logs
sudo journalctl -u nginx -f
sudo journalctl -u pocketbase* -f

# Application logs
/var/www/pocketbase/logs/pocketbase.log
/var/www/pocketbase/logs/error.log
/var/www/project-name/logs/

# PM2 logs
pm2 logs
pm2 logs project-name

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Performance Optimization
```bash
# Monitor resource usage
htop
iotop
/var/www/monitor.sh

# Optimize PM2 memory usage
pm2 start ecosystem.config.js --max-memory-restart 200M

# Restart services weekly (add to cron)
0 2 * * 0 pm2 restart all
0 3 * * 0 sudo systemctl restart pocketbase*
```

---

## 🔄 Migration and Backup

### Complete Backup
```bash
# Create full backup
sudo tar -czf /tmp/vps-backup-$(date +%Y%m%d).tar.gz \
  /var/www/ \
  /etc/nginx/sites-available/ \
  /etc/systemd/system/pocketbase*.service

# Download backup to local machine
scp user@vps:/tmp/vps-backup-*.tar.gz ./
```

### Restore on New VPS
```bash
# 1. Upload backup to new VPS
scp vps-backup-*.tar.gz user@new-vps:/tmp/

# 2. Extract backup
sudo tar -xzf /tmp/vps-backup-*.tar.gz -C /

# 3. Run scripts on new VPS to install dependencies
./setup-multi-projects.sh  # Choose same configuration

# 4. Restore services
sudo systemctl daemon-reload
sudo systemctl enable pocketbase*
sudo systemctl start pocketbase*
pm2 resurrect
```

---

**🎉 You're now ready to deploy and manage your VPS with confidence!**

For additional help, check the main [README.md](README.md) or create an issue with your specific configuration and error logs. 