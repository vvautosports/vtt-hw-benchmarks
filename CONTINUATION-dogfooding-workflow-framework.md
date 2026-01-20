# Continuation Prompt: Dogfooding 5-Role Workflow Framework

## Context
- **Date:** 2026-01-18
- **Session Type:** PLAN + CODE (dogfooding workflow testing in Cursor)
- **Issue:** Framework testing and Claude Code integration
- **Goal:** Pilot 5-role framework in vvt-operations using Cursor + Claude Code

---

## What We Need to Accomplish

### 1. Framework Testing Strategy
**Dogfooding Plan:** Apply the 5-role workflow framework to vvt-operations itself
- Use vvt-operations as the testbed to validate the framework
- Test all 5 roles (ASK, PLAN, CODE, TEST, DEBUG) in Cursor
- Integrate Claude Code for session management and commits
- Document learnings and iterate

### 2. Claude Code Integration
**Session Management:** Enhanced with Claude Code
- `/commit` - Commit current changes with proper messages
- `/run` - Execute tests and commands
- `/save` - Save current session state
- `/models` - Switch models per role requirements
- Session wrapping with progress tracking

### 3. Cursor Template Updates
**Enhanced cursorrules-cursor-agent.template:**
- Include Claude Code commands integration
- Model routing based on agent role
- Session management protocols
- Framework-specific shortcuts

---

## Implementation Phases

### Phase 1: Framework Setup in Cursor
**Goal:** Configure Cursor for 5-role workflow testing

**Tasks:**
1. **Update Cursor Agent Templates**
   - Add Claude Code integration to `cursorrules-cursor-agent.template`
   - Include session management commands
   - Add role-specific model preferences

2. **Create Pilot Environment**
   - Open 5 Cursor windows (one per role)
   - Configure each with appropriate template
   - Test cross-window communication

3. **Claude Code Integration Setup**
   - Configure Claude Code in Cursor terminal
   - Test `/commit` and `/run` commands
   - Set up session saving protocols

### Phase 2: Test Framework with Real Work
**Goal:** Use framework to complete pending updates

**Tasks:**
1. **Update Cheat Sheet (TEST role addition)**
   - PLAN: Design 5-role cheat sheet updates
   - CODE: Implement changes to `multi-agent-cheatsheet.md`
   - TEST: Validate updates work correctly
   - DEBUG: Fix any issues found

2. **Update Setup Guide (5 roles)**
   - PLAN: Design setup guide changes
   - CODE: Update `multi-agent-workflow-setup.md`
   - TEST: Test setup instructions
   - DEBUG: Resolve any setup issues

3. **Complete Infrastructure Cleanup**
   - PLAN: Review vvt-infrastructure cleanup requirements
   - CODE: Implement cross-repo references
   - TEST: Validate references work
   - DEBUG: Fix any reference issues

### Phase 3: Documentation & Iteration
**Goal:** Document learnings and refine framework

**Tasks:**
1. **Create Pilot Report**
   - Document what worked well
   - Identify pain points
   - Capture Claude Code integration insights

2. **Framework Refinements**
   - Update templates based on testing
   - Add missing automation scripts
   - Refine handoff protocols

3. **Team Rollout Preparation**
   - Update team documentation
   - Create onboarding guide
   - Prepare tool-specific instructions

---

## Claude Code Integration Details

### Session Management Commands
```bash
# In Cursor terminal with Claude Code:
/commit -m "feat: update cheat sheet for 5 roles

- Add TEST role section
- Update DEBUG role description
- Add workflow examples with TEST

Addresses: Framework testing in vvt-operations
Next: Update setup guide"

/run npm test  # Run tests
/run ./scripts/validate-cross-references.sh  # Custom validation

/save session-progress  # Save current work state
/models haiku           # Switch to fast model for ASK
/models opus            # Switch to reasoning model for PLAN
```

### Commit Message Standards
**Template:**
```
feat: [description of changes]

[Detailed explanation of what was implemented]

Addresses: [issue or context]
Next: [what comes next in the workflow]

Co-Authored-By: Claude Code <noreply@anthropic.com>
```

