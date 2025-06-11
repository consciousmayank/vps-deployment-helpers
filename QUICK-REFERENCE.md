# 🚀 Quick Reference Card

## 📥 Initial Setup Commands

```bash
# Make scripts executable
chmod +x *.sh

# Main setup (projects + optional PocketBase)
./setup-multi-projects.sh

# Single PocketBase only
./setup-pocketbase.sh

# Multiple PocketBase instances
./setup-multi-pocketbase.sh
```

## 🎯 Common Configuration Choices

### Domain Examples
- ✅ `mycompany.com`
- ✅ `myapp.dev` 
- ✅ `example.org`
- ❌ `www.mycompany.com`
- ❌ `https://mycompany.com`

### Project Names
- ✅ `frontend`, `admin`, `api`
- ✅ `blog-app`, `user_service`
- ❌ `my project`, `app@2024`

### Subdomain Examples
- **Frontend**: `app`, `web`, `www`
- **Admin**: `admin`, `dashboard`, `manage`
- **API**: `api`, `backend`, `server`
- **PocketBase**: `api`, `db`, `backend`, `pocketbase`

### Port Ranges
- **Node.js**: 3000-3999 (default: 3001, 3002, 3003...)
- **PocketBase**: 8000-8999 (default: 8090, 8091, 8092...)
- **Avoid**: 22, 80, 443, 25

## 🛠 Management Commands

### Node.js Projects (PM2)
```bash
pm2 status                    # View all processes
pm2 logs project-name         # View logs
pm2 restart project-name      # Restart project
pm2 stop project-name         # Stop project
pm2 restart all               # Restart all
```

### Single PocketBase
```bash
sudo systemctl status pocketbase
sudo systemctl restart pocketbase
/var/www/pocketbase/manage.sh status
/var/www/pocketbase/manage.sh logs
/var/www/pocketbase/manage.sh backup
```

### Multiple PocketBase
```bash
/var/www/manage-all-pocketbase.sh status
/var/www/manage-all-pocketbase.sh restart
/var/www/manage-all-pocketbase.sh logs instance-name
/var/www/pocketbase-instance/manage.sh backup
```

### System Services
```bash
sudo systemctl status nginx
sudo systemctl reload nginx
sudo nginx -t                 # Test config
```

## 📁 Important Directories

```
/var/www/
├── project-name/             # Node.js projects
├── pocketbase/               # Single PocketBase
├── pocketbase-instance/      # Multi PocketBase
├── deploy-project.sh         # Deploy script
└── monitor.sh               # System monitor
```

## 🔗 Access URLs After Deployment

### Projects
- Frontend: `https://app.yourdomain.com`
- Admin: `https://admin.yourdomain.com`
- API: `https://api.yourdomain.com`

### PocketBase
- API: `https://api.yourdomain.com`
- Admin: `https://api.yourdomain.com/_/`
- Docs: `https://api.yourdomain.com/_/docs`

## 🚨 Quick Troubleshooting

### Service Not Starting
```bash
sudo systemctl status service-name
sudo journalctl -u service-name -f
```

### SSL Issues
```bash
sudo certbot certificates
sudo certbot --nginx -d domain.com
```

### Port Conflicts
```bash
sudo netstat -tulpn | grep :PORT
sudo lsof -i :PORT
```

### Memory Issues
```bash
free -h
htop
pm2 restart all
```

### Nginx Issues
```bash
sudo nginx -t
sudo systemctl reload nginx
sudo tail -f /var/log/nginx/error.log
```

## 📦 Deployment Commands

### Deploy Single Project
```bash
/var/www/deploy-project.sh project-name
/var/www/deploy-project.sh project-name https://github.com/user/repo.git
/var/www/deploy-project.sh project-name https://github.com/user/repo.git main
```

### Deploy All Projects
```bash
/var/www/deploy-all.sh
```

## 🔒 SSL Management
```bash
sudo certbot certificates      # View certificates
sudo certbot renew           # Renew all
sudo certbot --nginx -d new.domain.com  # Add domain
```

## 💾 Backup Commands

### PocketBase Backup
```bash
/var/www/pocketbase/manage.sh backup
/var/www/manage-all-pocketbase.sh backup
```

### System Backup
```bash
sudo tar -czf backup.tar.gz /var/www/ /etc/nginx/sites-available/
```

### Auto Backup Setup
```bash
crontab -e
# Add: 0 2 * * * /var/www/pocketbase/backup-cron.sh
```

## 📊 Monitoring Commands

```bash
/var/www/monitor.sh           # System overview
pm2 monit                     # PM2 monitor
htop                          # Resource usage
sudo systemctl status nginx pocketbase*
```

## 🔧 Configuration Files

- **Nginx**: `/etc/nginx/sites-available/multi-projects`
- **PM2**: `/var/www/pm2/ecosystem.config.js`
- **PocketBase Service**: `/etc/systemd/system/pocketbase*.service`
- **Environment**: `/var/www/project/.env*`

## 📋 Pre-Deployment Checklist

- [ ] Domain DNS points to VPS IP
- [ ] VPS has sudo access
- [ ] Ports 80, 443 open
- [ ] At least 1GB RAM available
- [ ] SSH access working

## 🎯 Example Setups

### E-commerce
```
Domain: mystore.com
- app.mystore.com (frontend)
- admin.mystore.com (admin)
- api.mystore.com (PocketBase)
```

### Multi-tenant SaaS
```
Domain: myapp.com
- tenant1.myapp.com (PocketBase)
- tenant2.myapp.com (PocketBase)
- admin.myapp.com (management)
```

### Development Environment
```
Domain: myproject.dev
- dev.myproject.dev (dev app)
- staging.myproject.dev (staging)
- myproject.dev (production)
```

---

**💡 Pro Tips:**
- Use `screen` or `tmux` for long-running deployments
- Always test with `sudo nginx -t` before reloading
- Keep backups before major changes
- Monitor logs during deployment
- Use meaningful project and instance names 