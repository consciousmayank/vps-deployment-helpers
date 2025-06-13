# Deploying SvelteKit on Ubuntu VPS with Nginx

This guide provides step-by-step instructions for deploying a SvelteKit application on an Ubuntu VPS with Nginx as a reverse proxy.

## Prerequisites
- An Ubuntu VPS (20.04 LTS or later)  # Ubuntu LTS versions provide long-term stability and security updates
- A domain name pointing to your VPS IP address  # Required for accessing your website via a domain name
- SSH access to your VPS  # Secure shell access for remote server management
- Root or sudo privileges  # Administrative rights needed for system configuration
- sudo apt-get update and sudo apt-get install ufw

## Step 1: Initial Server Setup

```bash
# Update the package index to get the latest list of available packages
sudo apt update

# Upgrade all installed packages to their latest versions for security and stability
sudo apt upgrade -y  # -y flag automatically answers "yes" to prompts

# Install essential build tools and utilities:
# curl: Command-line tool for making HTTP requests
# git: Version control system for code management
# build-essential: Package containing compilation tools like gcc, make, etc.
sudo apt install -y curl git build-essential
```

## Step 2: Install Node.js and npm

```bash
# Download and execute the NodeSource setup script for Node.js 20.x LTS
# This adds the official Node.js repository to your system
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

# Install Node.js and npm from the added repository
# This installs both the Node.js runtime and npm package manager
sudo apt install -y nodejs

# Verify the installations by checking versions
# This confirms both tools are properly installed
node --version  # Should show v20.x.x
npm --version   # Should show 8.x.x or higher
```



### NOTE:- There may be a case that I am using aws vps. so 
```bash
# Stop the Bitnami Apache service:
sudo /opt/bitnami/ctlscript.sh stop apache

# If you want to permanently disable Apache from Bitnami stack:
sudo mv /opt/bitnami/apache/scripts/ctl.sh /opt/bitnami/apache/scripts/ctl.sh.disabled

# You can also stop all Bitnami services and restart only the ones you need:
# Stop all Bitnami services
sudo /opt/bitnami/ctlscript.sh stop

# Start specific services you need (if any)
sudo /opt/bitnami/ctlscript.sh start nginx  # if you want to use Nginx

```
## Step 3: Install Nginx

```bash
# Install the Nginx web server
sudo apt install -y nginx

# Start the Nginx service immediately
sudo systemctl start nginx

# Enable Nginx to start automatically on system boot
sudo systemctl enable nginx

# Verify Nginx is running properly
# This shows the current status, any errors, and recent log entries
sudo systemctl status nginx
```



## Step 4: Configure Firewall

```bash
# Allow both HTTP (80) and HTTPS (443) traffic through the firewall
# 'Nginx Full' profile includes both ports
sudo ufw allow 'Nginx Full'

# Allow SSH connections (port 22) to maintain remote access
sudo ufw allow OpenSSH

# Enable the firewall with the new rules
# WARNING: Ensure SSH is allowed before enabling to prevent lockout
sudo ufw enable
```

## Step 5: Prepare Your SvelteKit Application

```bash
# Create the web root directory
# -p flag creates parent directories if they don't exist
sudo mkdir -p /var/www/your-domain

# Navigate to the web root directory
cd /var/www/your-domain

# Clone your SvelteKit application repository
# The '.' at the end clones into the current directory
sudo git clone your-repository-url .

# Install all project dependencies defined in package.json
npm install

# Build the SvelteKit application for production
# This creates optimized static files in the build directory
npm run build
```

## Step 6: Install PM2 Process Manager

```bash
# Install PM2 globally using npm
# PM2 is a production process manager for Node.js applications
sudo npm install -g pm2

# Start your SvelteKit application using PM2
# --name flag gives your process a recognizable name
# build/index.js is the entry point of your built SvelteKit app
pm2 start build/index.js --name "sveltekit-app"

# Generate and configure PM2 startup script
# This ensures PM2 and your app start on system boot
pm2 startup

# Save the current PM2 process list
# This preserves your process configuration across restarts
pm2 save
```

