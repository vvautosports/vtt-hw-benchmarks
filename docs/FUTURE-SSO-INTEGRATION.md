# Future SSO Integration with Authentik

**Status:** Planned for future implementation  
**Goal:** Enable users to authenticate with Gmail/Discord accounts via Authentik SSO

## Current State

- **Repository:** Public (no authentication needed for cloning)
- **Git Installation:** Automated via `HP-ZBOOK-SETUP.ps1`
- **Authentication:** None required for setup

## Future SSO Integration

### Phase 1: Authentik Setup
1. Deploy Authentik instance
2. Configure OAuth providers:
   - Google (Gmail)
   - Discord
3. Set up user provisioning

### Phase 2: GitHub Integration
1. Configure GitHub OAuth app
2. Link Authentik to GitHub
3. Enable SSO for vvautosports organization

### Phase 3: Automated User Onboarding
1. User authenticates via Authentik (Gmail/Discord)
2. Automatically provision GitHub access
3. Clone repository with SSO credentials
4. Run setup script (no manual git install needed)

## Benefits

- ✅ No manual git installation
- ✅ Seamless authentication flow
- ✅ Single sign-on across services
- ✅ Automatic user provisioning
- ✅ Better security and access control

## Implementation Notes

When SSO is implemented, the setup script will:
1. Check for Authentik authentication
2. Use SSO credentials for git operations
3. Automatically configure git with SSO user
4. Handle token refresh automatically

## Current Workaround

For now, the setup script:
- Automatically installs git (no user action needed)
- Clones public repository (no auth needed)
- Works immediately without any login

---

**Timeline:** TBD - After initial HP ZBook deployment is validated
