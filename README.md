# EKS Node.js Microservices POC

## Overview

This project is a **production-style Proof of Concept (POC)** demonstrating how to deploy and run **Node.js microservices on AWS EKS** using **Terraform, Docker, Kubernetes, and AWS ALB Ingress** — with a strong focus on **real-world DevOps practices and cost efficiency**.

The goal of this project is not just to make things work, but to show *how they should be built in production*.

---

## Tech Stack

* **AWS EKS** – Managed Kubernetes
* **Terraform** – Infrastructure as Code
* **Docker** – Containerization
* **Kubernetes** – Orchestration
* **AWS ECR** – Container Registry
* **AWS Load Balancer Controller** – ALB-based Ingress
* **Node.js (Express)** – Microservices

---

## Architecture Diagram

```
                    ┌────────────────────────────┐
                    │        Internet Users       │
                    └──────────────┬─────────────┘
                                   │
                           (HTTP Requests)
                                   │
                    ┌──────────────▼─────────────┐
                    │    AWS Application Load     │
                    │        Balancer (ALB)       │
                    └──────────────┬─────────────┘
                                   │
                        Kubernetes Ingress (ALB)
                                   │
                ┌──────────────────┴──────────────────┐
                │                                     │
        ┌───────▼────────┐                   ┌────────▼───────┐
        │  user-service   │                   │  order-service  │
        │  (Node.js API)  │◀─────Service─────▶│  (Node.js API)  │
        └───────┬────────┘                   └────────┬───────┘
                │                                     │
        ┌───────▼────────┐                   ┌────────▼───────┐
        │ Kubernetes SVC  │                   │ Kubernetes SVC  │
        │   ClusterIP     │                   │   ClusterIP     │
        └────────────────┘                   └────────────────┘

        ─────────────────────────────────────────────────────────
                  AWS EKS Cluster (Managed Node Group)
```

---

## Microservices

### 1. User Service

* Internal service
* Exposes:

  * `/health` – Health check
* Consumed by `order-service`

### 2. Order Service

* Public-facing service
* Exposes:

  * `/orders` – Returns order details
* Calls `user-service` internally via Kubernetes service DNS

---

## Request Flow

1. Client sends request to ALB (`/orders`)
2. ALB forwards traffic to Kubernetes Ingress
3. Ingress routes request to `order-service`
4. `order-service` calls `user-service` internally
5. Combined response is returned to the client

---

## Infrastructure Design

* **VPC** with public and private subnets
* **EKS cluster** with managed node group
* **ECR repositories** for each microservice
* **IRSA** for AWS Load Balancer Controller
* **Ingress** backed by ALB

All infrastructure is created using **Terraform modules**.

---

## Kubernetes Highlights

* Deployments with multiple replicas
* ClusterIP services for internal communication
* ALB Ingress for external access
* Health checks for ALB target groups

---

## Cost Optimization Choices

* Single EKS node group
* Minimal instance sizes
* No NAT Gateway over-provisioning
* Shared ALB for both services

---

## Why This Project is Production-Oriented

* Separation of infra, app, and k8s layers
* No hardcoded secrets
* IAM roles via IRSA
* Explicit resource boundaries
* Scalable architecture

---

## Future Enhancements

* Horizontal Pod Autoscaler (HPA)
* Resource limits & requests
* CI/CD pipeline (GitHub Actions)
* Prometheus `/metrics` endpoint
* HTTPS via ACM
* GitOps with ArgoCD

---

## Deployment Steps

### Step 1: Provision Infrastructure with Terraform

Deploy VPC, EKS cluster, ECR repositories, and IAM roles:

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure
terraform apply -auto-approve
```

**Output to note:**
- ECR repository URIs for both services
- EKS cluster endpoint
- IAM role ARNs

### Step 2: Configure kubectl Access and IAM Access Entries

Configure EKS access for your IAM user and set up AWS Load Balancer Controller:

```bash
# Set variables
CLUSTER_NAME="eks-dev-cluster"
REGION="ap-south-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IAM_USER="test"  # Replace with your IAM user name
USER_ARN="arn:aws:iam::${ACCOUNT_ID}:user/${IAM_USER}"

