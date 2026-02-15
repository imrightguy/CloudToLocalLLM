##############################################################################
# AWS EKS Deployment Verification Script (PowerShell)
#
# This script verifies that all components of the Zoidbot deployment
# on AWS EKS are running correctly and accessible.
#
# Usage: .\verify-deployment.ps1 -Environment development
##############################################################################

param(
    [string]$Environment = "development",
    [string]$Namespace = "zoidbot",
    [string]$ClusterName = "zoidbot-eks",
    [string]$Region = "us-east-1"
)

# Configuration
$Domains = @(
    "zoidbot.online",
    "app.zoidbot.online",
    "api.zoidbot.online",
    "auth.zoidbot.online"
)

# Counters
$Passed = 0
$Failed = 0
$Warnings = 0

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

##############################################################################
# Verification Functions
##############################################################################

function Verify-ClusterConnectivity {
    Write-Info "Verifying EKS cluster connectivity..."
    
    try {
        $clusterInfo = kubectl cluster-info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Connected to EKS cluster"
            return $true
        }
        else {
            Write-Error-Custom "Failed to connect to EKS cluster"
            return $false
        }
    }
    catch {
        Write-Error-Custom "Error connecting to cluster: $_"
        return $false
    }
}

function Verify-NamespaceExists {
    Write-Info "Verifying namespace exists..."
    
    try {
        $namespace = kubectl get namespace $Namespace 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Namespace '$Namespace' exists"
            return $true
        }
        else {
            Write-Error-Custom "Namespace '$Namespace' does not exist"
            return $false
        }
    }
    catch {
        Write-Error-Custom "Error checking namespace: $_"
        return $false
    }
}

function Verify-PodsRunning {
    Write-Info "Verifying all pods are running..."
    
    try {
        $pods = kubectl get pods -n $Namespace -o jsonpath='{.items[*].metadata.name}' 2>$null
        
        if ([string]::IsNullOrEmpty($pods)) {
            Write-Warning-Custom "No pods found in namespace '$Namespace'"
            return $true
        }
        
        $podArray = $pods -split '\s+'
        $allRunning = $true
        
        foreach ($pod in $podArray) {
            if ([string]::IsNullOrEmpty($pod)) { continue }
            
            $status = kubectl get pod $pod -n $Namespace -o jsonpath='{.status.phase}' 2>$null
            
            if ($status -eq "Running") {
                Write-Success "Pod '$pod' is running"
            }
            else {
                Write-Error-Custom "Pod '$pod' is in state: $status"
                $allRunning = $false
            }
        }
        
        return $allRunning
    }
    catch {
        Write-Error-Custom "Error checking pods: $_"
        return $false
    }
}

function Verify-PodReadiness {
    Write-Info "Verifying pod readiness probes..."
    
    try {
        $pods = kubectl get pods -n $Namespace -o jsonpath='{.items[*].metadata.name}' 2>$null
        
        if ([string]::IsNullOrEmpty($pods)) {
            Write-Warning-Custom "No pods found in namespace '$Namespace'"
            return $true
        }
        
        $podArray = $pods -split '\s+'
        $allReady = $true
        
        foreach ($pod in $podArray) {
            if ([string]::IsNullOrEmpty($pod)) { continue }
            
            $ready = kubectl get pod $pod -n $Namespace -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>$null
            
            if ($ready -eq "True") {
                Write-Success "Pod '$pod' is ready"
            }
            else {
                Write-Error-Custom "Pod '$pod' is not ready"
                $allReady = $false
            }
        }
        
        return $allReady
    }
    catch {
        Write-Error-Custom "Error checking pod readiness: $_"
        return $false
    }
}

