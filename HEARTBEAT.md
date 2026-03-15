# HEARTBEAT.md

# Keep this file empty (or with only comments) to skip heartbeat API calls.

# Add tasks below when you want the agent to check something periodically.
## Zoidbot Internal Backlog

- [ ] **Fix Email Access**: Reconfigure `himalaya` for Christopher's accounts. Needs OAuth2 setup or app passwords.
- [ ] **Continuous Project Heartbeat**: Scheduled cron is active (`20844805-d656-4570-9f78-4952d3091c4b`).
- [ ] **Notion Sync Audit**: Verify all local `IDENTITY.md` and `USER.md` changes are reflected in Notion databases.
- [x] **Workspace Hygiene**: Auto-cleanup of `.trash` and redundant log files.
- [x] **Security Maintenance**: Fixed npm vulnerabilities (2026-03-15) - all npm audit issues resolved.
- [ ] **Git Repository Bloat**: .git is 1.9GB due to historical binary commits (Windows builds, AppImages, kubectl, cloudflared). Recommend BFG Repo-Cleaner or git-filter-repo to purge large files from history. Requires force push.
