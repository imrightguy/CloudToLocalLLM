##############################################################################
# AWS EKS Final Deployment Verification Script (PowerShell)
#
# This script performs comprehensive final verification of the Zoidbot
# deployment on AWS EKS, including:
# - All services running on AWS EKS
# - Smoke tests on all endpoints
# - Cloudflare domain resolution
# - SSL/TLS certificate validation
# - End-to-end user flow testing
#
# Usage: .\final-deployment-verification.ps1 -Environment development
##############################################################################

param(
    [string]$Environment = "development",
    [string]$Namespace = "zoidbot",
    [string]$ClusterName = "zoidbot-eks",
    [string]$Region = "us-east-1",
    [switch]$SkipSSLVerification = $false
)

# Configuration
$Domains = @(
    "zoidbot.online",
    "app.zoidbot.online",
    "api.zoidbot.online",
    "auth.zoidbot.online"
)

$HealthEndpoints = @(
    "https://api.zoidbot.online/health",
    "https://app.zoidbot.online/health"
)

$SmokeTestEndpoints = @(
    @{ Url = "https://app.zoidbot.online"; Method = "GET"; ExpectedStatus = 200 },
    @{ Url = "https://api.zoidbot.online/health"; Method = "GET"; ExpectedStatus = 200 },
    @{ Url = "https://zoidbot.online"; Method = "GET"; ExpectedStatus = 200 }
)

# Counters
$Passed = 0
$Failed = 0
$Warnings = 0
$VerificationResults = @()

##############################################################################
# Helper Functions
##############################################################################

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[PASS] $Message" -ForegroundColor Green
    $script:Passed++
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
    $script:Failed++
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
    $script:Warnings++
}

function Add-VerificationResult {
    param(
        [string]$Category,
        [string]$Check,
        [string]$Status,
        [string]$Details
    )
    
    $script:VerificationResults += @{
        Category = $Category
        Check = $Check
        Status = $Status
        Details = $Details
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}

##############################################################################
# Verification Functions
##############################################################################

function Verify-AllServicesRunning {
    Write-Info "Verifying all services are running on AWS EKS..."
    
    try {
        # Check cluster connectivity
        $clusterInfo = kubectl cluster-info 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error-Custom "Cannot connect to EKS cluster"
            Add-VerificationResult "Services" "Cluster Connectivity" "FAILED" "Cannot connect to EKS cluster"
            return $false
        }
        Write-Success "Connected to EKS cluster"
        Add-VerificationResult "Services" "Cluster Connectivity" "PASSED" "Successfully connected to EKS cluster"
        
        # Check namespace
        $namespace = kubectl get namespace $Namespace 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error-Custom "Namespace '$Namespace' does not exist"
            Add-VerificationResult "Services" "Namespace Exists" "FAILED" "Namespace '$Namespace' does not exist"
            return $false
        }
        Write-Success "Namespace '$Namespace' exists"
        Add-VerificationResult "Services" "Namespace Exists" "PASSED" "Namespace '$Namespace' exists"
        
        # Check all pods are running
        $pods = kubectl get pods -n $Namespace -o json | ConvertFrom-Json
        $runningPods = $pods.items | Where-Object { $_.status.phase -eq "Running" }
        
        if ($runningPods.Count -eq 0) {
            Write-Error-Custom "No running pods found in namespace '$Namespace'"
            Add-VerificationResult "Services" "Running Pods" "FAILED" "No running pods found"
            return $false
        }
        
        Write-Success "Found $($runningPods.Count) running pod(s)"
        Add-VerificationResult "Services" "Running Pods" "PASSED" "Found $($runningPods.Count) running pod(s)"
        
        # Check all pods are ready
        $readyPods = $pods.items | Where-Object { 
            $_.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" }
        }
        
        if ($readyPods.Count -eq $pods.items.Count) {
            Write-Success "All $($pods.items.Count) pod(s) are ready"
            Add-VerificationResult "Services" "Pod Readiness" "PASSED" "All $($pods.items.Count) pod(s) are ready"
        }
        else {
            Write-Warning-Custom "Only $($readyPods.Count) of $($pods.items.Count) pod(s) are ready"
            Add-VerificationResult "Services" "Pod Readiness" "WARNING" "Only $($readyPods.Count) of $($pods.items.Count) pod(s) are ready"
        }
        
        # Check services
        $services = kubectl get svc -n $Namespace -o json | ConvertFrom-Json
        Write-Success "Found $($services.items.Count) service(s)"
        Add-VerificationResult "Services" "Services Count" "PASSED" "Found $($services.items.Count) service(s)"
        
        return $true
    }
    catch {
        Write-Error-Custom "Error verifying services: $_"
        Add-VerificationResult "Services" "Services Verification" "FAILED" "Error: $_"
        return $false
    }
}

