# Deploying PocketBase on Ubuntu VPS with Nginx

This guide provides step-by-step instructions for deploying PocketBase alongside your SvelteKit application on an Ubuntu VPS with Nginx as a reverse proxy.

## Prerequisites
- An Ubuntu VPS (20.04 LTS or later)
- A domain/subdomain pointing to your VPS IP address (pb.mayankjoshi.in)
- SSH access to your VPS
- Root or sudo privileges
- Nginx already installed and configured (from SvelteKit deployment)

## Step 1: Create Directory for PocketBase

```bash
# Create directory for PocketBase
sudo mkdir -p /var/www/pocketbase

# Navigate to the directory
cd /var/www/pocketbase
```

## Step 2: Download and Install PocketBase

```bash
# Download the latest version of PocketBase for Linux
# Download using wget instead of curl (more reliable for binary files)
wget https://github.com/pocketbase/pocketbase/releases/download/v0.22.6/pocketbase_0.22.6_linux_amd64.zip -O pocketbase.zip

# Verify the download was successful
ls -l pocketbase.zip

# Then try unzipping
unzip pocketbase.zip

# Remove the zip file
rm pocketbase.zip

# Make PocketBase executable
chmod +x ./pocketbase
```

## Step 3: Create a Systemd Service for PocketBase

```bash
# Create a systemd service file for PocketBase
sudo nano /etc/systemd/system/pocketbase.service
```

Add the following content:

```ini
[Unit]
Description=PocketBase service
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/pocketbase
ExecStart=/var/www/pocketbase/pocketbase serve --http="127.0.0.1:8090"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

## Step 4: Configure Nginx for PocketBase

Create a new Nginx server block for PocketBase:

```bash
# Create Nginx configuration file for PocketBase
sudo nano /etc/nginx/sites-available/pb.mayankjoshi.in
```

Add this configuration:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name pb.mayankjoshi.in;

    location / {
        proxy_pass http://127.0.0.1:8090;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        
        # Additional headers for WebSocket support
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Increase timeouts for long-running requests
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }

    # Important for Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        allow all;
        root /var/www/html;
    }
}
```

## Step 5: Enable the Configuration and Set Permissions

```bash
# Create symbolic link to enable the site
sudo ln -s /etc/nginx/sites-available/pb.mayankjoshi.in /etc/nginx/sites-enabled/

# Set proper ownership
sudo chown -R www-data:www-data /var/www/pocketbase

# Set proper permissions
sudo chmod -R 755 /var/www/pocketbase

# Test Nginx configuration
sudo nginx -t

# Reload Nginx if test is successful
sudo systemctl reload nginx
```

## Step 6: Start PocketBase Service

```bash
# Reload systemd daemon to recognize new service
sudo systemctl daemon-reload

# Start PocketBase service
sudo systemctl start pocketbase

# Enable PocketBase to start on boot
sudo systemctl enable pocketbase

# Check status
sudo systemctl status pocketbase
```

## Step 7: Set Up SSL with Let's Encrypt

```bash
# Request SSL certificate for PocketBase subdomain
sudo certbot --nginx -d pb.mayankjoshi.in

# Verify automatic renewal
sudo systemctl status certbot.timer
```

## Step 8: Initial PocketBase Setup

1. Access the admin UI at `https://pb.mayankjoshi.in/_/`
2. Create your admin account
3. Configure your application settings

## Important Notes

### Security Considerations
1. The PocketBase admin UI is accessible at `/_/`
2. Consider setting up additional security measures:
   - Configure firewall rules
   - Set up rate limiting
   - Regularly backup your PocketBase data

### Backup Strategy
```bash
# Create backup directory
sudo mkdir -p /var/backups/pocketbase

# Set up daily backups (add to crontab)
sudo crontab -e
```

Add this line to crontab:
```
0 0 * * * tar -czf /var/backups/pocketbase/pb_backup_$(date +\%Y\%m\%d).tar.gz /var/www/pocketbase/pb_data/
```

### Updating PocketBase

```bash
# Stop the service
sudo systemctl stop pocketbase

# Backup current data
sudo cp -r /var/www/pocketbase/pb_data /var/www/pocketbase/pb_data_backup

# Download and replace the binary
cd /var/www/pocketbase
sudo curl -o pocketbase.zip -L https://github.com/pocketbase/pocketbase/releases/latest/download/pocketbase_linux_amd64.zip
sudo unzip -o pocketbase.zip
sudo rm pocketbase.zip
sudo chmod +x ./pocketbase

# Restart the service
sudo systemctl start pocketbase
```

## Troubleshooting

### Common Issues

1. Service Won't Start
   ```bash
   # Check service status
   sudo systemctl status pocketbase
   
   # Check logs
   sudo journalctl -u pocketbase -f
   ```

2. Nginx 502 Bad Gateway
   ```bash
   # Check if PocketBase is running
   sudo systemctl status pocketbase
   
   # Check Nginx error logs
   sudo tail -f /var/log/nginx/error.log
   ```

3. Permission Issues
   ```bash
   # Fix permissions
   sudo chown -R www-data:www-data /var/www/pocketbase
   sudo chmod -R 755 /var/www/pocketbase
   ```

## Maintenance

### Regular Updates
1. Keep your system updated
2. Regularly update PocketBase to the latest version
3. Monitor disk space usage
4. Check and rotate logs
5. Verify backup integrity

### Monitoring
1. Check service status regularly
2. Monitor system resources
3. Set up alerts for service disruptions
4. Review access logs periodically

## Integration with SvelteKit

To connect your SvelteKit application with PocketBase, update your environment variables:

```env
POCKETBASE_URL=https://pb.mayankjoshi.in
```

Remember to:
1. Keep your PocketBase instance updated
2. Regularly backup your data
3. Monitor system resources
4. Review security settings periodically
5. Keep your SSL certificates up to date 