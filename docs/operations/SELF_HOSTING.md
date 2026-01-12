# Self-Hosting CloudToLocalLLM

This document provides comprehensive instructions for self-hosting the CloudToLocalLLM application stack on a Linux VPS.

**Website: [https://cloudtolocalllm.online](https://cloudtolocalllm.online)**

## 🛠️ Prerequisites (Server-Side)

Before you begin, ensure your VPS meets the following requirements:

- **Operating System**: A modern Linux distribution (e.g., Ubuntu 20.04/22.04, Debian 11, CentOS Stream).
- **Hardware**:
    - Minimum 2 CPU cores.
    - Minimum 4GB RAM (8GB+ recommended if running larger LLMs directly on the server alongside the stack).
    - Minimum 20GB disk space (more if storing many LLMs or extensive data).
- **Networking**:
    - Static IP address.
    - Domain name pointed to the server's static IP (e.g., `cloudtolocalllm.online` and `*.cloudtolocalllm.online` for wildcard SSL).
- **Software to be installed (scripts will assist with some of these):**
    - **Git**: For cloning the repository.
    - **Docker**: Containerization platform.
    - **Docker Compose (v2 plugin)**: For defining and running multi-container Docker applications (`docker compose` command).
    - **UFW (Uncomplicated Firewall)**: For managing firewall rules (optional but recommended).
    - **Fail2ban**: For protecting against brute-force attacks (optional but recommended).
    - **Curl / Wget**: For downloading scripts or software.

## Initial Server Setup

These steps should be performed as the `root` user or a user with `sudo` privileges.

### 1. Create Dedicated User (`cloudllm`)

It's highly recommended to run the application under a dedicated non-root user.
- The `scripts/setup_cloudllm_user.sh` script can automate this. Download and run it:
  ```bash
  curl -o setup_cloudllm_user.sh https://raw.githubusercontent.com/CloudToLocalLLM-online/CloudToLocalLLM/main/scripts/setup_cloudllm_user.sh
  chmod +x setup_cloudllm_user.sh
  ./setup_cloudllm_user.sh cloudllm your_public_ssh_key_string
  ```
  Replace `your_public_ssh_key_string` with your actual public SSH key.
- This script will:
    - Create the `cloudllm` user.
    - Add your public SSH key for passwordless login.
    - Grant necessary sudo privileges for Docker management if it also installs Docker (though `scripts/deploy/deploy_to_vps.sh` typically handles Docker installation).
    - Set up the `docker` group and add `cloudllm` to it.

**After running the script, log out and log back in as the `cloudllm` user.**

### 2. Clone the Repository

As the `cloudllm` user, clone the project repository:
```bash
git clone https://github.com/CloudToLocalLLM-online/CloudToLocalLLM.git /opt/cloudtolocalllm
cd /opt/cloudtolocalllm
```
The rest of the setup will assume you are in the `/opt/cloudtolocalllm` directory.

### 3. Run the Deployment Script

The `scripts/deploy/deploy_to_vps.sh` script automates many of the subsequent setup tasks. Execute it as the `cloudllm` user (it will use `sudo` internally for privileged operations where necessary, assuming `cloudllm` has appropriate sudo rights, or you might need to run specific parts as root if `cloudllm` sudo is restricted).
```bash
cd /opt/cloudtolocalllm
./scripts/deploy/deploy_to_vps.sh
```
This script typically handles:
- System requirement checks (disk space, memory).
- Installation of Docker and Docker Compose if not present.
- UFW (firewall) setup with rules for SSH, HTTP, HTTPS.
- Fail2ban installation and basic configuration.
- Initial application startup using `docker compose`.

Review the script's output for any errors or important messages.

## 🔒 SSL Certificate Setup (Let's Encrypt Wildcard)

This project uses Let's Encrypt for SSL certificates, managed via Certbot with a manual DNS challenge for wildcard support (e.g., `*.cloudtolocalllm.online`). This allows HTTPS on your main domain and any subdomains.

**Run these steps as the `cloudllm` user from `/opt/cloudtolocalllm`.**

### Directory Structure for Certbot

The `docker-compose.yml` file maps `./certbot/conf:/etc/letsencrypt` and `./certbot/www:/var/www/certbot` into the `webapp` (Nginx) container. This means Certbot data will be stored in `/opt/cloudtolocalllm/certbot/` on the host.

### Using SSL Certificate Setup Script

The script `scripts/ssl/setup_letsencrypt.sh` is used to obtain and renew certificates.

1.  **Switch to Production (Important!)**:
    The script initially might be configured for Let's Encrypt's *staging* server. For a live, browser-trusted certificate, ensure the script is set to use the *production* server. This usually means removing or commenting out a line like `server: https://acme-staging-v02.api.letsencrypt.org/directory` or a `--staging` flag within the `certbot` command in the script.
    *   **Verify `scripts/ssl/setup_letsencrypt.sh`**:
        *   Open `scripts/ssl/setup_letsencrypt.sh`.
        *   Look for `CERTBOT_SERVER_FLAG`. If it's `"--staging"`, remove or comment it out for production, or set it to an empty string.
        *   The script should call `certbot certonly --manual ...` without `--staging`.

2.  **Ensure Script is Executable**:
    ```bash
    chmod +x scripts/ssl/setup_letsencrypt.sh
    ```

3.  **Run the Script**:
    ```bash
    ./scripts/ssl/setup_letsencrypt.sh yourdomain.online youremail@example.com
    ```
    Replace `yourdomain.online` with your actual domain (e.g., `cloudtolocalllm.online`) and `youremail@example.com` with your email for Let's Encrypt notifications.

4.  **Manual DNS Verification**:
    *   Certbot will pause and ask you to deploy DNS TXT records. For example:
        ```
        Please deploy a DNS TXT record under the name
        _acme-challenge.yourdomain.online with the following value:
        [some_long_random_string_1]

        Please deploy a DNS TXT record under the name
        _acme-challenge.yourdomain.online with the following value:
        [some_long_random_string_2]
        (This second TXT record may not always be shown, depending on Certbot version and request)
        ```
    *   Log in to your DNS provider (e.g., Namecheap, Cloudflare, GoDaddy).
    *   Create the specified TXT record(s) for `_acme-challenge.yourdomain.online` with the value(s) Certbot provides.
        *   **Name/Host**: `_acme-challenge` (your DNS provider might automatically append `yourdomain.online`)
        *   **Value/Text**: The random string provided by Certbot.
        *   **TTL**: Set a low TTL (e.g., 1 minute or 300 seconds) if possible, to speed up propagation.
    *   **Wait for DNS Propagation**: This can take a few minutes. You can use a tool like `https://dnschecker.org` to verify that the TXT record is visible globally before proceeding.
    *   Once the TXT record is propagated, press Enter in the terminal where Certbot is running.

5.  **Certificate Issuance**:
    *   If DNS verification is successful, Certbot will issue the certificate.
    *   Certificates are typically stored in `/opt/cloudtolocalllm/certbot/conf/live/yourdomain.online/` (e.g., `/opt/cloudtolocalllm/certbot/conf/live/cloudtolocalllm.online/`).
    *   **Important - Symlink Check**:
        *   Sometimes, especially after re-runs or issues, Certbot might create a directory like `yourdomain.online-0001`. Nginx expects `yourdomain.online`.
        *   Check the `live` directory: `ls -lA /opt/cloudtolocalllm/certbot/conf/live/`
        *   If you see `yourdomain.online-0001` and `yourdomain.online` is missing or is not a symlink to it, create/fix the symlink:
            ```bash
            cd /opt/cloudtolocalllm/certbot/conf/live/
            ln -sfn yourdomain.online-0001 yourdomain.online 
            cd /opt/cloudtolocalllm # Return to project root
            ```
        *   Also ensure that files like `fullchain.pem` and `privkey.pem` inside `/opt/cloudtolocalllm/certbot/conf/live/yourdomain.online/` are symlinks to the actual certificate files in the `../../archive/yourdomain.online/` directory. If they are plain files (not symlinks), it indicates a broken Certbot state. You might need to rename the `live/yourdomain.online` directory and re-run the script. Example fix if `live/yourdomain.online` is problematic:
            ```bash
            mv /opt/cloudtolocalllm/certbot/conf/live/yourdomain.online /opt/cloudtolocalllm/certbot/conf/live/yourdomain.online.bak
            # Then re-run ./scripts/ssl/setup_letsencrypt.sh ...
            ```

6.  **Permissions for `privkey.pem`**:
    Ensure `privkey.pem` has appropriate permissions for Nginx to read it. Often, Certbot sets this correctly, but it's good to verify.
    ```bash
    sudo chmod 640 /opt/cloudtolocalllm/certbot/conf/live/yourdomain.online/privkey.pem
    # Or 644 if Nginx still has issues and runs as a different user than the group of privkey.pem
    ```

### Renewing Certificates
Let's Encrypt certificates are valid for 90 days. You'll need to re-run the `scripts/ssl/setup_letsencrypt.sh` script and repeat the DNS challenge process before they expire. Set a calendar reminder.

## 🚀 Running the Application Stack

Once Docker, Docker Compose, and SSL certificates are set up:

1.  **Navigate to the project directory**:
    ```bash
    cd /opt/cloudtolocalllm
    ```
2.  **Start all services in detached mode**:
    (As the `cloudllm` user)
    ```bash
    docker compose up -d
    ```
    This will pull necessary Docker images and start all services defined in `docker-compose.yml`.

3.  **Verify services**:
    ```bash
    docker compose ps
    ```
    All services should show as `Up` or `running` (or `healthy` for `webapp`).

4.  **Check Webapp Logs (if issues)**:
    ```bash
    docker compose logs webapp
    ```
    Look for any Nginx errors, especially related to SSL certificates.

Your CloudToLocalLLM instance should now be accessible at `https://yourdomain.online`.

## 🔄 Updating the Application

To update the application to the latest version from Git:

1.  **Log in as `cloudllm` user and navigate to the project directory**:
    ```bash
    cd /opt/cloudtolocalllm
    ```
2.  **Pull latest changes**:
    ```bash
    git pull
    ```
3.  **Rebuild Docker Images (if necessary)**:
    *   If there are changes to `Dockerfile`s, or application code that's copied into images (like the Flutter web app in `webapp`), you need to rebuild the images.
    *   For the web application (`webapp` service), always rebuild with `--no-cache` to ensure new Flutter assets are picked up:
        ```bash
        docker compose build --no-cache webapp
        ```
    *   If other services (e.g., `api-backend`) were updated, build them too:
        ```bash
        docker compose build api-backend
        ```
4.  **Recreate and Restart Services**:
    Apply the changes by recreating the containers. `--force-recreate` ensures new images are used. `--no-deps` can be used if you only want to recreate specific services.
    ```bash
    docker compose up -d --force-recreate webapp api-backend # Add other updated services
    ```
    Or to recreate all:
    ```bash
    docker compose up -d --force-recreate
    ```
 
## ⚙️ Troubleshooting Common Issues
 
- **Docker Permission Errors**:
    - Ensure the `cloudllm` user is part of the `docker` group (`sudo usermod -aG docker cloudllm`, then log out/in).
    - Ensure `/opt/cloudtolocalllm` and its subdirectories (especially `certbot/` and any other volume mounts) are owned by `cloudllm`: `sudo chown -R cloudllm:cloudllm /opt/cloudtolocalllm`.
- **SSL Certificate Errors in Nginx Logs (`webapp` service)**:
    - `"cannot load certificate ... No such file or directory"`:
        - Verify the volume mount in `docker-compose.yml`: `webapp` service should mount `./certbot/conf:/etc/letsencrypt`.
        - Double-check the host path: `ls -lA /opt/cloudtolocalllm/certbot/conf/live/yourdomain.online/`. Ensure `fullchain.pem` and `privkey.pem` exist and are correct symlinks.
        - Fix symlinks or re-run Certbot script as described in the SSL section.
- **Flutter Web App UI Not Updating**:
    - After `git pull`, you **must** rebuild the `webapp` Docker image with `--no-cache` and then recreate the container, as detailed in the "Updating the Application" section.
- **`docker-compose: command not found`**:
    - Use `docker compose` (with a space). The `scripts/deploy/deploy_to_vps.sh` script aims to install the Docker Compose v2 plugin.
- **General Service Issues**:
    - `docker compose ps` to see container status.
    - `docker compose logs <service_name>` to view logs (e.g., `docker compose logs webapp`, `docker compose logs api-backend`).
    - Refer to `scripts/troubleshooting_commands.sh` for more diagnostic commands.
    - Check system logs: `journalctl -u docker.service` or `/var/log/syslog`.

This guide provides a comprehensive path to self-hosting CloudToLocalLLM. For further details on specific components or advanced configurations, refer to other documents in the `/docs` directory or the project's main `README.md`. 