# VPS Deployment Helper Scripts

A collection of bash scripts to easily deploy and manage multiple projects and PocketBase instances on a VPS with automatic SSL, Nginx configuration, and process management.

## 🚀 Features

- **Multi-Project Support**: Deploy multiple Node.js projects on subdomains
- **PocketBase Integration**: Deploy single or multiple PocketBase instances
- **Automatic SSL**: Let's Encrypt SSL certificates with auto-renewal
- **Process Management**: PM2 for Node.js apps, systemd for PocketBase
- **Nginx Configuration**: Automatic reverse proxy setup
- **Resource Optimization**: Memory-efficient configuration for low-resource VPS
- **Backup Systems**: Automated backup scripts for PocketBase
- **Management Tools**: Easy-to-use scripts for common operations

## 📋 Prerequisites

- Ubuntu/Debian VPS with sudo access
- Domain name pointed to your VPS
- At least 1GB RAM recommended
- Ports 80, 443, and your chosen application ports open

## 🛠 Available Scripts

### 1. `setup-multi-projects.sh` - Main Setup Script
Complete VPS setup with multiple Node.js projects and optional PocketBase integration.

**Features:**
- Interactive project configuration
- Dynamic port assignment
- PM2 process management
- Nginx reverse proxy
- SSL certificate setup
- Optional single/multiple PocketBase instances

**Usage:**
```bash
./setup-multi-projects.sh
```

**Example Flow:**
1. Enter domain: `mycompany.com`
2. Number of projects: `3`
3. Configure each project (name, subdomain, port)
4. Choose PocketBase integration
5. Automatic deployment and SSL setup

### 2. `setup-pocketbase.sh` - Standalone PocketBase
Deploy a single PocketBase instance with full configuration.

**Features:**
- Latest PocketBase version auto-detection
- Systemd service configuration
- Nginx reverse proxy
- SSL certificate
- Management scripts
- Backup automation

**Usage:**
```bash
./setup-pocketbase.sh
```

### 3. `setup-multi-pocketbase.sh` - Multiple PocketBase Instances
Deploy multiple PocketBase instances for different use cases.

**Features:**
- Up to 10 PocketBase instances
- Individual configuration per instance
- Separate databases and admin panels
- Global management script
- Bulk operations support

**Usage:**
```bash
./setup-multi-pocketbase.sh
```

**Use Cases:**
- Multi-tenant applications
- Separate backends for different projects
- Development/staging/production environments
- Microservices architecture

## 🏗 Architecture

### Directory Structure
```
/var/www/
├── project1/                 # Node.js project 1
├── project2/                 # Node.js project 2
├── pocketbase/               # Single PocketBase instance
├── pocketbase-api/           # Multi PocketBase instance 1
├── pocketbase-auth/          # Multi PocketBase instance 2
├── pm2/                      # PM2 configuration
├── deploy-project.sh         # Single project deployment
├── deploy-all.sh            # Deploy all projects
├── monitor.sh               # System monitoring
└── manage-all-pocketbase.sh  # Multi-PocketBase management
```

### Service Management
- **Node.js Apps**: Managed by PM2 with auto-restart
- **PocketBase**: Managed by systemd services
- **Nginx**: Reverse proxy with SSL termination
- **SSL**: Let's Encrypt with auto-renewal

## 📖 Usage Examples

### Scenario 1: E-commerce Setup
```bash
# Run main setup script
./setup-multi-projects.sh

# Configuration:
Domain: mystore.com
Projects:
  - frontend (app.mystore.com:3001)
  - admin (admin.mystore.com:3002)
PocketBase: api.mystore.com:8090
```

### Scenario 2: Multi-Tenant SaaS
```bash
# Deploy multiple PocketBase instances
./setup-multi-pocketbase.sh

# Configuration:
Domain: myapp.com
Instances:
  - tenant1 (tenant1.myapp.com:8090)
  - tenant2 (tenant2.myapp.com:8091)
  - shared (api.myapp.com:8092)
```

### Scenario 3: Development Environment
```bash
# Multiple environments
./setup-multi-projects.sh

# Configuration:
Domain: myproject.dev
Projects:
  - app-dev (dev.myproject.dev:3001)
  - app-staging (staging.myproject.dev:3002)
  - app-prod (myproject.dev:3003)
PocketBase: Multiple instances for each environment
```

