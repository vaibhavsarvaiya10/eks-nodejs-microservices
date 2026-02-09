#!/bin/bash

# Patch aws-auth ConfigMap using AWS SigV4 signed requests

CLUSTER_NAME="eks-dev-cluster"
REGION="ap-south-1"
USER_ARN="arn:aws:iam::***REMOVED***:user/terraform"
USERNAME="terraform"

# Get the cluster endpoint
ENDPOINT=$(aws eks describe-cluster --region $REGION --name $CLUSTER_NAME --query 'cluster.endpoint' --output text)
echo "Cluster endpoint: $ENDPOINT"

# Get CA certificate
aws eks describe-cluster --region $REGION --name $CLUSTER_NAME --query 'cluster.certificateAuthority.data' --output text | base64 -d > /tmp/ca.crt

# Create the patch payload
cat > /tmp/patch.json << EOF
{
  "data": {
    "mapUsers": "- userarn: $USER_ARN\n  username: $USERNAME\n  groups:\n  - system:masters"
  }
}
EOF

# Use curl with AWS SigV4 signing
# Note: This requires aws-cli v2 with curl support or manual signing

# Get temporary credentials
AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
AWS_SESSION_TOKEN=$(aws configure get aws_session_token || echo "")

# Build the canonical request for SigV4
METHOD="PATCH"
SERVICE="eks"
HOST=$(echo $ENDPOINT | sed 's/.*:\/\///' | sed 's/\/.*//')
PATH="/api/v1/namespaces/kube-system/configmaps/aws-auth"
URL="$ENDPOINT$PATH"

echo "Patching ConfigMap at: $URL"

# Try using kubectl with --validate=false
# First, create the YAML
cat > /tmp/aws-auth-patch.yaml << EOF
data:
  mapUsers: |-
    - userarn: $USER_ARN
      username: $USERNAME
      groups:
        - system:masters
EOF

# Apply with validation disabled
echo "Attempting to patch aws-auth..."
kubectl patch configmap/aws-auth -n kube-system --type merge --patch-file /tmp/aws-auth-patch.yaml 2>&1

echo ""
echo "Testing access..."
kubectl get nodes
