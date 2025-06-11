# Multi-Project VPS Deployment Guide (Resource Optimized)

## Overview
Deploy multiple projects (project1.mayankjoshi.in, project2.mayankjoshi.in, etc.) on a single 2 vCPU VPS using PM2 and one Nginx instance.

## Resource Comparison

### Docker Method (Heavy)
- **Memory**: ~512MB per project container + ~200MB for Nginx container
- **CPU**: Docker daemon overhead + container isolation overhead
- **Disk**: ~300MB per project image
- **Total for 3 projects**: ~2.5GB RAM, high CPU overhead

### PM2 Method (Lightweight)
- **Memory**: ~150MB per project process + ~50MB for single Nginx
- **CPU**: Minimal overhead, direct process execution
- **Disk**: ~100MB per built project
- **Total for 3 projects**: ~500MB RAM, minimal CPU overhead

## Directory Structure
```
/var/www/
├── portfolio/                 # project1.mayankjoshi.in
├── blog/                     # project2.mayankjoshi.in  
├── dashboard/                # project3.mayankjoshi.in
├── nginx/
│   └── sites-available/
└── pm2/
    └── ecosystem.config.js
```

## Step-by-Step Setup

### 1. VPS Preparation
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 globally
sudo npm install -g pm2

# Install Nginx
sudo apt install nginx -y

# Install certbot for SSL
sudo apt install certbot python3-certbot-nginx -y

# Create directory structure
sudo mkdir -p /var/www/{portfolio,blog,dashboard}
sudo chown -R $USER:$USER /var/www/
```

### 2. Deploy Each Project

#### For Portfolio Project (project1.mayankjoshi.in)
```bash
# Clone and build portfolio
cd /var/www/portfolio
git clone <your-portfolio-repo> .
npm install
npm run build

# Create .env file
cat > .env.production << EOF
NODE_ENV=production
PORT=3001
VITE_POCKETBASE_URL=https://awspb.mayankjoshi.in
VITE_MASTER_BUILDER_EMAIL=your-email@example.com
VITE_MASTER_BUILDER_PASSWORD=your-password
EOF
```

#### For Other Projects
```bash
# Example for project2 (blog)
cd /var/www/blog
git clone <your-blog-repo> .
npm install
npm run build

# Create .env file with different port
cat > .env.production << EOF
NODE_ENV=production
PORT=3002  # Different port for each project
EOF
```

### 3. Single PM2 Configuration for All Projects
Create `/var/www/pm2/ecosystem.config.js`:

```javascript
module.exports = {
  apps: [
    {
      name: 'portfolio',
      script: '/var/www/portfolio/build/index.js',
      cwd: '/var/www/portfolio',
      instances: 1,  // Use only 1 instance per project on 2 vCPU
      exec_mode: 'fork',  // Use fork mode instead of cluster
      env_production: {
        NODE_ENV: 'production',
        PORT: 3001,
        HOSTNAME: '0.0.0.0'
      },
      max_memory_restart: '400M',  // Limit memory per process
      error_file: '/var/www/portfolio/logs/error.log',
      out_file: '/var/www/portfolio/logs/out.log',
      log_file: '/var/www/portfolio/logs/combined.log'
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
      log_file: '/var/www/blog/logs/combined.log'
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
      log_file: '/var/www/dashboard/logs/combined.log'
    }
  ]
};
```

### 4. Single Nginx Configuration for All Subdomains
Create `/etc/nginx/sites-available/multi-projects`:

```nginx
# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

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

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name project1.mayankjoshi.in project2.mayankjoshi.in project3.mayankjoshi.in;
    return 301 https://$server_name$request_uri;
}

# Portfolio - project1.mayankjoshi.in
server {
    listen 443 ssl http2;
    server_name project1.mayankjoshi.in;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/project1.mayankjoshi.in/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/project1.mayankjoshi.in/privkey.pem;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    # Gzip compression
    gzip on;
    gzip_types text/css application/javascript application/json;
    
    location / {
        limit_req zone=api burst=10 nodelay;
        proxy_pass http://portfolio;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Optimize for low resource usage
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}

# Blog - project2.mayankjoshi.in
server {
    listen 443 ssl http2;
    server_name project2.mayankjoshi.in;
    
    ssl_certificate /etc/letsencrypt/live/project2.mayankjoshi.in/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/project2.mayankjoshi.in/privkey.pem;
    
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    gzip on;
    gzip_types text/css application/javascript application/json;
    
    location / {
        limit_req zone=api burst=10 nodelay;
        proxy_pass http://blog;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}

# Dashboard - project3.mayankjoshi.in
server {
    listen 443 ssl http2;
    server_name project3.mayankjoshi.in;
    
    ssl_certificate /etc/letsencrypt/live/project3.mayankjoshi.in/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/project3.mayankjoshi.in/privkey.pem;
    
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    gzip on;
    gzip_types text/css application/javascript application/json;
    
    location / {
        limit_req zone=api burst=10 nodelay;
        proxy_pass http://dashboard;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
```

### 5. Start All Projects
```bash
# Create log directories
mkdir -p /var/www/{portfolio,blog,dashboard}/logs

# Start all projects with PM2
cd /var/www/pm2
pm2 start ecosystem.config.js --env production

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup

# Enable Nginx site
sudo ln -s /etc/nginx/sites-available/multi-projects /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 6. SSL Setup for All Subdomains
```bash
# Get SSL certificates for all subdomains
sudo certbot --nginx -d project1.mayankjoshi.in
sudo certbot --nginx -d project2.mayankjoshi.in
sudo certbot --nginx -d project3.mayankjoshi.in

# Or get them all at once (if supported)
sudo certbot --nginx -d project1.mayankjoshi.in -d project2.mayankjoshi.in -d project3.mayankjoshi.in
```

## Resource Optimization Tips

### 1. Memory Optimization
```bash
# Add swap file if needed (2GB)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 2. Node.js Optimization
```javascript
// In each project's package.json, add memory limit
{
  "scripts": {
    "start": "NODE_OPTIONS='--max-old-space-size=300' node build"
  }
}
```

### 3. PM2 Memory Monitoring
```bash
# Monitor memory usage
pm2 monit

# Restart processes that use too much memory
pm2 restart all
```

## Deployment Script for Updates
Create `/var/www/deploy-all.sh`:

```bash
#!/bin/bash

deploy_project() {
    local project_name=$1
    local project_path="/var/www/$project_name"
    
    echo "Deploying $project_name..."
    cd $project_path
    
    # Pull latest changes
    git pull origin main
    
    # Install dependencies and build
    npm install --production
    npm run build
    
    # Restart PM2 process
    pm2 restart $project_name
    
    echo "$project_name deployed successfully!"
}

# Deploy all projects
deploy_project "portfolio"
deploy_project "blog" 
deploy_project "dashboard"

# Show status
pm2 status
```

## Monitoring Commands
```bash
# Check all processes
pm2 status

# View logs for specific project
pm2 logs portfolio

# Monitor resources
pm2 monit

# Check Nginx status
sudo systemctl status nginx

# Check memory usage
free -h
htop
```

## Estimated Resource Usage
- **Total RAM**: ~800MB (including OS overhead)
- **CPU**: Minimal overhead, efficient process management
- **Disk**: ~500MB for all projects combined
- **Network**: Single Nginx instance handles all traffic

This setup is perfect for your 2 vCPU VPS and will handle multiple projects efficiently! 