function Verify-ServicesAccessible {
    Write-Info "Verifying services are accessible..."
    
    try {
        $services = kubectl get svc -n $Namespace -o jsonpath='{.items[*].metadata.name}' 2>$null
        
        if ([string]::IsNullOrEmpty($services)) {
            Write-Warning-Custom "No services found in namespace '$Namespace'"
            return $true
        }
        
        $serviceArray = $services -split '\s+'
        $allAccessible = $true
        
        foreach ($service in $serviceArray) {
            if ([string]::IsNullOrEmpty($service)) { continue }
            
            $endpoints = kubectl get endpoints $service -n $Namespace -o jsonpath='{.subsets[*].addresses[*].ip}' 2>$null
            
            if (-not [string]::IsNullOrEmpty($endpoints)) {
                Write-Success "Service '$service' has endpoints"
            }
            else {
                Write-Warning-Custom "Service '$service' has no endpoints"
                $allAccessible = $false
            }
        }
        
        return $allAccessible
    }
    catch {
        Write-Error-Custom "Error checking services: $_"
        return $false
    }
}

function Verify-DNSResolution {
    Write-Info "Verifying DNS resolution for Cloudflare domains..."
    
    $allResolved = $true
    
    foreach ($domain in $Domains) {
        try {
            $result = Resolve-DnsName -Name $domain -ErrorAction Stop 2>$null
            if ($result) {
                $ip = $result.IPAddress | Select-Object -First 1
                Write-Success "Domain '$domain' resolves to $ip"
            }
            else {
                Write-Error-Custom "Domain '$domain' resolved but no IP found"
                $allResolved = $false
            }
        }
        catch {
            Write-Error-Custom "Failed to resolve domain '$domain': $_"
            $allResolved = $false
        }
    }
    
    return $allResolved
}

function Verify-SSLCertificates {
    Write-Info "Verifying SSL/TLS certificates..."
    
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
                
                if ($expiryDate -gt (Get-Date)) {
                    Write-Success "SSL certificate for '$domain' is valid (expires: $expiryDate)"
                }
                else {
                    Write-Error-Custom "SSL certificate for '$domain' has expired"
                    $allValid = $false
                }
            }
            
            $sslStream.Close()
            $tcpClient.Close()
        }
        catch {
            Write-Error-Custom "Failed to verify SSL certificate for '$domain': $_"
            $allValid = $false
        }
    }
    
    return $allValid
}

function Verify-IngressConfigured {
    Write-Info "Verifying Ingress is configured..."
    
    try {
        $ingress = kubectl get ingress -n $Namespace 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            $ingressCount = ($ingress | Measure-Object).Count
            if ($ingressCount -gt 0) {
                Write-Success "Found $ingressCount Ingress resource(s)"
            }
            else {
                Write-Warning-Custom "No Ingress resources found"
            }
        }
        else {
            Write-Warning-Custom "Ingress API not available"
        }
        
        return $true
    }
    catch {
        Write-Warning-Custom "Error checking Ingress: $_"
        return $true
    }
}

function Verify-LoadBalancer {
    Write-Info "Verifying Network Load Balancer..."
    
    try {
        $nlb = kubectl get svc -n $Namespace -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].hostname}' 2>$null
        
        if (-not [string]::IsNullOrEmpty($nlb)) {
            Write-Success "Network Load Balancer endpoint: $nlb"
        }
        else {
            Write-Warning-Custom "No LoadBalancer service found or endpoint not assigned yet"
        }
        
        return $true
    }
    catch {
        Write-Warning-Custom "Error checking LoadBalancer: $_"
        return $true
    }
}

function Verify-PodLogs {
    Write-Info "Verifying pod logs for errors..."
    
    try {
        $pods = kubectl get pods -n $Namespace -o jsonpath='{.items[*].metadata.name}' 2>$null
        
        if ([string]::IsNullOrEmpty($pods)) {
            Write-Warning-Custom "No pods found in namespace '$Namespace'"
            return $true
        }
        
        $podArray = $pods -split '\s+'
        $hasErrors = $false
        
        foreach ($pod in $podArray) {
            if ([string]::IsNullOrEmpty($pod)) { continue }
            
            $logs = kubectl logs $pod -n $Namespace 2>$null
            $errorCount = ($logs | Select-String -Pattern "error|exception|fatal" -AllMatches | Measure-Object).Count
            
            if ($errorCount -gt 0) {
                Write-Warning-Custom "Pod '$pod' has $errorCount error(s) in logs"
                $hasErrors = $true
            }
            else {
                Write-Success "Pod '$pod' logs are clean"
            }
        }
        
        return -not $hasErrors
    }
    catch {
        Write-Warning-Custom "Error checking pod logs: $_"
        return $true
    }
}

