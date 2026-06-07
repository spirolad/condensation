#!/bin/bash

###############################################################################
# Build and Push Docker Images to AWS ECR
#
# Usage:
#   ./build-and-push-images.sh <environment> <aws-region>
#   ./build-and-push-images.sh dev us-east-1
#
# This script:
#   1. Logs into AWS ECR
#   2. Builds Docker images for frontend, backend, and auth services
#   3. Pushes them to ECR
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Validate arguments
if [ $# -lt 2 ]; then
    print_error "Missing arguments"
    echo ""
    echo "Usage: $0 <environment> <aws-region> [aws-account-id]"
    echo ""
    echo "Examples:"
    echo "  $0 dev us-east-1"
    echo "  $0 prod eu-west-1 123456789012"
    echo ""
    exit 1
fi

ENVIRONMENT=$1
AWS_REGION=$2
AWS_ACCOUNT_ID=${3:-$(aws sts get-caller-identity --query Account --output text)}

print_header "Docker Image Build & Push for $ENVIRONMENT"

echo ""
echo "Configuration:"
echo "  Environment: $ENVIRONMENT"
echo "  AWS Region: $AWS_REGION"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo ""

# Get ECR repository URLs
ECR_DOMAIN="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_FRONTEND="${ECR_DOMAIN}/${ENVIRONMENT}-frontend"
ECR_BACKEND="${ECR_DOMAIN}/${ENVIRONMENT}-backend"
ECR_AUTH="${ECR_DOMAIN}/${ENVIRONMENT}-auth"

print_header "Logging into AWS ECR"

if aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_DOMAIN"; then
    print_success "Successfully logged in to ECR"
else
    print_error "Failed to login to ECR"
    echo "Make sure you have AWS credentials configured"
    exit 1
fi

# Get repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Array to track build status
IMAGES_FAILED=()
IMAGES_SUCCESS=()

# Build and push Frontend
print_header "Building & Pushing Frontend Image"
echo "Image: $ECR_FRONTEND:latest"
echo "Source: ./frontend"

if docker build -t "$ECR_FRONTEND:latest" ./frontend; then
    print_success "Frontend image built"
    if docker push "$ECR_FRONTEND:latest"; then
        print_success "Frontend image pushed to ECR"
        IMAGES_SUCCESS+=("Frontend")
    else
        print_error "Failed to push Frontend image"
        IMAGES_FAILED+=("Frontend")
    fi
else
    print_error "Failed to build Frontend image"
    IMAGES_FAILED+=("Frontend")
fi

echo ""

# Build and push Backend
print_header "Building & Pushing Backend Image"
echo "Image: $ECR_BACKEND:latest"
echo "Source: ./backend"

if docker build -t "$ECR_BACKEND:latest" ./backend; then
    print_success "Backend image built"
    if docker push "$ECR_BACKEND:latest"; then
        print_success "Backend image pushed to ECR"
        IMAGES_SUCCESS+=("Backend")
    else
        print_error "Failed to push Backend image"
        IMAGES_FAILED+=("Backend")
    fi
else
    print_error "Failed to build Backend image"
    IMAGES_FAILED+=("Backend")
fi

echo ""

# Build and push Auth
print_header "Building & Pushing Auth Image"
echo "Image: $ECR_AUTH:latest"
echo "Source: ./authentication"

if docker build -t "$ECR_AUTH:latest" ./authentication; then
    print_success "Auth image built"
    if docker push "$ECR_AUTH:latest"; then
        print_success "Auth image pushed to ECR"
        IMAGES_SUCCESS+=("Auth")
    else
        print_error "Failed to push Auth image"
        IMAGES_FAILED+=("Auth")
    fi
else
    print_error "Failed to build Auth image"
    IMAGES_FAILED+=("Auth")
fi

# Summary
echo ""
print_header "Build & Push Summary"

if [ ${#IMAGES_SUCCESS[@]} -gt 0 ]; then
    echo -e "${GREEN}Successfully built & pushed:${NC}"
    for image in "${IMAGES_SUCCESS[@]}"; do
        echo "  ✓ $image"
    done
fi

if [ ${#IMAGES_FAILED[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed to build/push:${NC}"
    for image in "${IMAGES_FAILED[@]}"; do
        echo "  ✗ $image"
    done
    echo ""
    print_error "Build process failed. Please check the errors above."
    exit 1
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}All images successfully built and pushed to ECR!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "  1. Run the Ansible playbook to deploy:"
echo "     ansible-playbook -i inventory.ini infra/ansible/deploy.yml -e env_name=$ENVIRONMENT"
echo ""
echo "ECR Repository URLs:"
echo "  Frontend:  $ECR_FRONTEND:latest"
echo "  Backend:   $ECR_BACKEND:latest"
echo "  Auth:      $ECR_AUTH:latest"
echo ""
