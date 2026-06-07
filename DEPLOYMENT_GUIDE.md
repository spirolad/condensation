# 🚀 Complete Deployment Guide - Condensation Project

## Prerequisites

- AWS CLI configured with credentials
- Docker installed and running
- Ansible installed
- Terraform state already applied (AWS infrastructure exists)
- SSH key pair generated for EC2 instance

## Deployment Steps

### Step 1: Configure Ansible Inventory

Update `infra/ansible/inventory.ini` with your EC2 instance IP:

```ini
[ec2_instances]
<EC2_PUBLIC_IP>

[ec2_instances:vars]
ansible_user=ec2-user
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

Get your EC2 IP:
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=dev-app-ec2" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text --region us-east-1
```

### Step 2: Run Ansible Deployment (with Integrated Build)

The playbook now handles everything - building and pushing images, then deploying:

```bash
ansible-playbook -i infra/ansible/inventory.ini \
  infra/ansible/deploy.yml \
  -e env_name=dev \
  -e ansible_ssh_private_key_file=~/.ssh/ec2-key.pem \
  -v
```

**When prompted:** Type `yes` to build Docker images, or `no` to use existing images in ECR.

### What the playbook does:

1. **PLAY 0 - Build Docker Images (Optional)**
   - Builds Frontend, Backend, and Auth images locally
   - Pushes them to AWS ECR
   - Can be skipped if images already exist

2. **PLAY 1 - Fetch AWS Configuration**
   - Retrieves database credentials from Secrets Manager
   - Fetches RDS endpoint, databases, and other config from SSM Parameter Store

3. **PLAY 2 - Deploy Application**
   - Installs Docker and Docker Compose on EC2
   - Generates docker-compose.yml with all environment variables
   - Pulls and starts all containers
   - Waits for services to be healthy
   - Displays access URLs

### Alternative: Skip Image Build (Deploy Only)

If images already exist in ECR:

```bash
ansible-playbook -i infra/ansible/inventory.ini \
  infra/ansible/deploy.yml \
  -e env_name=dev \
  -e build_images=false \
  -e ansible_ssh_private_key_file=~/.ssh/ec2-key.pem \
  -v
```

### Alternative: Build Images Separately

If you prefer to build images separately (not during deployment):

```bash
# Make script executable
chmod +x scripts/build-and-push-images.sh

# Build and push images
./scripts/build-and-push-images.sh dev us-east-1

# Then deploy without building
ansible-playbook -i infra/ansible/inventory.ini \
  infra/ansible/deploy.yml \
  -e env_name=dev \
  -e build_images=false \
  -e ansible_ssh_private_key_file=~/.ssh/ec2-key.pem \
  -v
```

#### Manual Build and Push (if needed)

```bash
# Set variables (if building manually)
ENVIRONMENT="dev"
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_DOMAIN="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_DOMAIN}

# Build and push Frontend
docker build -t ${ECR_DOMAIN}/${ENVIRONMENT}-frontend:latest ./frontend
docker push ${ECR_DOMAIN}/${ENVIRONMENT}-frontend:latest

# Build and push Backend
docker build -t ${ECR_DOMAIN}/${ENVIRONMENT}-backend:latest ./backend
docker push ${ECR_DOMAIN}/${ENVIRONMENT}-backend:latest

# Build and push Auth
docker build -t ${ECR_DOMAIN}/${ENVIRONMENT}-auth:latest ./authentication
docker push ${ECR_DOMAIN}/${ENVIRONMENT}-auth:latest
```

---

## Full Ansible Documentation

For detailed Ansible playbook documentation, see: [infra/ansible/README.md](infra/ansible/README.md)

This includes:
- All available variables
- Detailed troubleshooting
- CI/CD integration examples
- Advanced usage scenarios

---

## Troubleshooting

### Issue: "Failed to connect to host"

**Cause:** EC2 instance IP incorrect or unreachable

**Solution:**
```bash
# Verify instance is running
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:Name,Values=dev-app-ec2"

# Update inventory.ini with correct IP
# Verify SSH access works
ssh -i ~/.ssh/ec2-key.pem ec2-user@<EC2_IP> "echo OK"
```

### Issue: "manifest for image not found"

**Cause:** Docker images don't exist in ECR

**Solution:**
```bash
# Verify images exist
aws ecr describe-images --repository-name dev-frontend --region us-east-1

# If missing, run playbook with build enabled:
ansible-playbook ... -e build_images=true
```

### Issue: "Page loads infinitely"

