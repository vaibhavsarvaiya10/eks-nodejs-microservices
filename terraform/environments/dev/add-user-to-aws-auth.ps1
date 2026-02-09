# PowerShell script to add IAM user to aws-auth ConfigMap

# Get the cluster info
$clusterName = "eks-dev-cluster"
$region = "ap-south-1"
$userArn = "arn:aws:iam::***REMOVED***:user/terraform"

# Update kubeconfig
Write-Host "Updating kubeconfig..."
aws eks update-kubeconfig --region $region --name $clusterName

# Create the YAML for aws-auth ConfigMap
$yaml = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapUsers: |
    - userarn: $userArn
      username: terraform
      groups:
        - system:masters
"@

# Save to temp file
$tempFile = "$env:TEMP\aws-auth.yaml"
$yaml | Out-File -FilePath $tempFile -Encoding UTF8

# Apply the ConfigMap
Write-Host "Applying aws-auth ConfigMap..."
$output = kubectl apply -f $tempFile 2>&1
Write-Host $output

# Clean up
Remove-Item $tempFile

Write-Host "aws-auth ConfigMap updated successfully!"
Write-Host "Testing access..."
kubectl get nodes