## Step 7: Configure Nginx

### 7.1: Single Domain Setup
If you're only deploying one domain, create a new Nginx server block:

```bash
# Create/edit the Nginx configuration file for your domain
sudo nano /etc/nginx/sites-available/your-domain
```

Add this configuration:

```nginx
server {
    # Listen on port 80 (HTTP) for both IPv4 and IPv6
    listen 80;
    listen [::]:80;

    # Define server names that this block should respond to
    server_name your-domain.com www.your-domain.com;

    # Set the root directory for static files
    root /var/www/your-domain/build;

    location / {
        # Forward requests to your Node.js application
        proxy_pass http://localhost:3000;

        # Use HTTP/1.1 for proxy connections
        proxy_http_version 1.1;

        # Configure WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';

        # Pass the original host header
        proxy_set_header Host $host;

        # Prevent caching for dynamic content
        proxy_cache_bypass $http_upgrade;
    }
    # Important for Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        allow all;
        root /var/www/html;
    }
}
```

### 7.2: Multiple Subdomains Setup (For Different Branches)

```bash
# Create separate directories for each environment
# This keeps different branches isolated from each other
sudo mkdir -p /var/www/staging.your-domain   # Staging environment
sudo mkdir -p /var/www/dev.your-domain       # Development environment
sudo mkdir -p /var/www/your-domain           # Production environment
```

Create server blocks for each subdomain:

```bash
# Create Nginx configuration files for each environment
sudo nano /etc/nginx/sites-available/your-domain          # Production
sudo nano /etc/nginx/sites-available/staging.your-domain  # Staging
sudo nano /etc/nginx/sites-available/dev.your-domain      # Development
```

