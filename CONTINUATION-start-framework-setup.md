# Continuation Prompt: Start Framework Setup in Cursor

## Context
- **Date:** 2026-01-18
- **Session Type:** PLAN + CODE (framework setup and template updates)
- **Issue:** GitHub Issue #16 - Phase 1: Framework Setup in Cursor - Dogfooding 5-Role Workflow
- **Goal:** Configure Cursor IDE for testing the 5-role workflow framework with Claude Code integration

---

## What We Need to Accomplish

### 1. Enhanced Cursor Agent Template
**Goal:** Update cursorrules-cursor-agent.template with Claude Code integration

**Requirements:**
- Include Claude Code commands integration (/commit, /run, /save, /models)
- Model routing based on agent role (Haiku for ASK/TEST, Sonnet for PLAN/CODE/DEBUG)
- Session management protocols and commit message standards
- Framework-specific shortcuts and references

### 2. Pilot Environment Setup
**Goal:** Test 5-window setup in Cursor IDE

**Requirements:**
- Open 5 Cursor windows (ASK, PLAN, CODE, TEST, DEBUG)
- Load appropriate templates in each window
- Validate cross-window communication
- Test Claude Code commands in Cursor terminal

### 3. Framework Validation
**Goal:** Ensure all components work together

**Requirements:**
- Test handoff protocols between roles
- Validate Claude Code integration in real usage
- Document any setup issues or refinements needed
- Prepare for Phase 2 real work examples

---

## Implementation Tasks

### Task 1: Update Cursor Agent Template
**File:** templates/agents/cursorrules-cursor-agent.template

**Additions needed:**
1. **Claude Code Integration Section**
   ```markdown
   ## Claude Code Integration
   **Session Commands:**
   - `/commit` - Commit with proper message format
   - `/run [command]` - Execute tests/validations
   - `/save [name]` - Save session state
   - `/models [model]` - Switch models per role

   **Commit Format:**
   ```
   feat: [changes]

   [description]

   Addresses: [context]
   Next: [continuation]

   Co-Authored-By: Claude Code <noreply@anthropic.com>
   ```
   ```

2. **Role-Specific Configuration**
   - ASK Agent: claude-3-5-haiku
   - PLAN Agent: claude-3-5-sonnet
   - CODE Agent: claude-3-5-sonnet
   - TEST Agent: claude-3-5-haiku
   - DEBUG Agent: claude-3-5-sonnet

3. **Framework References**
   - Load framework: @../vvt-operations/docs/design/4-window-agent-framework.md
   - Load standards: @../vvt-operations/standards/

### Task 2: Test 5-Window Setup
**Validation Steps:**
1. Open 5 Cursor windows
2. Load appropriate agent templates in each
3. Test Claude Code commands in terminal
4. Attempt basic cross-window communication
5. Document setup time and any issues

### Task 3: Framework Validation
**Test Scenarios:**
1. **Model Switching:** Test /models command per role
2. **Session Management:** Test /save and /commit commands
3. **Handoff Protocol:** Create test handoff between windows
4. **Reference Loading:** Test @../vvt-operations/ path loading

---

## Success Criteria

**Template Complete When:**
- [ ] Claude Code integration section added
- [ ] Role-specific model recommendations configured
- [ ] Session management protocols documented
- [ ] Framework references included

**Setup Validated When:**
- [ ] 5 Cursor windows can be configured
- [ ] Claude Code commands work in terminal
- [ ] Cross-window communication possible
- [ ] Basic framework loading works

**Issue #16 Complete When:**
- [ ] Template updated and committed
- [ ] Setup process documented
- [ ] Known issues identified for framework refinements
- [ ] Ready for Phase 2 real work examples

---

## Files to Create/Modify

**Primary:**
- templates/agents/cursorrules-cursor-agent.template (enhance with Claude Code)

**Reference:**
- docs/design/4-window-agent-framework.md (confirm 5-role updates)
- CONTINUATION-dogfooding-workflow-framework.md (Phase 1 details)

---

## Testing Protocol

### Setup Test Checklist
- [ ] Open 5 Cursor windows simultaneously
- [ ] Load cursorrules-cursor-agent.template in each
- [ ] Identify windows with role-specific markers
- [ ] Test Claude Code terminal commands
- [ ] Attempt basic cross-window handoff

### Validation Commands
```bash
# In Cursor terminal:
/models haiku  # Test model switching
/save test-session  # Test session saving
/commit -m "feat: test framework setup

Testing Claude Code integration in Cursor

Addresses: #16
Next: Phase 2 documentation updates"
```

---

## Risk Mitigation

### Known Challenges
1. **Multiple Windows:** Cursor may have performance issues with 5 windows
   - **Mitigation:** Test with 3 windows first, scale up

2. **Claude Code Integration:** Commands may not work as expected
   - **Mitigation:** Document actual behavior vs expected

3. **Model Switching:** Manual model changes per window
   - **Mitigation:** Note pain points for future automation

### Fallback Plans
- If multi-window overwhelming: Focus on template updates first
- If Claude Code issues: Use terminal git commands as backup
- If setup too complex: Document simplified version for team

---

## Next Session Preparation

**Immediate Actions:**
1. Update cursorrules-cursor-agent.template
2. Test Claude Code integration
3. Open 5 windows for validation
4. Document setup process

**For Next Session:**
- Move to Phase 2: Update cheat sheet (#18)
- Or tackle infrastructure cleanup (#20)
- Or update setup guide (#19)

**Questions for Next Session:**
1. **Claude Code Behavior:** How do the commands actually work in your setup?
2. **Window Management:** Any Cursor-specific tips for managing multiple windows?
3. **Priority:** Which Phase 2 task should we tackle next?

---

## Commit Message (When Complete)

```
feat: enhance cursor agent template with claude code integration

- Add Claude Code session commands (/commit, /run, /save, /models)
- Configure role-specific model recommendations
- Add session management protocols and commit standards
- Test 5-window setup in Cursor IDE
- Document setup process and framework validation

Addresses: #16 (Phase 1: Framework Setup in Cursor)
Next: Phase 2 documentation updates (#18, #19, #20)

Co-Authored-By: Claude Code <noreply@anthropic.com>
```

---

**[FOR CODE AGENT]**

This continuation prompt is ready for implementation. Start by updating the Cursor agent template, then test the 5-window setup with Claude Code integration.