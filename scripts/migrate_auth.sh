#!/bin/bash
# scripts/migrate_auth.sh
# Stub for Supabase -> Auth0 migration (no data migration needed for fresh setup)

echo "=== CloudToLocalLLM Auth Migration Stub ==="
echo "No user data migration required for fresh Auth0 setup."
echo ""
echo "For existing Supabase users (manual):"
echo "1. Export users: supabase auth export-users --project-ref \$PROJECT_REF > users.json"
echo "2. Create Auth0 users via Management API:"
echo "   curl -H \"Authorization: Bearer \$MGMT_TOKEN\" \"
echo "     -H \"Content-Type: application/json\" \"
echo "     -d @users.json \"
echo "     https://\$DOMAIN.auth0.com/api/v2/users"
echo ""
echo "Update AppConfig.authProvider = AuthProviderType.auth0"
echo "Remove Supabase config/env vars"
echo "Test: flutter run -- login flow"
echo ""
echo "Migration complete - Auth0 PKCE flow active."
