$ErrorActionPreference = "Stop"

$ClusterName = "zoidbot-eks"
$NodeGroupName = "zoidbot-eks-node-group"
$NodeRoleArn = "arn:aws:iam::422017356244:role/zoidbot-eks-node-role"
$Subnets = "subnet-029797aeb6cd6d69c", "subnet-04c42b1dbf2649b38"
$Region = "us-east-1"

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

Write-Host "--- Recreating Node Group ---"

# 1. Delete failed Node Group
if (Test-EksResource -Command "aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName --region $Region" -Name $NodeGroupName) {
    Write-Host "Deleting failed Node Group..."
    aws eks delete-nodegroup --cluster-name $ClusterName --nodegroup-name $NodeGroupName --region $Region
    
    Write-Host "Waiting for Node Group deletion..."
    aws eks wait nodegroup-deleted --cluster-name $ClusterName --nodegroup-name $NodeGroupName --region $Region
    Write-Host "✓ Node Group deleted."
} else {
    Write-Host "✓ Node Group already deleted."
}

# 2. Create new Node Group
Write-Host "Creating new Node Group..."
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