## 🔧 Management Commands

### Project Management
```bash
# Deploy single project
/var/www/deploy-project.sh portfolio https://github.com/user/portfolio.git

# Deploy all projects
/var/www/deploy-all.sh

# Monitor system
/var/www/monitor.sh

# PM2 operations
pm2 status
pm2 logs project-name
pm2 restart project-name
```

### PocketBase Management

#### Single Instance
```bash
# Start/stop/restart
sudo systemctl start pocketbase
sudo systemctl status pocketbase

# Custom management
/var/www/pocketbase/manage.sh {start|stop|restart|status|logs|backup|update}
```

#### Multiple Instances
```bash
# Global management
/var/www/manage-all-pocketbase.sh status
/var/www/manage-all-pocketbase.sh restart api
/var/www/manage-all-pocketbase.sh backup

# Individual instance
/var/www/pocketbase-api/manage.sh logs
/var/www/pocketbase-auth/manage.sh backup
```

## 🔒 Security Features

- **Non-root execution**: All services run as regular user
- **Firewall configuration**: UFW rules for HTTP/HTTPS only
- **SSL/TLS**: Automatic certificate management
- **Rate limiting**: Nginx rate limiting for API protection
- **Process isolation**: Separate systemd services
- **File permissions**: Proper ownership and permissions

## 📊 Monitoring & Maintenance

### System Monitoring
```bash
# Overall system status
/var/www/monitor.sh

# Service status
sudo systemctl status nginx
sudo systemctl status pocketbase-*
pm2 status

# Logs
sudo journalctl -u pocketbase-api -f
pm2 logs project-name
sudo tail -f /var/log/nginx/error.log
```

### Backup Management
```bash
# Manual backup
/var/www/pocketbase/manage.sh backup

# Setup automatic backups
crontab -e
# Add: 0 2 * * * /var/www/pocketbase/backup-cron.sh
```

### Updates
```bash
# Update PocketBase
/var/www/pocketbase/manage.sh update

# Update Node.js projects
/var/www/deploy-project.sh project-name

# Update system
sudo apt update && sudo apt upgrade
```

## 🚨 Troubleshooting

### Common Issues

#### Port Conflicts
```bash
# Check port usage
netstat -tulpn | grep :PORT

# Modify port in service configuration
sudo systemctl edit pocketbase-instance
```

#### SSL Certificate Issues
```bash
# Manual certificate setup
sudo certbot --nginx -d subdomain.domain.com

# Check certificate status
sudo certbot certificates
```

#### Service Not Starting
```bash
# Check service logs
sudo journalctl -u service-name -f

# Check configuration
sudo nginx -t
```

#### Memory Issues
```bash
# Check memory usage
free -h
htop

# Restart services to free memory
pm2 restart all
sudo systemctl restart pocketbase-*
```

### Log Locations
- **Nginx**: `/var/log/nginx/`
- **PocketBase**: `/var/www/pocketbase-*/logs/`
- **PM2**: Managed by PM2, use `pm2 logs`
- **System**: `sudo journalctl -u service-name`

## 🔄 Migration & Scaling

### Moving to Larger VPS
1. Backup all data directories
2. Export PM2 configuration: `pm2 save`
3. Transfer files to new server
4. Run setup scripts on new server
5. Import PM2 configuration: `pm2 resurrect`

### Adding More Instances
1. Run individual setup scripts
2. Update Nginx configuration
3. Add SSL certificates
4. Update monitoring scripts

## 📝 Configuration Files

### Key Configuration Locations
- **Nginx**: `/etc/nginx/sites-available/multi-projects`
- **PM2**: `/var/www/pm2/ecosystem.config.js`
- **PocketBase Services**: `/etc/systemd/system/pocketbase*.service`
- **Environment**: `/var/www/*/.*env*`

### Customization
All scripts support customization through interactive prompts. For advanced users, environment variables can be pre-set:

```bash
export DOMAIN="mycompany.com"
export SKIP_CONFIRMATION="true"
./setup-multi-projects.sh
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Test on clean VPS
4. Submit pull request

## 📄 License

MIT License - Feel free to use and modify for your projects.

## 🆘 Support

For issues and questions:
1. Check troubleshooting section
2. Review service logs
3. Open an issue with:
   - OS version
   - Script output
   - Error logs
   - Configuration used

---

**Happy Deploying! 🚀** 