$ErrorActionPreference = "Stop"

$VpcId = "vpc-03628f637e676764b"
$PublicSubnetId = "subnet-0f86ad9e6835c66ad"
$PrivateSubnetIds = @("subnet-029797aeb6cd6d69c", "subnet-04c42b1dbf2649b38")
$Region = "us-east-1"

Write-Host "--- Fixing EKS Networking ---"

# 1. Allocate Elastic IP
Write-Host "Allocating Elastic IP..."
$eip = aws ec2 allocate-address --domain vpc --region $Region | ConvertFrom-Json
$allocationId = $eip.AllocationId
Write-Host "✓ Allocated EIP: $allocationId"

# 2. Create NAT Gateway
Write-Host "Creating NAT Gateway in $PublicSubnetId..."
$natGw = aws ec2 create-nat-gateway --subnet-id $PublicSubnetId --allocation-id $allocationId --region $Region | ConvertFrom-Json
$natGwId = $natGw.NatGateway.NatGatewayId
Write-Host "✓ Created NAT Gateway: $natGwId"

Write-Host "Waiting for NAT Gateway to be available (approx 3-5m)..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $natGwId --region $Region
Write-Host "✓ NAT Gateway is available."

# 3. Create Route Table
Write-Host "Creating Private Route Table..."
$rt = aws ec2 create-route-table --vpc-id $VpcId --region $Region | ConvertFrom-Json
$rtId = $rt.RouteTable.RouteTableId
aws ec2 create-tags --resources $rtId --tags Key=Name,Value=zoidbot-eks-private-rt --region $Region
Write-Host "✓ Created Route Table: $rtId"

# 4. Add Route to NAT Gateway
Write-Host "Adding route to NAT Gateway..."
aws ec2 create-route --route-table-id $rtId --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $natGwId --region $Region
Write-Host "✓ Route added."

# 5. Associate Private Subnets
foreach ($subnetId in $PrivateSubnetIds) {
    Write-Host "Associating $subnetId with Route Table..."
    aws ec2 associate-route-table --route-table-id $rtId --subnet-id $subnetId --region $Region
}
Write-Host "✓ Subnets associated."

Write-Host "Networking fixed. Nodes should now be able to reach the internet/EKS API."
