# AWS EKS Cluster Setup Script
# Creates VPC, subnets, security groups, EKS cluster, and node group
# This script uses CloudFormation for Infrastructure as Code

param(
    [string]$ClusterName = "zoidbot-eks",
    [string]$AwsRegion = "us-east-1",
    [string]$AwsAccountId = "422017356244",
    [string]$NodeInstanceType = "t3.small",
    [int]$MinNodes = 2,
    [int]$MaxNodes = 3,
    [int]$DesiredNodes = 2,
    [string]$KubernetesVersion = "1.34"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "AWS EKS Cluster Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify AWS CLI is configured
Write-Host "Step 1: Verifying AWS CLI configuration..." -ForegroundColor Yellow

try {
    $identity = aws sts get-caller-identity --region $AwsRegion | ConvertFrom-Json
    Write-Host "✓ AWS CLI configured" -ForegroundColor Green
    Write-Host "  Account ID: $($identity.Account)" -ForegroundColor Gray
    Write-Host "  Region: $AwsRegion" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Error verifying AWS CLI: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Create CloudFormation template for VPC and networking
Write-Host "Step 2: Creating CloudFormation template for VPC and networking..." -ForegroundColor Yellow

$vpcTemplate = @{
    AWSTemplateFormatVersion = "2010-09-09"
    Description = "VPC and networking infrastructure for EKS cluster"
    Parameters = @{
        ClusterName = @{
            Type = "String"
            Default = $ClusterName
            Description = "Name of the EKS cluster"
        }
    }
    Resources = @{
        EksVpc = @{
            Type = "AWS::EC2::VPC"
            Properties = @{
                CidrBlock = "10.0.0.0/16"
                EnableDnsHostnames = $true
                EnableDnsSupport = $true
                Tags = @(
                    @{ Key = "Name"; Value = "$ClusterName-vpc" },
                    @{ Key = "kubernetes.io/cluster/$ClusterName"; Value = "shared" }
                )
            }
        }
        PublicSubnet1 = @{
            Type = "AWS::EC2::Subnet"
            Properties = @{
                VpcId = @{ Ref = "EksVpc" }
                CidrBlock = "10.0.1.0/24"
                AvailabilityZone = @{ "Fn::Select" = @(0, @{ "Fn::GetAZs" = "" }) }
                MapPublicIpOnLaunch = $true
                Tags = @(
                    @{ Key = "Name"; Value = "$ClusterName-public-subnet-1" },
                    @{ Key = "kubernetes.io/cluster/$ClusterName"; Value = "shared" },
                    @{ Key = "kubernetes.io/role/elb"; Value = "1" }
                )
            }
        }
        PublicSubnet2 = @{
            Type = "AWS::EC2::Subnet"
            Properties = @{
                VpcId = @{ Ref = "EksVpc" }
                CidrBlock = "10.0.2.0/24"
                AvailabilityZone = @{ "Fn::Select" = @(1, @{ "Fn::GetAZs" = "" }) }
                MapPublicIpOnLaunch = $true
                Tags = @(
                    @{ Key = "Name"; Value = "$ClusterName-public-subnet-2" },
                    @{ Key = "kubernetes.io/cluster/$ClusterName"; Value = "shared" },
                    @{ Key = "kubernetes.io/role/elb"; Value = "1" }
                )
            }
        }
        PrivateSubnet1 = @{
            Type = "AWS::EC2::Subnet"
            Properties = @{
                VpcId = @{ Ref = "EksVpc" }
                CidrBlock = "10.0.11.0/24"
                AvailabilityZone = @{ "Fn::Select" = @(0, @{ "Fn::GetAZs" = "" }) }
                Tags = @(
                    @{ Key = "Name"; Value = "$ClusterName-private-subnet-1" },
                    @{ Key = "kubernetes.io/cluster/$ClusterName"; Value = "shared" },
                    @{ Key = "kubernetes.io/role/internal-elb"; Value = "1" }
                )
            }
        }
        PrivateSubnet2 = @{
            Type = "AWS::EC2::Subnet"
            Properties = @{
                VpcId = @{ Ref = "EksVpc" }
                CidrBlock = "10.0.12.0/24"
                AvailabilityZone = @{ "Fn::Select" = @(1, @{ "Fn::GetAZs" = "" }) }
                Tags = @(
                    @{ Key = "Name"; Value = "$ClusterName-private-subnet-2" },
                    @{ Key = "kubernetes.io/cluster/$ClusterName"; Value = "shared" },
                    @{ Key = "kubernetes.io/role/internal-elb"; Value = "1" }
                )
            }
        }
        InternetGateway = @{
            Type = "AWS::EC2::InternetGateway"
            Properties = @{
                Tags = @(
                    @{ Key = "Name"; Value = "$ClusterName-igw" }
                )
            }
        }
        AttachGateway = @{
            Type = "AWS::EC2::VPCGatewayAttachment"
            Properties = @{
                VpcId = @{ Ref = "EksVpc" }
                InternetGatewayId = @{ Ref = "InternetGateway" }
            }
        }
        PublicRouteTable = @{
            Type = "AWS::EC2::RouteTable"
            Properties = @{
                VpcId = @{ Ref = "EksVpc" }
                Tags = @(
                    @{ Key = "Name"; Value = "$ClusterName-public-rt" }
                )
            }
        }
        PublicRoute = @{
            Type = "AWS::EC2::Route"
            DependsOn = "AttachGateway"
            Properties = @{
                RouteTableId = @{ Ref = "PublicRouteTable" }
                DestinationCidrBlock = "0.0.0.0/0"
                GatewayId = @{ Ref = "InternetGateway" }
            }
        }
        PublicSubnet1RouteTableAssociation = @{
            Type = "AWS::EC2::SubnetRouteTableAssociation"
            Properties = @{
                SubnetId = @{ Ref = "PublicSubnet1" }
                RouteTableId = @{ Ref = "PublicRouteTable" }
            }
        }
        PublicSubnet2RouteTableAssociation = @{
            Type = "AWS::EC2::SubnetRouteTableAssociation"
            Properties = @{
                SubnetId = @{ Ref = "PublicSubnet2" }
                RouteTableId = @{ Ref = "PublicRouteTable" }
            }
        }
        EksSecurityGroup = @{
            Type = "AWS::EC2::SecurityGroup"
            Properties = @{
                GroupDescription = "Security group for EKS cluster"
                VpcId = @{ Ref = "EksVpc" }
                SecurityGroupIngress = @(
                    @{
                        IpProtocol = "tcp"
                        FromPort = 443
                        ToPort = 443
                        CidrIp = "0.0.0.0/0"
                        Description = "Allow HTTPS from anywhere"
                    }
                )
                SecurityGroupEgress = @(
                    @{
                        IpProtocol = "-1"
                        CidrIp = "0.0.0.0/0"
                        Description = "Allow all outbound traffic"
                    }
                )
                Tags = @(
                    @{ Key = "Name"; Value = "$ClusterName-sg" }
                )
            }
        }
        NodeSecurityGroup = @{
            Type = "AWS::EC2::SecurityGroup"
            Properties = @{
                GroupDescription = "Security group for EKS nodes"
                VpcId = @{ Ref = "EksVpc" }
                SecurityGroupIngress = @(
                    @{
                        IpProtocol = "tcp"
                        FromPort = 1025
                        ToPort = 65535
                        SourceSecurityGroupId = @{ Ref = "EksSecurityGroup" }
                        Description = "Allow pod communication"
                    },
                    @{
                        IpProtocol = "tcp"
                        FromPort = 443
                        ToPort = 443
                        CidrIp = "0.0.0.0/0"
                        Description = "Allow HTTPS"
                    }
                )
                SecurityGroupEgress = @(
                    @{
                        IpProtocol = "-1"
                        CidrIp = "0.0.0.0/0"
                        Description = "Allow all outbound traffic"
                    }
                )
                Tags = @(
                    @{ Key = "Name"; Value = "$ClusterName-node-sg" }
                )
            }
        }
    }
    Outputs = @{
        VpcId = @{
            Value = @{ Ref = "EksVpc" }
            Description = "VPC ID"
        }
        PublicSubnet1Id = @{
            Value = @{ Ref = "PublicSubnet1" }
            Description = "Public Subnet 1 ID"
        }
        PublicSubnet2Id = @{
            Value = @{ Ref = "PublicSubnet2" }
            Description = "Public Subnet 2 ID"
        }
        PrivateSubnet1Id = @{
            Value = @{ Ref = "PrivateSubnet1" }
            Description = "Private Subnet 1 ID"
        }
        PrivateSubnet2Id = @{
            Value = @{ Ref = "PrivateSubnet2" }
            Description = "Private Subnet 2 ID"
        }
        EksSecurityGroupId = @{
            Value = @{ Ref = "EksSecurityGroup" }
            Description = "EKS Security Group ID"
        }
        NodeSecurityGroupId = @{
            Value = @{ Ref = "NodeSecurityGroup" }
            Description = "Node Security Group ID"
        }
    }
}

$vpcTemplatePath = "$env:TEMP\eks-vpc-template.json"
$vpcTemplate | ConvertTo-Json -Depth 10 | Out-File -FilePath $vpcTemplatePath -Encoding UTF8

Write-Host "✓ VPC template created" -ForegroundColor Green

Write-Host ""

# Step 3: Deploy VPC stack
Write-Host "Step 3: Deploying VPC stack..." -ForegroundColor Yellow

$vpcStackName = "$ClusterName-vpc-stack"

try {
    # Check if stack already exists
    $existingStack = aws cloudformation describe-stacks --stack-name $vpcStackName --region $AwsRegion 2>$null
    
    if ($existingStack) {
        Write-Host "✓ VPC stack already exists" -ForegroundColor Green
    }
    else {
        Write-Host "  Creating VPC stack..." -ForegroundColor Gray
        aws cloudformation create-stack `
            --stack-name $vpcStackName `
            --template-body "file://$vpcTemplatePath" `
            --parameters "ParameterKey=ClusterName,ParameterValue=$ClusterName" `
            --region $AwsRegion
        
        Write-Host "  Waiting for stack creation..." -ForegroundColor Gray
        aws cloudformation wait stack-create-complete `
            --stack-name $vpcStackName `
            --region $AwsRegion
        
        Write-Host "✓ VPC stack created" -ForegroundColor Green
    }
}
catch {
    Write-Host "✗ Error deploying VPC stack: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 4: Get VPC and subnet IDs from stack
Write-Host "Step 4: Retrieving VPC and subnet information..." -ForegroundColor Yellow

try {
    $stackOutputs = aws cloudformation describe-stacks `
        --stack-name $vpcStackName `
        --region $AwsRegion `
        --query 'Stacks[0].Outputs' | ConvertFrom-Json
    
    $vpcId = ($stackOutputs | Where-Object { $_.OutputKey -eq "VpcId" }).OutputValue
    $publicSubnet1 = ($stackOutputs | Where-Object { $_.OutputKey -eq "PublicSubnet1Id" }).OutputValue
    $publicSubnet2 = ($stackOutputs | Where-Object { $_.OutputKey -eq "PublicSubnet2Id" }).OutputValue
    $privateSubnet1 = ($stackOutputs | Where-Object { $_.OutputKey -eq "PrivateSubnet1Id" }).OutputValue
    $privateSubnet2 = ($stackOutputs | Where-Object { $_.OutputKey -eq "PrivateSubnet2Id" }).OutputValue
    $eksSecurityGroup = ($stackOutputs | Where-Object { $_.OutputKey -eq "EksSecurityGroupId" }).OutputValue
    $nodeSecurityGroup = ($stackOutputs | Where-Object { $_.OutputKey -eq "NodeSecurityGroupId" }).OutputValue
    
    Write-Host "✓ VPC information retrieved" -ForegroundColor Green
    Write-Host "  VPC ID: $vpcId" -ForegroundColor Gray
    Write-Host "  Public Subnets: $publicSubnet1, $publicSubnet2" -ForegroundColor Gray
    Write-Host "  Private Subnets: $privateSubnet1, $privateSubnet2" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Error retrieving VPC information: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 5: Create EKS cluster role
Write-Host "Step 5: Creating EKS cluster role..." -ForegroundColor Yellow

$clusterRoleName = "$ClusterName-cluster-role"

try {
    $trustPolicy = @{
        Version = "2012-10-17"
        Statement = @(
            @{
                Effect = "Allow"
                Principal = @{
                    Service = "eks.amazonaws.com"
                }
                Action = "sts:AssumeRole"
            }
        )
    } | ConvertTo-Json -Depth 10
    
    $trustPolicyPath = "$env:TEMP\eks-trust-policy.json"
    $trustPolicy | Out-File -FilePath $trustPolicyPath -Encoding UTF8
    
    # Check if role already exists
    $existingRole = aws iam get-role --role-name $clusterRoleName 2>$null
    
    if ($existingRole) {
        Write-Host "✓ EKS cluster role already exists" -ForegroundColor Green
    }
    else {
        Write-Host "  Creating EKS cluster role..." -ForegroundColor Gray
        aws iam create-role `
            --role-name $clusterRoleName `
            --assume-role-policy-document "file://$trustPolicyPath" `
            --description "Role for EKS cluster"
        
        # Attach policy
        aws iam attach-role-policy `
            --role-name $clusterRoleName `
            --policy-arn "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
        
        Write-Host "✓ EKS cluster role created" -ForegroundColor Green
    }
    
    $clusterRoleArn = (aws iam get-role --role-name $clusterRoleName --query 'Role.Arn' --output text)
}
catch {
    Write-Host "✗ Error creating EKS cluster role: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 6: Create EKS cluster
Write-Host "Step 6: Creating EKS cluster..." -ForegroundColor Yellow

try {
    # Check if cluster already exists
    $existingCluster = aws eks describe-cluster --name $ClusterName --region $AwsRegion 2>$null
    
    if ($existingCluster) {
        Write-Host "✓ EKS cluster already exists" -ForegroundColor Green
    }
    else {
        Write-Host "  Creating EKS cluster..." -ForegroundColor Gray
        aws eks create-cluster `
            --name $ClusterName `
            --version $KubernetesVersion `
            --role-arn $clusterRoleArn `
            --resources-vpc-config "subnetIds=$publicSubnet1,$publicSubnet2,$privateSubnet1,$privateSubnet2,securityGroupIds=$eksSecurityGroup" `
            --region $AwsRegion `
            --logging '{"clusterLogging":[{"enabled":true,"types":["api","audit","authenticator","controllerManager","scheduler"]}]}'
        
        Write-Host "  Waiting for cluster creation (this may take 10-15 minutes)..." -ForegroundColor Gray
        aws eks wait cluster-active `
            --name $ClusterName `
            --region $AwsRegion
        
        Write-Host "✓ EKS cluster created" -ForegroundColor Green
    }
}
catch {
    Write-Host "✗ Error creating EKS cluster: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 7: Create node group role
Write-Host "Step 7: Creating node group role..." -ForegroundColor Yellow

$nodeRoleName = "$ClusterName-node-role"

try {
    $nodeTrustPolicy = @{
        Version = "2012-10-17"
        Statement = @(
            @{
                Effect = "Allow"
                Principal = @{
                    Service = "ec2.amazonaws.com"
                }
                Action = "sts:AssumeRole"
            }
        )
    } | ConvertTo-Json -Depth 10
    
    $nodeTrustPolicyPath = "$env:TEMP\eks-node-trust-policy.json"
    $nodeTrustPolicy | Out-File -FilePath $nodeTrustPolicyPath -Encoding UTF8
    
    # Check if role already exists
    $existingNodeRole = aws iam get-role --role-name $nodeRoleName 2>$null
    
    if ($existingNodeRole) {
        Write-Host "✓ Node group role already exists" -ForegroundColor Green
    }
    else {
        Write-Host "  Creating node group role..." -ForegroundColor Gray
        aws iam create-role `
            --role-name $nodeRoleName `
            --assume-role-policy-document "file://$nodeTrustPolicyPath" `
            --description "Role for EKS node group"
        
        # Attach policies
        $nodePolicies = @(
            "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
            "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
            "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        )
        
        foreach ($policy in $nodePolicies) {
            aws iam attach-role-policy `
                --role-name $nodeRoleName `
                --policy-arn $policy
        }
        
        Write-Host "✓ Node group role created" -ForegroundColor Green
    }
    
    $nodeRoleArn = (aws iam get-role --role-name $nodeRoleName --query 'Role.Arn' --output text)
}
catch {
    Write-Host "✗ Error creating node group role: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 8: Create node group
Write-Host "Step 8: Creating node group..." -ForegroundColor Yellow

$nodeGroupName = "$ClusterName-node-group"

try {
    # Check if node group already exists
    $existingNodeGroup = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $nodeGroupName --region $AwsRegion 2>$null
    
    if ($existingNodeGroup) {
        Write-Host "✓ Node group already exists" -ForegroundColor Green
    }
    else {
        Write-Host "  Creating node group..." -ForegroundColor Gray
        aws eks create-nodegroup `
            --cluster-name $ClusterName `
            --nodegroup-name $nodeGroupName `
            --scaling-config "minSize=$MinNodes,maxSize=$MaxNodes,desiredSize=$DesiredNodes" `
            --subnets $privateSubnet1 $privateSubnet2 `
            --node-role $nodeRoleArn `
            --instance-types $NodeInstanceType `
            --region $AwsRegion
        
        Write-Host "  Waiting for node group creation (this may take 5-10 minutes)..." -ForegroundColor Gray
        aws eks wait nodegroup-active `
            --cluster-name $ClusterName `
            --nodegroup-name $nodeGroupName `
            --region $AwsRegion
        
        Write-Host "✓ Node group created" -ForegroundColor Green
    }
}
catch {
    Write-Host "✗ Error creating node group: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 9: Configure kubectl
Write-Host "Step 9: Configuring kubectl..." -ForegroundColor Yellow

try {
    aws eks update-kubeconfig `
        --name $ClusterName `
        --region $AwsRegion
    
    Write-Host "✓ kubectl configured" -ForegroundColor Green
}
catch {
    Write-Host "✗ Error configuring kubectl: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 10: Verify cluster
Write-Host "Step 10: Verifying cluster..." -ForegroundColor Yellow

try {
    $clusterInfo = aws eks describe-cluster --name $ClusterName --region $AwsRegion | ConvertFrom-Json
    $clusterStatus = $clusterInfo.cluster.status
    
    Write-Host "✓ Cluster verified" -ForegroundColor Green
    Write-Host "  Cluster Name: $ClusterName" -ForegroundColor Gray
    Write-Host "  Status: $clusterStatus" -ForegroundColor Gray
    Write-Host "  Kubernetes Version: $($clusterInfo.cluster.version)" -ForegroundColor Gray
    Write-Host "  Endpoint: $($clusterInfo.cluster.endpoint)" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Error verifying cluster: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 11: Save configuration
Write-Host "Step 11: Saving configuration..." -ForegroundColor Yellow

try {
    $config = @{
        ClusterName = $ClusterName
        AwsRegion = $AwsRegion
        AwsAccountId = $AwsAccountId
        VpcId = $vpcId
        PublicSubnets = @($publicSubnet1, $publicSubnet2)
        PrivateSubnets = @($privateSubnet1, $privateSubnet2)
        EksSecurityGroup = $eksSecurityGroup
        NodeSecurityGroup = $nodeSecurityGroup
        ClusterRoleArn = $clusterRoleArn
        NodeRoleArn = $nodeRoleArn
        NodeInstanceType = $NodeInstanceType
        MinNodes = $MinNodes
        MaxNodes = $MaxNodes
        DesiredNodes = $DesiredNodes
        KubernetesVersion = $KubernetesVersion
        SetupDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $configPath = "scripts/aws/eks-cluster-config.json"
    $config | ConvertTo-Json | Out-File -FilePath $configPath -Encoding UTF8
    Write-Host "✓ Configuration saved to $configPath" -ForegroundColor Green
}
catch {
    Write-Host "✗ Error saving configuration: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "✓ AWS EKS Cluster Setup Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Cluster Configuration:" -ForegroundColor Cyan
Write-Host "  Cluster Name: $ClusterName" -ForegroundColor White
Write-Host "  AWS Region: $AwsRegion" -ForegroundColor White
Write-Host "  VPC ID: $vpcId" -ForegroundColor White
Write-Host "  Node Instance Type: $NodeInstanceType" -ForegroundColor White
Write-Host "  Desired Nodes: $DesiredNodes" -ForegroundColor White
Write-Host "  Kubernetes Version: $KubernetesVersion" -ForegroundColor White
Write-Host "  Estimated Monthly Cost: ~$75 (2x t3.small + services)" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Verify cluster nodes: kubectl get nodes" -ForegroundColor White
Write-Host "2. Deploy applications to the cluster" -ForegroundColor White
Write-Host "3. Configure monitoring and logging" -ForegroundColor White
Write-Host ""
