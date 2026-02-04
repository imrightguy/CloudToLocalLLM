# Zoidbot Tray Service Installation Script for Windows
# This script installs the Zoidbot tray daemon as a Windows service

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Start,
    [switch]$Stop,
    [switch]$Status
)

$ServiceName = "ZoidbotTray"
$ServiceDisplayName = "Zoidbot System Tray Daemon"
$ServiceDescription = "Provides system tray functionality for Zoidbot application"
$ExecutablePath = "$env:PROGRAMFILES\Zoidbot\bin\zoidbot-tray.exe"

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-TrayService {
    if (-not (Test-Administrator)) {
        Write-Error "Administrator privileges required to install service"
        exit 1
    }

    if (-not (Test-Path $ExecutablePath)) {
        Write-Error "Zoidbot tray executable not found at: $ExecutablePath"
        exit 1
    }

    try {
        # Check if service already exists
        $existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-Host "Service already exists. Stopping and removing..."
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            sc.exe delete $ServiceName
            Start-Sleep -Seconds 2
        }

        # Create the service
        Write-Host "Installing Zoidbot Tray Service..."
        $result = sc.exe create $ServiceName binPath= "`"$ExecutablePath`"" DisplayName= $ServiceDisplayName start= auto
        
        if ($LASTEXITCODE -eq 0) {
            # Set service description
            sc.exe description $ServiceName $ServiceDescription
            
            # Configure service to restart on failure
            sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/10000/restart/30000
            
            Write-Host "Service installed successfully!" -ForegroundColor Green
            Write-Host "Starting service..."
            Start-Service -Name $ServiceName
            Write-Host "Service started!" -ForegroundColor Green
        } else {
            Write-Error "Failed to install service"
            exit 1
        }
    }
    catch {
        Write-Error "Error installing service: $_"
        exit 1
    }
}

function Uninstall-TrayService {
    if (-not (Test-Administrator)) {
        Write-Error "Administrator privileges required to uninstall service"
        exit 1
    }

    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service) {
            Write-Host "Stopping and removing Zoidbot Tray Service..."
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            sc.exe delete $ServiceName
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Service uninstalled successfully!" -ForegroundColor Green
            } else {
                Write-Error "Failed to uninstall service"
                exit 1
            }
        } else {
            Write-Host "Service not found" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "Error uninstalling service: $_"
        exit 1
    }
}

function Start-TrayService {
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service) {
            if ($service.Status -eq "Running") {
                Write-Host "Service is already running" -ForegroundColor Yellow
            } else {
                Write-Host "Starting Zoidbot Tray Service..."
                Start-Service -Name $ServiceName
                Write-Host "Service started!" -ForegroundColor Green
            }
        } else {
            Write-Error "Service not found. Please install it first."
            exit 1
        }
    }
    catch {
        Write-Error "Error starting service: $_"
        exit 1
    }
}

function Stop-TrayService {
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service) {
            if ($service.Status -eq "Stopped") {
                Write-Host "Service is already stopped" -ForegroundColor Yellow
            } else {
                Write-Host "Stopping Zoidbot Tray Service..."
                Stop-Service -Name $ServiceName -Force
                Write-Host "Service stopped!" -ForegroundColor Green
            }
        } else {
            Write-Error "Service not found"
            exit 1
        }
    }
    catch {
        Write-Error "Error stopping service: $_"
        exit 1
    }
}

function Get-TrayServiceStatus {
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service) {
            Write-Host "Service Status: $($service.Status)" -ForegroundColor Cyan
            Write-Host "Service Name: $($service.Name)"
            Write-Host "Display Name: $($service.DisplayName)"
            Write-Host "Start Type: $($service.StartType)"
        } else {
            Write-Host "Service not installed" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "Error getting service status: $_"
        exit 1
    }
}

# Main execution
if ($Install) {
    Install-TrayService
} elseif ($Uninstall) {
    Uninstall-TrayService
} elseif ($Start) {
    Start-TrayService
} elseif ($Stop) {
    Stop-TrayService
} elseif ($Status) {
    Get-TrayServiceStatus
} else {
    Write-Host "Zoidbot Tray Service Management Script"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\install-tray-service.ps1 -Install    # Install and start the service"
    Write-Host "  .\install-tray-service.ps1 -Uninstall  # Stop and remove the service"
    Write-Host "  .\install-tray-service.ps1 -Start      # Start the service"
    Write-Host "  .\install-tray-service.ps1 -Stop       # Stop the service"
    Write-Host "  .\install-tray-service.ps1 -Status     # Show service status"
    Write-Host ""
    Write-Host "Note: Administrator privileges required for install/uninstall operations"
}
