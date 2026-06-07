# Ansible Deployment Playbook

## Overview

This playbook automates the complete deployment of the Condensation application stack to AWS EC2.

### What the playbook does:

1. **PLAY 0 - Build Docker Images (Optional)**
   - Prompts user to build and push Docker images to ECR
   - Builds Frontend, Backend, and Auth images
   - Pushes images to AWS ECR repositories
   - This step can be skipped if images already exist in ECR

2. **PLAY 1 - Fetch Secrets & Config**
   - Retrieves database credentials from AWS Secrets Manager
   - Fetches RDS endpoint, database names, and other configuration from SSM Parameter Store
   - Retrieves ECR image URLs

3. **PLAY 2 - Deploy Application**
   - Installs Docker and Docker Compose on EC2
   - Generates docker-compose.yml with all environment variables
   - Logs into ECR
   - Pulls and starts containers
   - Waits for services to be healthy
   - Displays access URLs and debugging information

---

## Prerequisites

### Local Machine
- **AWS CLI** - configured with credentials
- **Docker** - installed and running
- **Ansible** - version 2.9 or higher
- **Git** - to detect repository root

### AWS
- **Terraform Infrastructure** - must be already deployed (EC2, RDS, ECR, SSM parameters)
- **IAM Permissions** - user/role must have:
  - ECR access (build, push)
  - SSM Parameter Store read access
  - Secrets Manager read access

### SSH
- **EC2 Key Pair** - private key file must be available locally
- **EC2 Instance** - must be running and accessible via SSH

---

## Usage

### Option 1: Build Images + Deploy (Full Workflow)

Includes building Docker images from scratch:

```bash
# Navigate to repository root
cd /path/to/condensation

# Run with build enabled
ansible-playbook -i infra/ansible/inventory.ini \
  infra/ansible/deploy.yml \
  -e env_name=dev \
  -e ansible_ssh_private_key_file=/path/to/ec2-key.pem \
  -v
```

When prompted, type `yes` to build images.

### Option 2: Skip Image Build (Deploy Only)

If images already exist in ECR:

```bash
ansible-playbook -i infra/ansible/inventory.ini \
  infra/ansible/deploy.yml \
  -e env_name=dev \
  -e build_images=false \
  -e ansible_ssh_private_key_file=/path/to/ec2-key.pem \
  -v
```

Or answer `no` when prompted.

### Option 3: From CI/CD Pipeline

In GitHub Actions, GitLab CI, or other CI/CD:

```yaml
- name: Deploy with Docker build
  run: |
    ansible-playbook -i infra/ansible/inventory.ini \
      infra/ansible/deploy.yml \
      -e env_name=${{ env.ENVIRONMENT }} \
      -e build_images=true \
      -e ansible_ssh_private_key_file=$SSH_KEY_PATH
```

---

## Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `env_name` | *required* | Environment name (dev, prod, staging) |
| `build_images` | false | Whether to build Docker images (true/false/prompt) |
| `ansible_ssh_private_key_file` | *required* | Path to EC2 private key |
| `aws_region` | us-east-1 | AWS region |

### Example with all variables:

```bash
ansible-playbook -i infra/ansible/inventory.ini \
  infra/ansible/deploy.yml \
  -e env_name=prod \
  -e build_images=false \
  -e ansible_ssh_private_key_file=~/.ssh/ec2-prod.pem \
  -e aws_region=eu-west-1 \
  -v
```

---

## Inventory Configuration

### File: `infra/ansible/inventory.ini`

```ini
[ec2_instances]
# Add EC2 instance IP address here
# Obtained from Terraform outputs

[ec2_instances:vars]
ansible_user=ec2-user
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

### Update with EC2 Instance IP:

```bash
# Get EC2 Public IP from AWS (or Terraform output)
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=dev-app-ec2" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text --region us-east-1

# Update inventory.ini with the IP
```

---

## Troubleshooting

### Issue: "Failed to connect to host"

```bash
# Verify EC2 instance is running
aws ec2 describe-instances --region us-east-1 \
  --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}'

# Test SSH connection manually
ssh -i /path/to/key.pem ec2-user@<EC2_PUBLIC_IP> "echo OK"

# Check security group allows SSH (port 22)
aws ec2 describe-security-groups \
  --query 'SecurityGroups[*].[GroupId,IpPermissions]' --region us-east-1
```

### Issue: "Permission denied (publickey)"

```bash
# Verify private key permissions
chmod 600 /path/to/ec2-key.pem

# Verify key is correct
ssh-keygen -y -f /path/to/ec2-key.pem  # Should show public key

