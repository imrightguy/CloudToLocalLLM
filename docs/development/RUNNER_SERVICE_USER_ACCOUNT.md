# Running GitHub Actions Runner as User Account

When a GitHub Actions self-hosted runner is installed as a Windows service, it may run under the SYSTEM account or a service account by default. This can cause issues with:

- Network downloads (permissions, firewall)
- Accessing user-specific directories (`$env:USERPROFILE`)
- Installing software to user locations

## Solution: Run Service as Your User Account

### Step 1: Stop and Uninstall Current Service

Open PowerShell **as Administrator** and run:

```powershell
# Navigate to runner directory
cd C:\actions-runner  # or wherever your runner is installed

# Stop the service
.\svc.exe stop

# Uninstall the service
.\svc.exe uninstall
```

### Step 2: Install Service to Run as Your User Account

```powershell
# Install the service to run as your current user account
.\svc.exe install --username "YOUR_USERNAME" --password "YOUR_PASSWORD"
```

**Note:** Replace:

- `YOUR_USERNAME` with your Windows username (e.g., `rightguy` or `DOMAIN\username`)
- `YOUR_PASSWORD` with your Windows password

**Alternative:** If you don't want to provide password in command line:

```powershell
# Install without password (will prompt or use Windows credential manager)
.\svc.exe install --username "YOUR_USERNAME"
```

### Step 3: Start the Service

```powershell
# Start the service
.\svc.exe start

# Verify it's running
Get-Service actions.runner.* | Format-Table -AutoSize
```

### Step 4: Verify Service Account

Check what account the service is running under:

```powershell
# Get service details
$service = Get-WmiObject Win32_Service -Filter "Name LIKE 'actions.runner.%'"
$service | Select-Object Name, StartName, State

# Should show your username instead of "LocalSystem"
```

### Alternative: Configure Through Services App

1. Press `Win + R`, type `services.msc`, press Enter
2. Find the service named `actions.runner.<your-runner-name>`
3. Right-click → **Properties**
4. Go to **Log On** tab
5. Select **This account** and enter your username and password
6. Click **OK** and restart the service

## For Linux Runner (WSL)

If you're also having issues with the Linux runner, you can run it as a systemd user service:

```bash
# Edit the service file
sudo nano /etc/systemd/system/actions.runner.*.service

# Change User= to your username
User=yourusername

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart actions.runner.*
```

## Verification

After reconfiguring, test a workflow run and check:

1. The runner appears online in GitHub Actions
2. Downloads work properly (Flutter download completes)
3. Files are created in user directories without permission errors

## Troubleshooting

### Service Won't Start

- Verify the username and password are correct
- Check that the user account has "Log on as a service" right:

  ```powershell
  # Add user to "Log on as a service" policy
  secedit /export /cfg c:\secpol.cfg
  # Edit secpol.cfg to add your user, then:
  secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas USER_RIGHTS
  ```

### Still Getting Permission Errors

- Ensure your user account has admin privileges (recommended)
- Check Windows Firewall settings for your user account
- Verify network connectivity from your user context