Production Configuration (your-domain):
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name your-domain.com www.your-domain.com;  # Main domain names

    root /var/www/your-domain/build;  # Production build directory

    location / {
        proxy_pass http://localhost:3000;  # Production runs on port 3000
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Staging Configuration:
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name staging.your-domain.com;  # Staging subdomain

    root /var/www/staging.your-domain/build;  # Staging build directory

    location / {
        proxy_pass http://localhost:3001;  # Staging runs on port 3001
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Development Configuration:
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name dev.your-domain.com;  # Development subdomain

    root /var/www/dev.your-domain/build;  # Development build directory

    location / {
        proxy_pass http://localhost:3002;  # Development runs on port 3002
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable server blocks:
```bash
# Create symbolic links to enable the Nginx configurations
# This links configurations from sites-available to sites-enabled
sudo ln -s /etc/nginx/sites-available/your-domain /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/staging.your-domain /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/dev.your-domain /etc/nginx/sites-enabled/

# Test the Nginx configuration for syntax errors
sudo nginx -t

# Restart Nginx to apply changes
sudo systemctl restart nginx
```

PM2 Configuration for Multiple Branches:
```bash
# Start production application on port 3000
cd /var/www/your-domain
pm2 start build/index.js --name "prod-app" -- --port 3000

# Start staging application on port 3001
cd /var/www/staging.your-domain
pm2 start build/index.js --name "staging-app" -- --port 3001

# Start development application on port 3002
cd /var/www/dev.your-domain
pm2 start build/index.js --name "dev-app" -- --port 3002

# Save PM2 process list for persistence across reboots
pm2 save
```

DNS Configuration:
```plaintext
# Add these A records in your domain's DNS settings:
staging.your-domain.com → Your VPS IP  # Points staging subdomain to your server
dev.your-domain.com → Your VPS IP      # Points development subdomain to your server
your-domain.com → Your VPS IP          # Points main domain to your server
```

## Step 8: Set Up SSL with Let's Encrypt

```bash
# Install Certbot and its Nginx plugin
# Certbot automates SSL certificate management
sudo apt install -y certbot python3-certbot-nginx

# Request SSL certificates for all domains
# --nginx: Use Nginx plugin
# -d: Specify domains to secure
sudo certbot --nginx -d your-domain.com -d www.your-domain.com -d staging.your-domain.com -d dev.your-domain.com

# Check automatic renewal service status
# Certificates auto-renew every 90 days
sudo systemctl status certbot.timer
```

## Step 9: Set File Permissions

```bash
# Set www-data (Nginx user) as owner of web directories
# This allows Nginx to serve files
sudo chown -R www-data:www-data /var/www/your-domain
sudo chown -R www-data:www-data /var/www/staging.your-domain
sudo chown -R www-data:www-data /var/www/dev.your-domain

# Set directory permissions to 755 (rwxr-xr-x)
# Owner can read/write/execute, others can read/execute
sudo chmod -R 755 /var/www/your-domain
sudo chmod -R 755 /var/www/staging.your-domain
sudo chmod -R 755 /var/www/dev.your-domain
```

## Additional Notes for Multiple Environments

### Deployment Workflow
```bash
# Clone main branch for production
cd /var/www/your-domain
git clone -b main your-repository-url .  # -b specifies the branch

# Clone staging branch
cd /var/www/staging.your-domain
git clone -b staging your-repository-url .

# Clone development branch
cd /var/www/dev.your-domain
git clone -b dev your-repository-url .

# Create environment-specific .env files
# These contain environment-specific variables
nano /var/www/your-domain/.env          # Production environment variables
nano /var/www/staging.your-domain/.env  # Staging environment variables
nano /var/www/dev.your-domain/.env      # Development environment variables

# Example deployment script for staging
cd /var/www/staging.your-domain    # Navigate to staging directory
git pull origin staging            # Pull latest changes from staging branch
npm install                        # Install/update dependencies
npm run build                      # Rebuild the application
pm2 restart staging-app           # Restart the staging PM2 process
```

## Important Notes

1. Replace `your-domain` and `your-domain.com` with your actual domain name
2. The default SvelteKit port is 3000. If you're using a different port, update the Nginx configuration accordingly
3. Make sure your domain's DNS A record points to your VPS IP address
4. The SSL certificate will auto-renew every 90 days

## Troubleshooting

### Check Logs
- Nginx error logs: `sudo tail -f /var/nginx/error.log`
- PM2 logs: `pm2 logs sveltekit-app`

### Common Issues
1. 502 Bad Gateway
   - Check if your Node.js application is running
   - Verify PM2 process status: `pm2 status`
   - Check Node.js application logs: `pm2 logs`

2. Permission Issues
   - Verify file ownership: `ls -la /var/www/your-domain`
   - Fix permissions if needed: `sudo chown -R www-data:www-data /var/www/your-domain`

3. SSL Certificate Issues
   - Check certbot logs: `sudo certbot certificates`
   - Renew certificates manually: `sudo certbot renew --dry-run`

## Maintenance

### Regular Updates
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Node.js dependencies
cd /var/www/your-domain
npm update

# Rebuild application
npm run build

# Restart PM2 process
pm2 restart sveltekit-app

# Check status
pm2 status
```

### Backup Important Files
Regularly backup these files:
- `/etc/nginx/sites-available/your-domain`
- `/etc/letsencrypt/` (SSL certificates)
- Your application code and data

## Security Best Practices

1. Keep your system updated
2. Use strong SSH keys
3. Configure fail2ban
4. Regular security audits
5. Monitor server resources
6. Set up automated backups

## Additional Recommendations

1. Set up monitoring (e.g., UptimeRobot, New Relic)
2. Configure server backups
3. Implement rate limiting in Nginx
4. Set up error pages
5. Configure gzip compression
6. Implement caching strategies

Remember to replace all instances of `your-domain` with your actual domain name throughout this guide.

[Rest of the previous content remains the same...] 