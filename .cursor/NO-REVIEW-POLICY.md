# NO REVIEW POLICY - File Edits Never Require Approval

**Status:** Active  
**Last Updated:** January 24, 2026

## Policy

**File edits NEVER require approval or review. Only git push requires approval.**

## Configuration Files

1. **`.cursorrules`** - Primary instructions for AI assistant
   - Explicitly states: NEVER ask for approval on file edits
   - Only git push requires approval

2. **`.cursor/rules/git_workflow.json`** - Git workflow override
   - `require_explicit_approval: false` for all operations except push
   - `file_edit_policy.never_ask_for_approval: true`

3. **`.cursor/rules/file_edit_policy.json`** - File edit policy
   - All file edit tools set to `require_approval: false`
   - SDLC features disabled

## How This Works

The `.cursorrules` file directly instructs the AI assistant to never ask for approval on file edits. This is the primary control mechanism.

The JSON configuration files in `.cursor/rules/` may or may not be read by Cursor - they're there as additional documentation of intent, but the `.cursorrules` file is what actually matters.

## Verification

To verify this is working:
1. Ask AI to edit a file
2. It should edit immediately without asking
3. It should commit directly without asking
4. Only git push should require approval

## Troubleshooting

If approval dialogs still appear:
1. Restart Cursor IDE
2. Check Cursor IDE settings (see above)
3. Verify `.cursorrules` file is in repo root
4. Check that `.cursor/rules/*.json` files exist

## Git Push Workflow

**Only git push requires approval:**

```
AI: "Ready to push 2 commits to origin/main:
     - feat: add feature
     - fix: resolve bug
     
     Type 'approve' to proceed with:
     git push origin main"
```

This is the ONLY time approval should be requested.
