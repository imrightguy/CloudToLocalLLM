# Monitor nameservers until they change to Cloudflare nameservers
# Simple, reliable version

$ErrorActionPreference = "Continue"

# Cloudflare nameservers we expect (will be loaded from file or API)
$expectedNameservers = @()

$domain = "zoidbot.online"
$checkInterval = 30 # seconds
$attempt = 0

# Try to load nameservers from file first
$nameserversFile = "cloudflare-nameservers.txt"
if (Test-Path $nameserversFile) {
    Write-Host "📄 Loading Cloudflare nameservers from $nameserversFile..." -ForegroundColor Cyan
    $expectedNameservers = Get-Content $nameserversFile | Where-Object { $_.Trim() -ne "" }
    Write-Host "✅ Loaded $($expectedNameservers.Count) nameservers" -ForegroundColor Green
} else {
    # Try to get from Cloudflare API
    if ($env:CLOUDFLARE_API_TOKEN) {
        Write-Host "🔍 Fetching Cloudflare nameservers via API..." -ForegroundColor Cyan
        try {
            $zoneResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones?name=$domain" `
                -Method GET `
                -Headers @{
                    "Authorization" = "Bearer $env:CLOUDFLARE_API_TOKEN"
                    "Content-Type" = "application/json"
                } -ErrorAction Stop
            
            if ($zoneResponse.result.Count -gt 0) {
                $expectedNameservers = $zoneResponse.result[0].name_servers
                Write-Host "✅ Fetched $($expectedNameservers.Count) nameservers from Cloudflare API" -ForegroundColor Green
                # Save for future use
                $expectedNameservers | Out-File -FilePath $nameserversFile -Encoding UTF8
            }
        } catch {
            Write-Host "⚠️  Could not fetch nameservers from API: $_" -ForegroundColor Yellow
        }
    }
}

# Fallback to common Cloudflare patterns if still empty
if ($expectedNameservers.Count -eq 0) {
    Write-Host "⚠️  No nameservers loaded. Using Cloudflare pattern matching..." -ForegroundColor Yellow
    Write-Host "   Run '.\scripts\get-cloudflare-nameservers.ps1' first for exact nameservers" -ForegroundColor Yellow
    Write-Host ""
    # Cloudflare nameservers typically contain ".ns.cloudflare.com"
    # We'll match any nameserver containing "cloudflare" or ".ns.cloudflare.com"
}

Write-Host ""
Write-Host "🔍 Monitoring nameservers for $domain..." -ForegroundColor Cyan
Write-Host ""

if ($expectedNameservers.Count -gt 0) {
    Write-Host "Expected Cloudflare nameservers:" -ForegroundColor Yellow
    foreach ($ns in $expectedNameservers) {
        Write-Host "  • $ns" -ForegroundColor White
    }
} else {
    Write-Host "Expected: Cloudflare nameservers (containing 'cloudflare' or '.ns.cloudflare.com')" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Checking every $checkInterval seconds..." -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

function Get-NameServers {
    param([string]$domainName, [string]$dnsServer)
    
    try {
        # Use Resolve-DnsName with timeout
        $job = Start-Job -ScriptBlock {
            param($name, $server)
            try {
                Resolve-DnsName -Name $name -Type NS -Server $server -ErrorAction Stop | 
                    Where-Object { $_.Type -eq "NS" } | 
                    ForEach-Object { $_.NameHost.ToLower().TrimEnd('.') } | 
                    Sort-Object -Unique
            } catch {
                $null
            }
        } -ArgumentList $domainName, $dnsServer
        
        $result = $job | Wait-Job -Timeout 10 | Receive-Job
        $job | Remove-Job -Force -ErrorAction SilentlyContinue
        
        return $result
    } catch {
        return $null
    }
}

function Test-AllNameserversPropagated {
    param([array]$expectedNameservers)
    
    $dnsServers = @(
        @{Name="Google DNS"; Server="8.8.8.8"},
        @{Name="Cloudflare DNS"; Server="1.1.1.1"},
        @{Name="OpenDNS"; Server="208.67.222.222"}
    )
    
    $allPropagated = $true
    $results = @()
    
    foreach ($dns in $dnsServers) {
        $ns = Get-NameServers -domainName $domain -dnsServer $dns.Server
        
        $isCloudflare = $false
        if ($ns -and $ns.Count -gt 0) {
            if ($expectedNameservers.Count -gt 0) {
                # Check against expected nameservers
                foreach ($n in $ns) {
                    foreach ($expectedNs in $expectedNameservers) {
                        $nLower = $n.ToLower().TrimEnd('.')
                        $expectedLower = $expectedNs.ToLower().TrimEnd('.')
                        if ($nLower -eq $expectedLower -or $nLower -like "*$expectedLower*" -or $expectedLower -like "*$nLower*") {
                            $isCloudflare = $true
                            break
                        }
                    }
                    if ($isCloudflare) { break }
                }
            } else {
                # Pattern matching fallback
                foreach ($n in $ns) {
                    $nLower = $n.ToLower()
                    if ($nLower -like "*cloudflare*" -or $nLower -like "*.ns.cloudflare.com") {
                        $isCloudflare = $true
                        break
                    }
                }
            }
            
            # Need at least 2 Cloudflare nameservers
            if ($isCloudflare) {
                $cloudflareCount = 0
                foreach ($n in $ns) {
                    $nLower = $n.ToLower()
                    if ($nLower -like "*cloudflare*" -or $nLower -like "*.ns.cloudflare.com") {
                        $cloudflareCount++
                    }
                }
                $isCloudflare = $cloudflareCount -ge 2
            }
        }
        
        $results += @{
            DNS = $dns.Name
            Server = $dns.Server
            Nameservers = $ns
            IsCloudflare = $isCloudflare
        }
        
        if (-not $isCloudflare) {
            $allPropagated = $false
        }
    }
    
    return @{
        AllPropagated = $allPropagated
        Results = $results
    }
}

function Test-CloudflareNameservers {
    param([array]$current, [array]$expected)
    
    if ($null -eq $current -or $current.Count -eq 0) {
        return $false
    }
    
    # If we have specific expected nameservers, match exactly
    if ($expected -and $expected.Count -gt 0) {
        $matchCount = 0
        foreach ($ns in $current) {
            $nsLower = $ns.ToLower().TrimEnd('.')
            foreach ($expectedNs in $expected) {
                $expectedLower = $expectedNs.ToLower().TrimEnd('.')
                if ($nsLower -eq $expectedLower -or $nsLower -like "*$expectedLower*" -or $expectedLower -like "*$nsLower*") {
                    $matchCount++
                    break
                }
            }
        }
        # Need at least 2 matching Cloudflare nameservers (Cloudflare typically uses 2)
        return $matchCount -ge 2
    } else {
        # Fallback: Match Cloudflare pattern
        $cloudflareCount = 0
        foreach ($ns in $current) {
            $nsLower = $ns.ToLower()
            if ($nsLower -like "*cloudflare*" -or $nsLower -like "*.ns.cloudflare.com") {
                $cloudflareCount++
            }
        }
        # Need at least 2 Cloudflare nameservers
        return $cloudflareCount -ge 2
    }
}

try {
    while ($true) {
        $attempt++
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        Write-Host "[$timestamp] Attempt #$attempt" -ForegroundColor Cyan
        Write-Host "Checking nameservers across multiple DNS servers..." -ForegroundColor White
        Write-Host ""
        
        # Check all DNS servers
        $propagationStatus = Test-AllNameserversPropagated -expectedNameservers $expectedNameservers
        
        $allGood = $true
        foreach ($result in $propagationStatus.Results) {
            Write-Host "  $($result.DNS) ($($result.Server)):" -ForegroundColor Cyan
            
            if ($null -eq $result.Nameservers -or $result.Nameservers.Count -eq 0) {
                Write-Host "    ⚠️  Could not retrieve nameservers" -ForegroundColor Yellow
                $allGood = $false
            } else {
                foreach ($ns in $result.Nameservers) {
                    $nsLower = $ns.ToLower()
                    if ($nsLower -like "*cloudflare*" -or $nsLower -like "*.ns.cloudflare.com") {
                        Write-Host "    ✅ $ns (Cloudflare)" -ForegroundColor Green
                    } else {
                        Write-Host "    ❌ $ns (NOT Cloudflare)" -ForegroundColor Red
                    }
                }
                
                if ($result.IsCloudflare) {
                    Write-Host "    ✅ Status: Cloudflare nameservers active" -ForegroundColor Green
                } else {
                    Write-Host "    ❌ Status: Still showing non-Cloudflare nameservers" -ForegroundColor Red
                    $allGood = $false
                }
            }
            Write-Host ""
        }
        
        # Check if all DNS servers show Cloudflare nameservers
        if ($propagationStatus.AllPropagated) {
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
            Write-Host "✅ SUCCESS! Cloudflare nameservers are now fully propagated!" -ForegroundColor Green
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
            Write-Host ""
            Write-Host "All DNS servers are now showing Cloudflare nameservers." -ForegroundColor Green
            Write-Host "Full global propagation may take additional 5-15 minutes for all locations." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Cyan
            Write-Host "  1. DNS records will be managed via Cloudflare DNS" -ForegroundColor White
            Write-Host "  2. SSL certificates will be provisioned via Cloudflare DNS-01 challenge" -ForegroundColor White
            Write-Host ""
            break
        } else {
            Write-Host "  ⏳ Propagation incomplete - waiting for all DNS servers to update..." -ForegroundColor Yellow
            Write-Host "  This may take 5-15 minutes or longer depending on DNS cache TTL" -ForegroundColor Gray
        }
        
        Write-Host ""
        Start-Sleep -Seconds $checkInterval
    }
} catch {
    Write-Host ""
    Write-Host "❌ Error: $_" -ForegroundColor Red
    Write-Host "Monitoring stopped." -ForegroundColor Yellow
} finally {
    # Clean up any background jobs
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
}