# Step 1: Create EKS access entry for your IAM user
aws eks create-access-entry \
  --cluster-name $CLUSTER_NAME \
  --principal-arn $USER_ARN \
  --region $REGION

# Step 2: Associate cluster admin policy
aws eks associate-access-policy \
  --cluster-name $CLUSTER_NAME \
  --principal-arn $USER_ARN \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region $REGION

# Step 3: Update kubeconfig
aws eks update-kubeconfig \
  --region $REGION \
  --name $CLUSTER_NAME

# Step 4: Verify kubectl access
kubectl get nodes
kubectl get pods -n kube-system

# ============================================
# AWS Load Balancer Controller Setup (for Ingress)
# ============================================

# Step 5: Download ALB controller IAM policy
curl -o iam_policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# Step 6: Create IAM policy
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json \
  --region $REGION

# Step 7: Get OIDC issuer URL
OIDC_ID=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $REGION \
  --query "cluster.identity.oidc.issuer" \
  --output text | cut -d '/' -f5)

echo "OIDC ID: $OIDC_ID"

# Step 8: Create IAM service account with IRSA (if using eksctl)
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region $REGION

# Step 9: Add AWS EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Step 10: Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$REGION \
  --set vpcId=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=eks-dev-vpc --region $REGION --query 'Vpcs[0].VpcId' --output text)

# Step 11: Verify ALB Controller is running
kubectl get deployment -n kube-system | grep aws-load-balancer-controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

**What this does:**
- Creates EKS access entry for your IAM user (modern method replacing aws-auth ConfigMap)
- Assigns cluster admin policy
- Sets up AWS Load Balancer Controller for ALB-based Ingress
- Creates IRSA (IAM roles for Service Accounts) for secure AWS API access

### Step 3: Build Docker Images Locally

Build container images for both microservices:

```bash
# Build user-service image
cd services/user-service
docker build -t user-service:latest .

# Build order-service image
cd ../order-service
docker build -t order-service:latest .

cd ../..
```

### Step 4: Push Images to AWS ECR

Get ECR repository URIs and push images:

```bash
# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-south-1"

# ECR repository URIs
USER_SERVICE_ECR="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/eks-dev-user-service"
ORDER_SERVICE_ECR="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/eks-dev-order-service"

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Tag images
docker tag user-service:latest $USER_SERVICE_ECR:latest
docker tag order-service:latest $ORDER_SERVICE_ECR:latest

# Push images to ECR
docker push $USER_SERVICE_ECR:latest
docker push $ORDER_SERVICE_ECR:latest

echo "Images pushed successfully!"
echo "User Service: $USER_SERVICE_ECR:latest"
echo "Order Service: $ORDER_SERVICE_ECR:latest"
```

### Step 5: Deploy Kubernetes Manifests with Kustomize

This project uses **Kustomize** for environment-agnostic manifest management. Images and environment-specific values are injected at deployment time.

**Prerequisites:**
- `kubectl` with kustomize support (v1.14+)
- `envsubst` command available in your shell
- AWS CLI configured with valid credentials

**Deployment:**

```bash
# Navigate to project root
cd eks-nodejs-microservices

# Set environment variables
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION="ap-south-1"
export IMAGE_TAG="latest"
export ENVIRONMENT="dev"  # dev, staging, or prod

# Option 1: Use the automated deploy script
chmod +x deploy.sh
./deploy.sh

# Option 2: Manual Kustomize deployment
kubectl kustomize k8s/overlays/dev | envsubst | kubectl apply -f -

# Verify deployments
kubectl get deployments -n microservices
kubectl get pods -n microservices
kubectl get services -n microservices
```

