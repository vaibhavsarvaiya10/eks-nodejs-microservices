#!/bin/bash
# Deploy microservices using Kustomize with environment variables

set -e

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-eks-dev-cluster}"
REGION="${AWS_REGION:-ap-south-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=================================================="
echo "Deploying Microservices with Kustomize"
echo "=================================================="
echo "Cluster: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"
echo "AWS Account ID: $ACCOUNT_ID"
echo "Image Tag: $IMAGE_TAG"
echo "=================================================="

# Export variables for Kustomize
export AWS_ACCOUNT_ID=$ACCOUNT_ID
export AWS_REGION=$REGION
export IMAGE_TAG=$IMAGE_TAG

# Create namespace if it doesn't exist
kubectl create namespace microservices --dry-run=client -o yaml | kubectl apply -f -

# Apply Kustomize configuration
echo ""
echo "Applying Kustomize configuration..."
kubectl kustomize "k8s/overlays/${ENVIRONMENT}" | envsubst | kubectl apply -f -

# Verify deployments
echo ""
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available \
  --timeout=300s \
  deployment/order-service \
  deployment/user-service \
  -n microservices

# Get deployment status
echo ""
echo "Deployment Status:"
kubectl get deployments -n microservices
echo ""
echo "Pods:"
kubectl get pods -n microservices
echo ""
echo "Services:"
kubectl get services -n microservices

echo ""
echo "=================================================="
echo "Deployment Complete!"
echo "=================================================="