function Verify-ResourceLimits {
    Write-Info "Verifying resource limits are configured..."
    
    try {
        $pods = kubectl get pods -n $Namespace -o jsonpath='{.items[*].metadata.name}' 2>$null
        
        if ([string]::IsNullOrEmpty($pods)) {
            Write-Warning-Custom "No pods found in namespace '$Namespace'"
            return $true
        }
        
        $podArray = $pods -split '\s+'
        $allConfigured = $true
        
        foreach ($pod in $podArray) {
            if ([string]::IsNullOrEmpty($pod)) { continue }
            
            $limits = kubectl get pod $pod -n $Namespace -o jsonpath='{.spec.containers[*].resources.limits}' 2>$null
            
            if (-not [string]::IsNullOrEmpty($limits) -and $limits -ne "{}") {
                Write-Success "Pod '$pod' has resource limits configured"
            }
            else {
                Write-Warning-Custom "Pod '$pod' does not have resource limits configured"
                $allConfigured = $false
            }
        }
        
        return $allConfigured
    }
    catch {
        Write-Error-Custom "Error checking resource limits: $_"
        return $false
    }
}

function Verify-HealthEndpoints {
    Write-Info "Verifying health check endpoints..."
    
    $healthEndpoints = @(
        "https://api.zoidbot.online/health",
        "https://app.zoidbot.online/health"
    )
    
    $allHealthy = $true
    
    foreach ($endpoint in $healthEndpoints) {
        try {
            $response = Invoke-WebRequest -Uri $endpoint -SkipCertificateCheck -TimeoutSec 5 -ErrorAction Stop
            
            if ($response.Content -match "ok|healthy|running") {
                Write-Success "Health endpoint '$endpoint' is responding"
            }
            else {
                Write-Warning-Custom "Health endpoint '$endpoint' responded but status unclear"
                $allHealthy = $false
            }
        }
        catch {
            Write-Warning-Custom "Health endpoint '$endpoint' is not responding or unreachable: $_"
            $allHealthy = $false
        }
    }
    
    return $allHealthy
}

##############################################################################
# Main Execution
##############################################################################

function Main {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "AWS EKS Deployment Verification" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Environment: $Environment"
    Write-Host "Namespace: $Namespace"
    Write-Host "Cluster: $ClusterName"
    Write-Host "Region: $Region"
    Write-Host ""
    
    # Run all verification checks
    Verify-ClusterConnectivity | Out-Null
    Verify-NamespaceExists | Out-Null
    Verify-PodsRunning | Out-Null
    Verify-PodReadiness | Out-Null
    Verify-ServicesAccessible | Out-Null
    Verify-IngressConfigured | Out-Null
    Verify-LoadBalancer | Out-Null
    Verify-DNSResolution | Out-Null
    Verify-SSLCertificates | Out-Null
    Verify-PodLogs | Out-Null
    Verify-ResourceLimits | Out-Null
    Verify-HealthEndpoints | Out-Null
    
    # Print summary
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Verification Summary" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Passed: $Passed" -ForegroundColor Green
    Write-Host "Warnings: $Warnings" -ForegroundColor Yellow
    Write-Host "Failed: $Failed" -ForegroundColor Red
    Write-Host ""
    
    if ($Failed -eq 0) {
        Write-Host "✓ All critical checks passed!" -ForegroundColor Green
        return 0
    }
    else {
        Write-Host "✗ Some checks failed. Please review the output above." -ForegroundColor Red
        return 1
    }
}

# Run main function
exit (Main)
