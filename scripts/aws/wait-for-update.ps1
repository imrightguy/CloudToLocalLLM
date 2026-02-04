$ClusterName = "zoidbot-eks"
$UpdateId = "782e569b-5086-31a6-bb8b-d6a51e8e4055"
$Region = "us-east-1"

Write-Host "Waiting for update $UpdateId to complete..."

do {
    Start-Sleep -Seconds 10
    $UpdateStatus = aws eks describe-update --name $ClusterName --update-id $UpdateId --region $Region --query "update.status" --output text
    Write-Host "Update status: $UpdateStatus"
} while ($UpdateStatus -eq "InProgress")

if ($UpdateStatus -eq "Successful") {
    Write-Host "Update successful."
    Write-Host "Verifying access config..."
    aws eks describe-cluster --name $ClusterName --region $Region --query "cluster.accessConfig"
    
    Write-Host "Running grant access script..."
    ./scripts/aws/grant-github-actions-access.ps1
} else {
    Write-Host "Update failed with status: $UpdateStatus"
    exit 1
}
