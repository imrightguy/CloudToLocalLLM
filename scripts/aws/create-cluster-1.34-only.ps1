$ErrorActionPreference = "Stop"

$ClusterName = "zoidbot-eks"
$Region = "us-east-1"
$NodeGroupName = "zoidbot-eks-node-group"
$NodeRoleArn = "arn:aws:iam::422017356244:role/zoidbot-eks-node-role"
$Subnets = "subnet-029797aeb6cd6d69c", "subnet-04c42b1dbf2649b38"

Write-Host "--- Creating Cluster (v1.34) ---"
Write-Host "Creating cluster from config..."
try {
    aws eks create-cluster --cli-input-json file://cluster-config.json --region $Region
} catch {
    Write-Warning "Cluster creation command failed. Checking if it's already creating..."
    $status = aws eks describe-cluster --name $ClusterName --region $Region --query "cluster.status" --output text
    if ($status -eq "CREATING" -or $status -eq "ACTIVE") {
        Write-Host "Cluster is already $status."
    } else {
        throw $_
    }
}

Write-Host "Waiting for cluster to be ACTIVE (approx 10-15m)..."
aws eks wait cluster-active --name $ClusterName --region $Region
Write-Host "✓ Cluster is ACTIVE."

Write-Host "--- Creating Node Group ---"
try {
    aws eks create-nodegroup `
        --cluster-name $ClusterName `
        --nodegroup-name $NodeGroupName `
        --scaling-config minSize=2,maxSize=3,desiredSize=2 `
        --subnets $Subnets `
        --node-role $NodeRoleArn `
        --instance-types t3.small `
        --region $Region
} catch {
    Write-Warning "Node group creation command failed. Checking if it's already creating..."
    $ngStatus = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName --region $Region --query "nodegroup.status" --output text
    if ($ngStatus -eq "CREATING" -or $ngStatus -eq "ACTIVE") {
        Write-Host "Node Group is already $ngStatus."
    } else {
        throw $_
    }
}

Write-Host "Waiting for Node Group to be ACTIVE (approx 5-10m)..."
aws eks wait nodegroup-active --cluster-name $ClusterName --nodegroup-name $NodeGroupName --region $Region
Write-Host "✓ Node Group is ACTIVE."

Write-Host "--- Updating Kubeconfig ---"
aws eks update-kubeconfig --name $ClusterName --region $Region
Write-Host "✓ Kubeconfig updated."
