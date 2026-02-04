param(
    [string]$UserName = "zoidbot-admin"
)

$ErrorActionPreference = "Stop"

Write-Host "Creating IAM user: $UserName"

# Create User
try {
    aws iam create-user --user-name $UserName
    Write-Host "✓ Created user: $UserName" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -match "EntityAlreadyExists") {
        Write-Host "✓ User $UserName already exists" -ForegroundColor Yellow
    } else {
        Write-Error "Failed to create user: $_"
    }
}

# Attach Admin Policy
try {
    aws iam attach-user-policy --user-name $UserName --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
    Write-Host "✓ Attached AdministratorAccess policy to $UserName" -ForegroundColor Green
} catch {
    Write-Error "Failed to attach policy: $_"
}

# Create Access Key
Write-Host "Creating access key..."
try {
    $keyJson = aws iam create-access-key --user-name $UserName
    $key = $keyJson | ConvertFrom-Json
    
    $accessKeyId = $key.AccessKey.AccessKeyId
    $secretAccessKey = $key.AccessKey.SecretAccessKey

    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "CREDENTIALS CREATED FOR $UserName" -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "Access Key ID:     $accessKeyId" -ForegroundColor White
    Write-Host "Secret Access Key: $secretAccessKey" -ForegroundColor White
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To configure AWS CLI with these credentials, run:" -ForegroundColor Yellow
    Write-Host "aws configure --profile $UserName" -ForegroundColor White
    Write-Host ""
    Write-Host "Or set environment variables:" -ForegroundColor Yellow
    Write-Host "`$env:AWS_ACCESS_KEY_ID='$accessKeyId'" -ForegroundColor Gray
    Write-Host "`$env:AWS_SECRET_ACCESS_KEY='$secretAccessKey'" -ForegroundColor Gray
} catch {
    Write-Error "Failed to create access key: $_"
}