**Directory Structure:**
```
k8s/
├── base/                          # Base configurations (shared)
│   ├── order-service/
│   │   ├── deployment.yaml       # Generic image name (no account ID)
│   │   ├── service.yaml
│   │   ├── kustomization.yaml
│   │   └── resources/
│   │       └── namespace.yaml
│   ├── user-service/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── kustomization.yaml
│   │   └── resources/
│   │       └── namespace.yaml
│   └── ingress/
│       ├── ingress.yaml
│       └── kustomization.yaml
└── overlays/                      # Environment-specific overrides
    ├── dev/
    │   ├── kustomization.yaml     # Replaces images with ECR URIs
    │   └── configmap.yaml
    ├── staging/
    │   ├── kustomization.yaml
    │   └── configmap.yaml
    └── prod/
        ├── kustomization.yaml
        └── configmap.yaml
```

**How it works:**
1. Base manifests contain generic image names (e.g., `order-service:latest`)
2. Overlays replace images with ECR repository URIs using environment variables
3. The deploy script exports `AWS_ACCOUNT_ID`, `AWS_REGION`, and `IMAGE_TAG`
4. `envsubst` substitutes these values into Kustomize output
5. `kubectl apply` deploys the final manifests

**Example transformation:**
```bash
# Before (base/order-service/deployment.yaml):
image: order-service:latest

# After (dev overlay with environment variables):
image: ${AWS_ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com/eks-dev-order-service:latest
# Example: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/eks-dev-order-service:latest
```



### Step 6: Access the Application

Get the ALB DNS name and test the services:

```bash
# Get ALB DNS name
ALB_DNS=$(kubectl get ingress -n microservices -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "ALB DNS: $ALB_DNS"

# Wait for ALB to be ready (2-3 minutes typically)
echo "Waiting for ALB to route traffic..."
sleep 120

# Test the services
curl http://$ALB_DNS/orders
```

---

## Security & Best Practices

### No Hardcoded Secrets

This project follows production-grade security practices:

✅ **What we do:**
- Use **Kustomize overlays** for environment-specific configurations
- Store only generic base manifests in version control
- Pass environment variables at deployment time
- Use **AWS IAM authentication** for all AWS API calls
- Leverage **IRSA** (IAM Roles for Service Accounts) for pod permissions
- Never commit account IDs, ARNs, or sensitive credentials

❌ **What we avoid:**
- Hardcoded AWS Account IDs
- Hardcoded IAM user ARNs
- Plaintext database passwords
- API keys in manifests
- Terraform `.tfvars` files (use `.tfvars.example` for templates)

### Files NOT to commit:
```
terraform.tfvars          # AWS credentials, account IDs
.env                      # Environment variables
.env.local               # Local overrides
aws-credentials          # AWS CLI credentials
*.pem, *.key            # SSH keys
```

These are already in `.gitignore`.

### Deployment Best Practices:

```bash
# ✅ CORRECT: Set variables before deployment
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION="ap-south-1"
export IMAGE_TAG="latest"
./deploy.sh

# ❌ WRONG: Committing hardcoded values
# Don't do this:
# image: 123456789012.dkr.ecr.ap-south-1.amazonaws.com/eks-dev-order-service:latest
```

### Creating Multiple Environments:

```bash
# Create staging overlay (copy from dev)
mkdir -p k8s/overlays/staging
cp k8s/overlays/dev/* k8s/overlays/staging/

# Update kustomization.yaml for staging
# - Different image names or tags
# - Different replica counts
# - Different resource limits
```

---

## How to Run (High-Level)

1. **Provision infrastructure** – Terraform creates VPC, EKS, ECR, and IAM
2. **Build Docker images** – Create container images for microservices
3. **Push to ECR** – Authenticate with AWS ECR and upload images
4. **Deploy to Kubernetes** – Use Kustomize with environment variables for secure deployments
5. **Access services** – Use ALB DNS to reach the microservices

---

## Author

**Vaibhav Sarvaiya**
Senior DevOps Engineer