**Possible causes:**
- Services still starting (wait 60-90 seconds)
- Database connectivity issues
- Services cannot reach each other

**Debugging:**
```bash
# SSH into EC2
ssh -i ~/.ssh/ec2-key.pem ec2-user@<EC2_IP>

# Check service logs
cd /home/ec2-user/app
docker-compose logs -f frontend
docker-compose logs -f backend
docker-compose logs -f auth

# Test inter-service connectivity
docker exec frontend curl -v http://backend:8080/actuator/health
docker exec frontend curl -v http://auth:80
```

### Issue: "Connection refused" from frontend to backend

**Check network connectivity:**
```bash
# Inside frontend container
docker exec frontend curl -v http://backend:8080

# Inside backend container
docker exec backend nc -zv auth 80

# Verify environment variables
docker exec frontend env | grep -E "AUTH_URL|BACKEND_URL|API_URL"
```

---

## Service Access URLs

After successful deployment:

- **Frontend**: `http://<EC2_PUBLIC_IP>:80`
- **Auth Service**: `http://<EC2_PUBLIC_IP>:8000`
- **Backend API**: `http://<EC2_PUBLIC_IP>:8080`
- **Prometheus**: `http://<EC2_PUBLIC_IP>:9090`
- **Grafana**: `http://<EC2_PUBLIC_IP>:3001`

---

## Useful Commands

### View live logs
```bash
ssh -i ${SSH_KEY_PATH} ec2-user@${EC2_PUBLIC_IP}
cd /home/ec2-user/app
docker-compose logs -f
```

### Check container status
```bash
docker-compose ps
```

### Restart all services
```bash
docker-compose restart
```

### View specific service logs
```bash
docker-compose logs -f auth       # Auth service
docker-compose logs -f backend     # Backend API
docker-compose logs -f frontend    # Frontend
```

### Test service health
```bash
# From EC2 instance
curl http://localhost:8080/actuator/health    # Backend
curl http://localhost:80                        # Frontend
curl http://localhost:8000                      # Auth
curl http://localhost:9090/-/healthy            # Prometheus
```

---

## Database Operations

### Connect to database
```bash
# Get database credentials from SSM (from local machine)
aws ssm get-parameter --name "/${ENVIRONMENT}/rds_db_secret" \
  --query 'Parameter.Value' --output text --region us-east-1 | \
  aws secretsmanager get-secret-value --secret-id - \
  --query 'SecretString' --output text --region us-east-1 | jq

# Connect using psql (if installed locally)
psql -h <RDS_ENDPOINT> -U <USERNAME> -d <DATABASE_NAME>
```

### View database migrations
```bash
# Inside auth container
docker exec -it auth php artisan migrate:status

# Inside backend container
docker exec -it backend ./mvnw flyway:info
```

---

## Environment Variables Reference

Key environment variables used in docker-compose.yml:

- `DB_HOST` - RDS endpoint
- `DB_USERNAME` - Database username
- `DB_PASSWORD` - Database password
- `DB_DATABASE` - Database name
- `ECR_*_URL` - ECR repository URLs for Docker images
- `AUTH_URL` - Auth service URL (internal)
- `BACKEND_URL` - Backend service URL (internal)
- `CLIENT_ID` - OAuth client ID
- `INTERNAL_SECRET` - Shared secret between services
- `STRIPE_SECRET_KEY` - Stripe API key

All these are stored in AWS SSM Parameter Store and fetched by Ansible during deployment.

---

## Monitoring & Observability

### Prometheus
- Access: `http://<EC2_PUBLIC_IP>:9090`
- Metrics from backend at: `/actuator/prometheus`
- Default scrape interval: 15 seconds

### Grafana
- Access: `http://<EC2_PUBLIC_IP>:3001`
- Default credentials: admin / admin
- Data source: Prometheus

### Container Logs
```bash
docker-compose logs -f <service_name>
```

---

## Rollback

To revert to previous images:

```bash
# View image history
docker image ls | grep dev-

# Tag specific image version
docker tag ${ECR_DOMAIN}/dev-frontend:v1.0.0 ${ECR_DOMAIN}/dev-frontend:latest

# Update docker-compose.yml image reference (manual edit required)

# Restart containers
docker-compose pull
docker-compose up -d
```

---

## Additional Documentation

- [AWS SSM Parameter Store Setup](../../aws/4-ec2.tf)
- [Terraform Infrastructure](../../aws/)
- [Ansible Configuration](../ansible/)
- [Docker Compose Configuration](../ansible/docker-compose.yml.j2)