### Session Wrapping Protocol
**End of session:**
1. `/commit` - Commit all changes
2. `/save` - Save session state
3. Create continuation file if work spans sessions
4. Update progress in appropriate issue/PR

---

## Updated Cursor Agent Template

### Enhanced cursorrules-cursor-agent.template
```markdown
# Cursor IDE Agent Configuration
# 5-Role Workflow Framework with Claude Code Integration

## Framework Context
Load framework: @../vvt-operations/docs/design/4-window-agent-framework.md
Load standards: @../vvt-operations/standards/

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

## Role-Specific Configuration

### ASK Agent (Fast responses)
Model: claude-3-5-haiku
Template: @../vvt-operations/templates/agents/cursorrules-ask-agent.template

### PLAN Agent (Architecture)
Model: claude-3-5-sonnet
Template: @../vvt-operations/templates/agents/cursorrules-plan-agent.template

### CODE Agent (Implementation)
Model: claude-3-5-sonnet
Template: @../vvt-operations/templates/agents/cursorrules-code-agent.template

### TEST Agent (Automated testing)
Model: claude-3-5-haiku
Template: @../vvt-operations/templates/agents/cursorrules-test-agent.template

### DEBUG Agent (Bug diagnosis)
Model: claude-3-5-sonnet
Template: @../vvt-operations/templates/agents/cursorrules-debug-agent.template

---

## Testing Protocol

### Window Setup Test
1. Open 5 Cursor windows
2. Load appropriate template in each
3. Test cross-window communication
4. Validate Claude Code commands work

### Workflow Test (Cheat Sheet Update)
1. **PLAN window:** Design cheat sheet updates
2. **CODE window:** Implement changes
3. **TEST window:** Validate changes
4. **DEBUG window:** Fix issues found
5. **ASK window:** Quick clarifications

### Cross-Repo Reference Test
1. Update vvt-infrastructure references
2. Test `@../vvt-operations/` paths work
3. Validate in multiple Cursor windows

---

## Success Criteria

**Pilot Complete When:**
- [ ] 5-role workflow tested end-to-end in Cursor
- [ ] Claude Code integration working smoothly
- [ ] Cheat sheet updated for 5 roles
- [ ] Setup guide updated for 5 roles
- [ ] vvt-infrastructure cleanup complete
- [ ] Pilot report documenting learnings
- [ ] Framework refinements identified

**Quality Gates:**
- All commits follow proper format
- Session states saved appropriately
- Cross-window handoffs work smoothly
- Claude Code commands integrated naturally

---

## Risk Mitigation

### Known Challenges
1. **Context Switching:** Multiple windows may cause confusion
   - **Mitigation:** Clear window labeling, handoff protocols

2. **Model Switching:** Manual model changes per role
   - **Mitigation:** Document optimal models per role

3. **Session Management:** Tracking progress across windows
   - **Mitigation:** Use continuation files, clear commit messages

### Fallback Plans
- If Claude Code integration issues: Use terminal git commands
- If multi-window confusing: Test roles sequentially first
- If context mixing: Restart windows with fresh context

---

## Next Session Preparation

**Immediate Actions:**
1. Create this continuation file
2. Open 5 Cursor windows for testing
3. Load appropriate templates
4. Test Claude Code integration
5. Begin with cheat sheet update

**For Next Session:**
- Continue with setup guide updates
- Complete infrastructure cleanup
- Create pilot report

---

## Questions for Next Session

1. **Claude Code Integration:** Any specific commands or workflows you want prioritized?

2. **Testing Scope:** Should we focus on specific types of work (documentation updates, code changes, cross-repo references)?

3. **Success Metrics:** What specific outcomes indicate the framework is working well?

4. **Team Rollout:** How do you want to introduce this to the team after piloting?

---

**[FOR CODE AGENT]**

This continuation prompt is ready for implementation. Start by testing the framework setup in Cursor, then proceed with the cheat sheet updates as the first real work example.