# Verify EC2 has the public key
# (check in AWS console or via aws-cli)
```

### Issue: "Docker images not found in ECR"

The playbook will automatically fail with clear instructions if images don't exist:

```bash
# Build and push images
ansible-playbook ... -e build_images=true

# Or use the standalone build script
chmod +x scripts/build-and-push-images.sh
./scripts/build-and-push-images.sh dev us-east-1
```

### Issue: "Services not becoming healthy"

```bash
# SSH into EC2 and check logs
ssh -i /path/to/key.pem ec2-user@<EC2_PUBLIC_IP>

# Check container status
cd /home/ec2-user/app
docker-compose ps

# View service logs
docker-compose logs -f auth
docker-compose logs -f backend
docker-compose logs -f frontend
```

### Issue: "Database connection errors"

```bash
# Verify database endpoint is correct
aws ssm get-parameter --name "/dev/rds_endpoint" \
  --query 'Parameter.Value' --output text

# Test database connectivity from EC2
ssh -i /path/to/key.pem ec2-user@<EC2_PUBLIC_IP>
docker exec backend curl -v http://auth:80  # Test internal connectivity
```

---

## Building Docker Images

The playbook automates this, but for reference:

### What gets built:

1. **Frontend** - Next.js application
   - Built from: `./frontend`
   - Dockerfile: `./frontend/Dockerfile`

2. **Backend** - Spring Boot application
   - Built from: `./backend`
   - Dockerfile: `./backend/Dockerfile`

3. **Auth** - Laravel application
   - Built from: `./authentication`
   - Dockerfile: `./authentication/Dockerfile`

### Build performance tips:

- Builds can take 5-15 minutes depending on image size
- Ensure sufficient disk space (at least 5GB)
- Use a stable internet connection
- Run on a machine with sufficient CPU resources

---

## Service Access After Deployment

Once deployment completes successfully:

| Service | URL | Port |
|---------|-----|------|
| Frontend (Next.js) | `http://<EC2_IP>` | 80 |
| Auth (Laravel) | `http://<EC2_IP>:8000` | 8000 |
| Backend (Spring Boot) | `http://<EC2_IP>:8080` | 8080 |
| Prometheus | `http://<EC2_IP>:9090` | 9090 |
| Grafana | `http://<EC2_IP>:3001` | 3001 |

---

## Monitoring Deployment

### View playbook execution:

```bash
# Verbose output
ansible-playbook ... -v

# Extra verbose
ansible-playbook ... -vv

# Debug mode
ansible-playbook ... -vvv
```

### View logs on EC2:

```bash
# SSH into instance
ssh -i /path/to/key.pem ec2-user@<EC2_PUBLIC_IP>

# Real-time logs
cd /home/ec2-user/app
docker-compose logs -f

# Specific service logs
docker-compose logs -f frontend   # Frontend
docker-compose logs -f backend    # Backend
docker-compose logs -f auth       # Auth
docker-compose logs -f prometheus # Prometheus
docker-compose logs -f grafana    # Grafana
```

---

## Advanced Usage

### CI/CD Integration Example (GitHub Actions)

```yaml
name: Deploy with Ansible

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - staging
          - prod

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Install Ansible
        run: pip install ansible
      
      - name: Create SSH key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.EC2_PRIVATE_KEY }}" > ~/.ssh/ec2-key.pem
          chmod 600 ~/.ssh/ec2-key.pem
      
      - name: Update inventory
        run: |
          EC2_IP=$(aws ec2 describe-instances \
            --filters "Name=tag:Environment,Values=${{ inputs.environment }}" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)
          sed -i "s/EC2_IP/$EC2_IP/g" infra/ansible/inventory.ini
      
      - name: Run Ansible Deployment
        run: |
          ansible-playbook -i infra/ansible/inventory.ini \
            infra/ansible/deploy.yml \
            -e env_name=${{ inputs.environment }} \
            -e build_images=true \
            -e ansible_ssh_private_key_file=~/.ssh/ec2-key.pem \
            -v
```

---

## Rollback

To revert to a previous deployment:

```bash
# SSH into EC2
ssh -i /path/to/key.pem ec2-user@<EC2_PUBLIC_IP>
cd /home/ec2-user/app

# Stop current containers
docker-compose down

# Pull previous image version (if available)
docker pull <ECR_URL>:<TAG>

# Update docker-compose.yml with previous image tags
vim docker-compose.yml

# Restart
docker-compose up -d
```

---

## Support & Documentation

- [Main Deployment Guide](../../DEPLOYMENT_GUIDE.md)
- [AWS Infrastructure](../../aws/)
- [Docker Compose Configuration](./docker-compose.yml.j2)
- [Build Script](../../scripts/build-and-push-images.sh)