function Verify-SmokeTests {
    Write-Info "Performing smoke tests on all endpoints..."
    
    $allPassed = $true
    
    foreach ($endpoint in $SmokeTestEndpoints) {
        try {
            $params = @{
                Uri = $endpoint.Url
                Method = $endpoint.Method
                TimeoutSec = 10
                SkipCertificateCheck = $SkipSSLVerification
                ErrorAction = "Stop"
            }
            
            $response = Invoke-WebRequest @params
            
            if ($response.StatusCode -eq $endpoint.ExpectedStatus) {
                Write-Success "Smoke test passed for $($endpoint.Url) (Status: $($response.StatusCode))"
                Add-VerificationResult "Smoke Tests" $endpoint.Url "PASSED" "Status: $($response.StatusCode)"
            }
            else {
                Write-Warning-Custom "Smoke test for $($endpoint.Url) returned unexpected status: $($response.StatusCode)"
                Add-VerificationResult "Smoke Tests" $endpoint.Url "WARNING" "Status: $($response.StatusCode), Expected: $($endpoint.ExpectedStatus)"
                $allPassed = $false
            }
        }
        catch {
            Write-Error-Custom "Smoke test failed for $($endpoint.Url): $_"
            Add-VerificationResult "Smoke Tests" $endpoint.Url "FAILED" "Error: $_"
            $allPassed = $false
        }
    }
    
    return $allPassed
}

function Verify-CloudflareDomains {
    Write-Info "Verifying all Cloudflare domains resolve correctly..."
    
    $allResolved = $true
    
    foreach ($domain in $Domains) {
        try {
            $result = Resolve-DnsName -Name $domain -ErrorAction Stop 2>$null
            if ($result) {
                $ip = $result.IPAddress | Select-Object -First 1
                Write-Success "Domain '$domain' resolves to $ip"
                Add-VerificationResult "DNS Resolution" $domain "PASSED" "Resolves to $ip"
            }
            else {
                Write-Error-Custom "Domain '$domain' resolved but no IP found"
                Add-VerificationResult "DNS Resolution" $domain "FAILED" "No IP found"
                $allResolved = $false
            }
        }
        catch {
            Write-Error-Custom "Failed to resolve domain '$domain': $_"
            Add-VerificationResult "DNS Resolution" $domain "FAILED" "Error: $_"
            $allResolved = $false
        }
    }
    
    return $allResolved
}

function Verify-SSLCertificates {
    Write-Info "Verifying SSL/TLS certificates are valid..."
    
    $allValid = $true
    
    foreach ($domain in $Domains) {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.Connect($domain, 443)
            
            $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false)
            $sslStream.AuthenticateAsClient($domain)
            
            $cert = $sslStream.RemoteCertificate
            
            if ($cert) {
                $certObj = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cert)
                $expiryDate = $certObj.NotAfter
                $daysUntilExpiry = ($expiryDate - (Get-Date)).Days
                
                if ($expiryDate -gt (Get-Date)) {
                    Write-Success "SSL certificate for '$domain' is valid (expires in $daysUntilExpiry days)"
                    Add-VerificationResult "SSL Certificates" $domain "PASSED" "Valid, expires in $daysUntilExpiry days"
                }
                else {
                    Write-Error-Custom "SSL certificate for '$domain' has expired"
                    Add-VerificationResult "SSL Certificates" $domain "FAILED" "Certificate expired"
                    $allValid = $false
                }
            }
            
            $sslStream.Close()
            $tcpClient.Close()
        }
        catch {
            Write-Error-Custom "Failed to verify SSL certificate for '$domain': $_"
            Add-VerificationResult "SSL Certificates" $domain "FAILED" "Error: $_"
            $allValid = $false
        }
    }
    
    return $allValid
}

function Verify-HealthEndpoints {
    Write-Info "Verifying health check endpoints..."
    
    $allHealthy = $true
    
    foreach ($endpoint in $HealthEndpoints) {
        try {
            $params = @{
                Uri = $endpoint
                Method = "GET"
                TimeoutSec = 10
                SkipCertificateCheck = $SkipSSLVerification
                ErrorAction = "Stop"
            }
            
            $response = Invoke-WebRequest @params
            
            if ($response.StatusCode -eq 200) {
                Write-Success "Health endpoint '$endpoint' is responding (Status: 200)"
                Add-VerificationResult "Health Checks" $endpoint "PASSED" "Status: 200"
            }
            else {
                Write-Warning-Custom "Health endpoint '$endpoint' returned status: $($response.StatusCode)"
                Add-VerificationResult "Health Checks" $endpoint "WARNING" "Status: $($response.StatusCode)"
                $allHealthy = $false
            }
        }
        catch {
            Write-Error-Custom "Health endpoint '$endpoint' is not responding: $_"
            Add-VerificationResult "Health Checks" $endpoint "FAILED" "Error: $_"
            $allHealthy = $false
        }
    }
    
    return $allHealthy
}

