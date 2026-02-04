$ClusterName = "zoidbot-eks"
$Region = "us-east-1"

Write-Host "Updating cluster authentication mode to API_AND_CONFIG_MAP..."

aws eks update-cluster-config `
    --name $ClusterName `
    --region $Region `
    --access-config authenticationMode=API_AND_CONFIG_MAP

Write-Host "Update initiated. Waiting for update to complete..."

# Wait for update to complete
do {
    Start-Sleep -Seconds 10
    $Status = aws eks describe-cluster --name $ClusterName --region $Region --query "cluster.status" --output text
    Write-Host "Cluster status: $Status"
} while ($Status -eq "UPDATING")

Write-Host "Update completed. Verifying access config..."
aws eks describe-cluster --name $ClusterName --region $Region --query "cluster.accessConfig"

Write-Host "Running grant access script..."
./scripts/aws/grant-github-actions-access.ps1
