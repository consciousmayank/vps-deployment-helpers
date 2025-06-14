# Self-Hosting Supabase on a VPS

This guide provides step-by-step instructions for setting up a self-hosted Supabase instance on your VPS.

## Prerequisites

- A VPS with at least 4GB RAM (8GB recommended)
- Ubuntu 20.04 or newer
- Docker and Docker Compose installed
- Domain name pointing to your VPS
- Root or sudo access to your VPS

## Step 1: Install Required Software

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Docker if not already installed
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installations
docker --version
docker-compose --version
```

## Step 2: Set Up Docker Network

```bash
docker network create supabase-network
```

## Step 3: Clone Supabase Docker Repository

```bash
git clone https://github.com/supabase/supabase-docker.git
cd supabase-docker
```

## Step 4: Configure Environment Variables

1. Copy the example environment file:
```bash
cp .env.example .env
```

2. Edit the `.env` file with your settings:
```bash
# Required
POSTGRES_PASSWORD=your_secure_postgres_password
JWT_SECRET=your_secure_jwt_secret
ANON_KEY=your_secure_anon_key
SERVICE_ROLE_KEY=your_secure_service_role_key

# Domain config
DOMAIN=your_domain.com
ENABLE_SSL=true

# Email config (optional)
SMTP_HOST=your_smtp_host
SMTP_PORT=587
SMTP_USER=your_smtp_user
SMTP_PASS=your_smtp_password
SMTP_SENDER_NAME=Supabase
SMTP_SENDER_EMAIL=noreply@your_domain.com
```

## Step 5: Configure SSL with Let's Encrypt

1. Install Certbot:
```bash
sudo apt install certbot -y
```

2. Generate SSL certificates:
```bash
sudo certbot certonly --standalone -d your_domain.com
```

3. Copy certificates to Supabase directory:
```bash
sudo cp /etc/letsencrypt/live/your_domain.com/fullchain.pem ./volumes/api/kong.crt
sudo cp /etc/letsencrypt/live/your_domain.com/privkey.pem ./volumes/api/kong.key
```

## Step 6: Start Supabase Services

```bash
# Pull latest images
docker-compose pull

# Start services
docker-compose up -d
```

## Step 7: Verify Installation

1. Check if all services are running:
```bash
docker-compose ps
```

2. Access your Supabase Dashboard:
- Studio URL: https://your_domain.com/studio
- API URL: https://your_domain.com/rest/v1/

## Step 8: Security Considerations

1. Configure firewall rules:
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

2. Regularly update your installation:
```bash
cd /path/to/supabase-docker
git pull
docker-compose pull
docker-compose up -d
```

## Step 9: Backup Configuration

1. Set up automated backups for PostgreSQL:
```bash
# Create backup directory
mkdir -p /path/to/backup/postgres

# Add to crontab
0 0 * * * docker exec supabase-db pg_dumpall -U postgres > /path/to/backup/postgres/backup_$(date +%Y%m%d).sql
```

## Troubleshooting

### Common Issues

1. **Services not starting:**
   - Check logs: `docker-compose logs -f [service_name]`
   - Verify port availability: `netstat -tulpn`

2. **Database connection issues:**
   - Verify PostgreSQL is running: `docker-compose ps db`
   - Check database logs: `docker-compose logs db`

3. **SSL certificate issues:**
   - Verify certificate paths in kong configuration
   - Check certificate expiration: `openssl x509 -in ./volumes/api/kong.crt -text -noout`

### Maintenance

1. Regular updates:
```bash
# Update containers
docker-compose pull
docker-compose up -d

# Clean up unused images
docker image prune -f
```

2. Monitor resources:
```bash
# Check container resource usage
docker stats

# Check disk space
df -h
```

## Additional Resources

- [Official Supabase Documentation](https://supabase.com/docs)
- [Supabase Docker Repository](https://github.com/supabase/supabase-docker)
- [Kong Gateway Documentation](https://docs.konghq.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## Security Best Practices

1. **Access Control:**
   - Use strong passwords for all services
   - Implement IP whitelisting where possible
   - Regularly rotate JWT secrets and API keys

2. **Monitoring:**
   - Set up logging aggregation
   - Monitor system resources
   - Configure alerts for suspicious activities

3. **Backup Strategy:**
   - Regular database backups
   - Configuration backups
   - Test restore procedures periodically

4. **Updates:**
   - Regular system updates
   - Container image updates
   - Security patches

Remember to replace placeholder values (like `your_domain.com`, `your_secure_postgres_password`, etc.) with your actual values before running the commands. 