# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Git
choco install git -y

# Create runner directory
New-Item -ItemType Directory -Path C:\actions-runner -Force
Set-Location C:\actions-runner

# Download the runner application
Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-win-x64-2.311.0.zip" -OutFile "actions-runner-win-x64-2.311.0.zip"
Expand-Archive -Path "actions-runner-win-x64-2.311.0.zip" -DestinationPath "."

# Configure the runner
.\config.cmd --url https://github.com/Zoidbot-online/Zoidbot --token BOBH5XEA7XJPPTNW2CYI7F3IUR2RG --labels windows,self-hosted --unattended

# Install as a service
.\svc.exe install
.\svc.exe start
