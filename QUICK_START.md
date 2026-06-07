# ⚡ Quick Start Guide - One Command Deployment

## Prerequisites ✅

```bash
# Install required tools
brew install awscli ansible          # macOS
sudo apt-get install awscli ansible  # Ubuntu/Debian

# Configure AWS
aws configure
# Enter your AWS Access Key ID, Secret Access Key, region: us-east-1

# Verify AWS access
aws sts get-caller-identity
```

## Step-by-Step 🚀

### 1. Get EC2 Instance IP

```bash
# Option A: From AWS CLI
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=dev-app-ec2" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text --region us-east-1

# Option B: From AWS Console
# EC2 Dashboard → Instances → Find "dev-app-ec2" → Copy Public IPv4 address
```

### 2. Update Ansible Inventory

```bash
# Copy example inventory
cp infra/ansible/inventory.ini.example infra/ansible/inventory.ini

# Edit with your EC2 IP
nano infra/ansible/inventory.ini
# Replace <EC2_PUBLIC_IP> with actual IP
```

### 3. Prepare EC2 SSH Key

```bash
# Make sure your EC2 private key has correct permissions
chmod 600 ~/.ssh/ec2-key.pem

# Test SSH connection (optional)
ssh -i ~/.ssh/ec2-key.pem ec2-user@<EC2_PUBLIC_IP> "echo OK"
```

### 4. Run Deployment (Single Command! 🎉)

```bash
ansible-playbook -i infra/ansible/inventory.ini \
  infra/ansible/deploy.yml \
  -e env_name=dev \
  -e ansible_ssh_private_key_file=~/.ssh/ec2-key.pem \
  -v
```

**When prompted:** Type `yes` to build Docker images and deploy

That's it! ✨

---

## What Happens 📋

The playbook automatically:

1. **Builds Docker Images** (if you answered yes)
   - Compiles Frontend (Next.js)
   - Compiles Backend (Spring Boot)
   - Compiles Auth (Laravel)
   - Pushes all to AWS ECR

2. **Fetches AWS Configuration**
   - Gets database credentials
   - Fetches RDS endpoint
   - Retrieves ECR image URLs

3. **Deploys Application**
   - Installs Docker & Docker Compose on EC2
   - Logs into ECR
   - Starts all containers
   - Waits for services to be healthy

4. **Displays Access URLs**
   - Frontend: `http://<EC2_IP>`
   - Auth: `http://<EC2_IP>:8000`
   - Backend: `http://<EC2_IP>:8080`
   - Prometheus: `http://<EC2_IP>:9090`
   - Grafana: `http://<EC2_IP>:3001`

---

## Debugging 🔧

If deployment fails, check:

```bash
# View playbook logs (already displayed)
# Look for error messages and follow suggestions

# SSH into EC2 and check services
ssh -i ~/.ssh/ec2-key.pem ec2-user@<EC2_IP>
cd /home/ec2-user/app

# View container logs
docker-compose logs -f

# Check specific service
docker-compose logs -f frontend
docker-compose logs -f backend
docker-compose logs -f auth

# Check container status
docker-compose ps

# Test service health
curl http://localhost:8080/actuator/health  # Backend
curl http://localhost                        # Frontend
curl http://localhost:8000                   # Auth
```

---

## Common Issues 🚨

### "Failed to connect to host"
- Verify EC2 instance IP is correct
- Check security group allows SSH (port 22)
- Verify SSH key permissions: `chmod 600 ~/.ssh/ec2-key.pem`

### "Permission denied (publickey)"
- Wrong SSH key or key not added to EC2
- Verify with: `ssh-keygen -y -f ~/.ssh/ec2-key.pem`

### "Docker images not found"
- Playbook will automatically build them (answer "yes" when prompted)
- Or pass `-e build_images=true` to force build

### "Page loads infinitely"
- Services may still be starting (wait 60-90 seconds)
- Check backend logs for database connection errors
- Verify all services are healthy: `docker-compose ps`

---

## More Options 🎛️

### Skip Image Build (use existing images)
```bash
ansible-playbook ... -e build_images=false
```

### Verbose Output (detailed logging)
```bash
ansible-playbook ... -vvv
```

### For Production Environment
```bash
ansible-playbook ... -e env_name=prod \
  -e ansible_ssh_private_key_file=~/.ssh/ec2-prod.pem
```

---

## Full Documentation 📚

For more details, see:
- [infra/ansible/README.md](infra/ansible/README.md) - Detailed Ansible documentation
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Complete deployment guide
- [scripts/build-and-push-images.sh](scripts/build-and-push-images.sh) - Standalone build script

---

## Support 💬

Having issues? Check:
1. AWS credentials are configured: `aws sts get-caller-identity`
2. Docker is running locally: `docker ps`
3. EC2 instance is running: `aws ec2 describe-instances | grep State`
4. Security group allows SSH: Check EC2 security group rules
5. SSH key permissions: `ls -la ~/.ssh/ec2-key.pem` should show `-rw-------`

For detailed troubleshooting, see [infra/ansible/README.md](infra/ansible/README.md)
