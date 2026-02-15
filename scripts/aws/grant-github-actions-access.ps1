$ClusterName = "zoidbot-eks"
$Region = "us-east-1"
$RoleArn = "arn:aws:iam::422017356244:role/github-actions-role"

Write-Host "Granting access to $RoleArn for cluster $ClusterName..."

# Create Access Entry
aws eks create-access-entry `
    --cluster-name $ClusterName `
    --principal-arn $RoleArn `
    --region $Region

# Associate Access Policy
aws eks associate-access-policy `
    --cluster-name $ClusterName `
    --principal-arn $RoleArn `
    --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy `
    --access-scope type=cluster `
    --region $Region

Write-Host "Access granted successfully."