function Verify-EndToEndFlow {
    Write-Info "Performing end-to-end user flow testing..."
    
    try {
        # Step 1: Access main domain
        Write-Info "Step 1: Accessing main domain..."
        $mainResponse = Invoke-WebRequest -Uri "https://zoidbot.online" -SkipCertificateCheck:$SkipSSLVerification -TimeoutSec 10 -ErrorAction Stop
        Write-Success "Main domain is accessible"
        Add-VerificationResult "E2E Flow" "Main Domain Access" "PASSED" "Status: $($mainResponse.StatusCode)"
        
        # Step 2: Access app domain
        Write-Info "Step 2: Accessing app domain..."
        $appResponse = Invoke-WebRequest -Uri "https://app.zoidbot.online" -SkipCertificateCheck:$SkipSSLVerification -TimeoutSec 10 -ErrorAction Stop
        Write-Success "App domain is accessible"
        Add-VerificationResult "E2E Flow" "App Domain Access" "PASSED" "Status: $($appResponse.StatusCode)"
        
        # Step 3: Check API health
        Write-Info "Step 3: Checking API health..."
        $apiResponse = Invoke-WebRequest -Uri "https://api.zoidbot.online/health" -SkipCertificateCheck:$SkipSSLVerification -TimeoutSec 10 -ErrorAction Stop
        Write-Success "API health check passed"
        Add-VerificationResult "E2E Flow" "API Health Check" "PASSED" "Status: $($apiResponse.StatusCode)"
        
        # Step 4: Verify no errors in pod logs
        Write-Info "Step 4: Checking pod logs for errors..."
        $pods = kubectl get pods -n $Namespace -o jsonpath='{.items[*].metadata.name}'
        $errorCount = 0
        
        foreach ($pod in $pods -split '\s+') {
            if ([string]::IsNullOrEmpty($pod)) { continue }
            $logs = kubectl logs $pod -n $Namespace 2>$null
            $podErrors = ($logs | Select-String -Pattern "error|exception|fatal" -AllMatches | Measure-Object).Count
            $errorCount += $podErrors
        }
        
        if ($errorCount -eq 0) {
            Write-Success "No errors found in pod logs"
            Add-VerificationResult "E2E Flow" "Pod Logs" "PASSED" "No errors found"
        }
        else {
            Write-Warning-Custom "Found $errorCount error(s) in pod logs"
            Add-VerificationResult "E2E Flow" "Pod Logs" "WARNING" "Found $errorCount error(s)"
        }
        
        return $true
    }
    catch {
        Write-Error-Custom "End-to-end flow test failed: $_"
        Add-VerificationResult "E2E Flow" "E2E Test" "FAILED" "Error: $_"
        return $false
    }
}

function Generate-VerificationReport {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Final Deployment Verification Report" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Environment: $Environment"
    Write-Host "Namespace: $Namespace"
    Write-Host "Cluster: $ClusterName"
    Write-Host "Region: $Region"
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ""
    
    # Group results by category
    $categories = $VerificationResults | Group-Object -Property Category
    
    foreach ($category in $categories) {
        Write-Host "$($category.Name):" -ForegroundColor Yellow
        foreach ($result in $category.Group) {
            $statusColor = switch ($result.Status) {
                "PASSED" { "Green" }
                "FAILED" { "Red" }
                "WARNING" { "Yellow" }
                default { "White" }
            }
            
            Write-Host "  [$($result.Status)] $($result.Check)" -ForegroundColor $statusColor
            Write-Host "    Details: $($result.Details)"
        }
        Write-Host ""
    }
    
    # Summary
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Summary" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Passed: $Passed" -ForegroundColor Green
    Write-Host "Warnings: $Warnings" -ForegroundColor Yellow
    Write-Host "Failed: $Failed" -ForegroundColor Red
    Write-Host ""
    
    if ($Failed -eq 0) {
        Write-Host "✓ All critical checks passed!" -ForegroundColor Green
        Write-Host "✓ AWS EKS deployment is ready for production" -ForegroundColor Green
        return 0
    }
    else {
        Write-Host "✗ Some checks failed. Please review the output above." -ForegroundColor Red
        return 1
    }
}

##############################################################################
# Main Execution
##############################################################################

function Main {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "AWS EKS Final Deployment Verification" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Run all verification checks
    $servicesOk = Verify-AllServicesRunning
    Write-Host ""
    
    $smokeTestsOk = Verify-SmokeTests
    Write-Host ""
    
    $domainsOk = Verify-CloudflareDomains
    Write-Host ""
    
    $certificatesOk = Verify-SSLCertificates
    Write-Host ""
    
    $healthOk = Verify-HealthEndpoints
    Write-Host ""
    
    $e2eOk = Verify-EndToEndFlow
    Write-Host ""
    
    # Generate report
    $exitCode = Generate-VerificationReport
    
    return $exitCode
}

# Run main function
exit (Main)
