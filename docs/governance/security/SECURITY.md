# Security Policy

The following versions of the Zoidbot project are currently supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 7.17.x  | :white_check_mark: |
| 7.16.x  | :white_check_mark: |
| 4.5.x  | :white_check_mark: |
| 7.15.x  | :white_check_mark: |
| 7.14.x  | :white_check_mark: |
| 7.13.x  | :white_check_mark: |
| 7.12.x  | :white_check_mark: |
| 7.11.x  | :white_check_mark: |
| 7.10.x  | :white_check_mark: |
| 7.9.x  | :white_check_mark: |
| 7.8.x  | :white_check_mark: |
| 7.7.x  | :white_check_mark: |
| 7.6.x  | :white_check_mark: |
| 7.5.x  | :white_check_mark: |
| 7.4.x  | :white_check_mark: |
| 7.3.x  | :white_check_mark: |
| 7.2.x  | :white_check_mark: |
| 7.1.x  | :white_check_mark: |
| 7.0.x  | :white_check_mark: |
| 6.5.x  | :white_check_mark: |
| 6.4.x  | :white_check_mark: |
| 6.3.x  | :white_check_mark: |
| 6.2.x  | :white_check_mark: |
| 6.1.x  | :white_check_mark: |
| 6.0.x  | :white_check_mark: |
| 5.0.x  | :white_check_mark: |
| 4.20.x  | :white_check_mark: |
| 4.19.x  | :white_check_mark: |
| 4.18.x  | :white_check_mark: |
| 4.17.x  | :white_check_mark: |
| 4.16.x  | :white_check_mark: |
| 4.15.x  | :white_check_mark: |
| 4.14.x  | :white_check_mark: |
| 4.13.x  | :x:                |
| < 4.13  | :x:                |

## Reporting a Vulnerability

Use this section to tell people how to report a vulnerability.

To report a vulnerability, please do **not** open a public issue. Instead, please report it via the "Security" tab in this repository (if enabled) or contact the maintainers directly at:

**Email**: `support@zoidbot.online`
*(Please include "[SECURITY]" in the subject line)*

We aim to acknowledge reports within 48 hours and provide updates on the remediation process.

## Infrastructure Security

We take security seriously. Our architecture is designed to provide enterprise-grade security whether you are running a single local instance or a full cloud deployment.

### Deployment Security Parity

**Same Code, Same Security**: We adhere to a strict "security consistency" policy. **Local instances** verify and enforce the exact same security standards as our Cloud deployments. There are no "weakened" local dev modes; the security controls you see in production are the same ones protecting your local machine.

### Built-in Protections

* **Non-Root Execution**: All our containers are architected to run as unprivileged non-root users, utilizing minimal base images to reduce the attack surface.
* **Network Isolation**: Our specific `docker-compose` network definitions strictly isolate backend services (like the database and Ollama bridge) from the public internet. Only the API Gateway is exposed.
* **Automated Rate Limiting**: All sensitive endpoints (Auth, API Keys) are protected by strict, adaptive rate limits by default to prevent abuse.

### Authentication & Secrets

* **Secure Defaults**: We enforce industry-standard JWT validation and API key hashing. Keys are never stored in plain text.
* **Encrypted Tunnels**: All traffic between local LLMs and the cloud proxy uses encrypted WebSocket tunnels (WSS) and SSH tunneling, ensuring data privacy in transit.
* **Production-Ready Configuration**: Our default configurations enforce HTTPS, secure headers (Helmet), and strict cookie policies out of the box.
