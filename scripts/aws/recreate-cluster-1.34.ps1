$ErrorActionPreference = "Stop"

$ClusterName = "zoidbot-eks"
$Region = "us-east-1"
$NodeGroupName = "zoidbot-eks-node-group"
$NodeRoleArn = "arn:aws:iam::422017356244:role/zoidbot-eks-node-role"
$Subnets = "subnet-029797aeb6cd6d69c", "subnet-04c42b1dbf2649b38"

# Function to check if resource exists
function Test-EksResource {
    param($Command, $Name)
    try {
        Invoke-Expression $Command | Out-Null
        return $true
    } catch {
        if ($_.Exception.Message -match "ResourceNotFoundException") {
            return $false
        }
        throw $_
    }
}

Write-Host "--- Step 1: Waiting for Node Group Deletion ---"
while (Test-EksResource -Command "aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName --region $Region" -Name $NodeGroupName) {
    Write-Host "Node Group is still deleting... waiting 30s"
    Start-Sleep -Seconds 30
}
Write-Host "✓ Node Group deleted."

Write-Host "--- Step 2: Deleting Cluster ---"
if (Test-EksResource -Command "aws eks describe-cluster --name $ClusterName --region $Region" -Name $ClusterName) {
    Write-Host "Deleting cluster..."
    aws eks delete-cluster --name $ClusterName --region $Region
    
    Write-Host "Waiting for cluster deletion..."
    aws eks wait cluster-deleted --name $ClusterName --region $Region
    Write-Host "✓ Cluster deleted."
} else {
    Write-Host "✓ Cluster already deleted."
}

Write-Host "--- Step 3: Creating Cluster (v1.34) ---"
Write-Host "Creating cluster from config..."
aws eks create-cluster --cli-input-json file://cluster-config.json --region $Region

Write-Host "Waiting for cluster to be ACTIVE (approx 10-15m)..."
aws eks wait cluster-active --name $ClusterName --region $Region
Write-Host "✓ Cluster is ACTIVE."

Write-Host "--- Step 4: Creating Node Group ---"
aws eks create-nodegroup `
    --cluster-name $ClusterName `
    --nodegroup-name $NodeGroupName `
    --scaling-config minSize=2,maxSize=3,desiredSize=2 `
    --subnets $Subnets `
    --node-role $NodeRoleArn `
    --instance-types t3.small `
    --region $Region

Write-Host "Waiting for Node Group to be ACTIVE (approx 5-10m)..."
aws eks wait nodegroup-active --cluster-name $ClusterName --nodegroup-name $NodeGroupName --region $Region
Write-Host "✓ Node Group is ACTIVE."

Write-Host "--- Step 5: Updating Kubeconfig ---"
aws eks update-kubeconfig --name $ClusterName --region $Region
Write-Host "✓ Kubeconfig updated."

Write-Host "DONE! Cluster recreated with v1.34."
