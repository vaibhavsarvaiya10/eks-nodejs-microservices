param(
    [string]$cluster_name = "eks-dev-cluster",
    [string]$region = "ap-south-1",
    [string]$user_arn = "arn:aws:iam::***REMOVED***:user/terraform"
)

$ErrorActionPreference = "Stop"

Write-Host "Configuring aws-auth for cluster: $cluster_name"

# Wait for cluster to be fully active
Write-Host "Waiting for cluster to be ready..."
$maxRetries = 30
$retryCount = 0
while ($retryCount -lt $maxRetries) {
    try {
        $status = aws eks describe-cluster --region $region --name $cluster_name --query 'cluster.status' --output text
        if ($status -eq "ACTIVE") {
            Write-Host "Cluster is ACTIVE"
            break
        }
        $retryCount++
        Write-Host "Cluster status: $status, waiting... ($retryCount/$maxRetries)"
        Start-Sleep -Seconds 10
    }
    catch {
        $retryCount++
        Write-Host "Cluster not ready yet, retrying... ($retryCount/$maxRetries)"
        Start-Sleep -Seconds 10
    }
}

if ($status -ne "ACTIVE") {
    throw "Cluster did not become active after 5 minutes"
}

# Update kubeconfig
Write-Host "Updating kubeconfig..."
aws eks update-kubeconfig --region $region --name $cluster_name

# Wait a bit for kubeconfig to be usable
Start-Sleep -Seconds 5

# Create the aws-auth ConfigMap YAML content
$awsAuthYaml = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapUsers: |
    - userarn: $user_arn
      username: terraform
      groups:
        - system:masters
"@

# Save to temp file
$tempFile = "$env:TEMP\aws-auth-$([guid]::NewGuid()).yaml"
$awsAuthYaml | Out-File -FilePath $tempFile -Encoding UTF8

# Try to apply with retries
Write-Host "Applying aws-auth ConfigMap..."
$applyRetries = 5
$applyCount = 0

while ($applyCount -lt $applyRetries) {
    try {
        # Try with insecure-skip-tls-verify first (for initial bootstrap)
        $output = kubectl apply -f $tempFile --insecure-skip-tls-verify=true 2>&1
        Write-Host $output
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully applied aws-auth ConfigMap"
            break
        }
    }
    catch {
        $applyCount++
        Write-Host "Apply failed, retrying... ($applyCount/$applyRetries)"
        Start-Sleep -Seconds 5
    }
}

# Clean up
Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

# Verify the ConfigMap was created
Write-Host "Verifying aws-auth ConfigMap..."
$verifyCount = 0
while ($verifyCount -lt 5) {
    try {
        $cm = kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapUsers}' 2>&1
        if ($cm) {
            Write-Host "aws-auth ConfigMap verified successfully"
            Write-Host "ConfigMap content:"
            Write-Host $cm
            break
        }
    }
    catch {
        $verifyCount++
        Write-Host "Verification attempt $verifyCount/5..."
        Start-Sleep -Seconds 5
    }
}

# Final test
Write-Host "Testing kubectl access..."
$nodeOutput = kubectl get nodes 2>&1
Write-Host $nodeOutput

Write-Host "Configuration complete!"
