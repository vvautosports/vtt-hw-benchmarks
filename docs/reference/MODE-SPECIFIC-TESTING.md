# Mode-Specific AI Model Testing

Test prompts and methodology for evaluating AI models across different coding assistant modes.

---

## Test Modes Overview

### Ask Mode
**Purpose:** Quick questions and explanations
**Context:** 4K-8K tokens
**Priority:** Speed > Quality
**Recommended Models:** GPT-OSS-20B, GLM-Q8

### Code Mode
**Purpose:** Write, modify, refactor code
**Context:** 16K-65K tokens
**Priority:** Speed + Context capacity
**Recommended Models:** GLM-Q8, GPT-OSS-20B (small files)

### Architect Mode
**Purpose:** Plan and design system architecture
**Context:** 16K-65K tokens
**Priority:** Reasoning > Speed
**Recommended Models:** REAP-218B, Qwen-235B

### Debug Mode
**Purpose:** Diagnose and fix issues
**Context:** 8K-32K tokens
**Priority:** Reasoning + Analysis
**Recommended Models:** REAP-218B, GLM-Q8

---

## Test Prompts by Mode

### Ask Mode Test Prompts

**Test 1: Simple Explanation (4K context)**
```
Explain what a Python decorator is and give a simple example.
```
**Expected:**
- Fast response (< 2 seconds for GPT-OSS-20B)
- Clear, concise explanation
- Working code example

**Test 2: Code Understanding (8K context)**
```python
# [Insert 200-line function here]

Explain what this function does, its time complexity, and potential optimizations.
```
**Expected:**
- Accurate analysis
- Complexity calculation
- Practical suggestions

**Success Criteria:**
- Response time < 5 seconds (GPT-OSS-20B)
- Response time < 10 seconds (GLM-Q8)
- Accurate technical details

---

### Code Mode Test Prompts

**Test 3: Function Generation (16K context)**
```
Create a Python class that implements a least-recently-used (LRU) cache with the following requirements:
- Fixed capacity
- O(1) get and put operations
- Thread-safe
- Type hints
- Comprehensive docstrings
- Unit tests

Include proper error handling and edge cases.
```
**Expected:**
- Working implementation
- Correct algorithm (doubly-linked list + hashmap)
- Complete test coverage

**Test 4: Multi-file Refactoring (32K context)**
```
Refactor this Flask application to use dependency injection and the repository pattern.
Files:
- app.py (main application)
- models.py (database models)
- routes.py (API endpoints)
- database.py (database connection)

Provide the refactored code for all files.
```
**Expected:**
- Coherent refactoring across files
- Maintains functionality
- Follows best practices

**Success Criteria:**
- Code compiles/runs
- Maintains original functionality
- Response time < 30 seconds (GLM-Q8)

---

### Architect Mode Test Prompts

**Test 5: System Design (32K context)**
```
Design a microservices architecture for a real-time collaborative document editing system similar to Google Docs.

Requirements:
- Support 10,000+ concurrent users
- Real-time synchronization (< 100ms latency)
- Conflict resolution
- Offline mode support
- Scalable to millions of documents

Provide:
1. System architecture diagram (text-based)
2. Service breakdown and responsibilities
3. Data models
4. Technology stack recommendations
5. Scaling strategy
6. Potential bottlenecks and solutions
```
**Expected:**
- Comprehensive design
- Consideration of trade-offs
- Practical technology choices
- Addressing scalability concerns

**Test 6: Architecture Decision (16K context)**
```
We need to choose between:
1. Monolithic architecture with microservices for specific components
2. Full microservices architecture
3. Event-driven architecture with CQRS

For a startup building a fintech platform handling:
- User authentication and authorization
- Payment processing
- Transaction history
- Analytics and reporting
- Third-party integrations (banks, credit bureaus)

Team size: 8 developers
Timeline: 6 months to MVP
Budget: Limited

Provide detailed analysis of each approach with pros/cons and final recommendation.
```
**Expected:**
- Deep analysis of trade-offs
- Consideration of business constraints
- Clear recommendation with justification

**Success Criteria:**
- Addresses all requirements
- Considers real-world constraints
- Response time acceptable (REAP: 30-60 seconds OK)

---

### Debug Mode Test Prompts

**Test 7: Bug Diagnosis (16K context)**
```python
# Production error log:
# TypeError: 'NoneType' object is not subscriptable
# File: app.py, Line 145

def process_user_data(user_id):
    user = db.query(User).filter(User.id == user_id).first()
    profile = user.profile  # Line 145
    return {
        'name': profile['name'],
        'email': profile['email']
    }

This works in dev but fails randomly in production.
Stack trace shows the error occurs about 5% of the time.
Database: PostgreSQL
ORM: SQLAlchemy
Framework: Flask

Diagnose the root cause and provide a fix with proper error handling.
```
**Expected:**
- Identify race condition / null handling issue
- Explain why it's intermittent
- Provide robust solution

**Test 8: Performance Issue (24K context)**
```
This API endpoint is slow (5-10 seconds response time):

[Insert 500 lines of code with multiple inefficiencies:
 - N+1 query problem
 - Inefficient algorithm
 - Missing database indexes
 - Unnecessary JSON serialization
]

Response time should be < 500ms.
Identify ALL performance issues and provide optimized solution.
```
**Expected:**
- Find multiple issues
- Prioritize fixes by impact
- Provide optimized code

**Success Criteria:**
- Identifies primary bottleneck
- Suggests correct optimizations
- Explains reasoning

---

## Benchmark Execution

### Running Mode-Specific Tests

```bash
# Test single model, single mode
./scripts/test-model-mode.sh GLM-Q8 ask

# Test single model, all modes
./scripts/test-model-mode.sh GLM-Q8 all

# Test all models, single mode
./scripts/test-all-models.sh code

# Comprehensive test suite (all models, all modes)
./scripts/comprehensive-ai-test.sh
```

### Evaluation Criteria

**Speed Metrics:**
- Time to first token (TTFT)
- Tokens per second (prompt processing)
- Tokens per second (generation)
- Total response time

**Quality Metrics:**
- Correctness (does code work?)
- Completeness (addresses all requirements?)
- Best practices (follows conventions?)
- Explanation clarity

**Context Metrics:**
- Maximum context successfully used
- Performance degradation with context size
- Memory usage at different context sizes

---

## Expected Results by Model

### GPT-OSS-20B (Best for Ask Mode)
- **Ask Mode:** ⭐⭐⭐⭐⭐ (fastest)
- **Code Mode:** ⭐⭐⭐ (good for small files)
- **Architect Mode:** ⭐⭐ (shallow analysis)
- **Debug Mode:** ⭐⭐ (surface-level)

**Recommendation:** Use for quick questions and single-file code tasks

### GLM-4.7-Flash-Q8 (Best Overall)
- **Ask Mode:** ⭐⭐⭐⭐ (fast)
- **Code Mode:** ⭐⭐⭐⭐⭐ (large context + speed)
- **Architect Mode:** ⭐⭐⭐ (good analysis)
- **Debug Mode:** ⭐⭐⭐⭐ (solid debugging)

**Recommendation:** Default choice for most tasks

### GLM-4.7-REAP-218B (Best for Reasoning)
- **Ask Mode:** ⭐⭐ (slow for simple questions)
- **Code Mode:** ⭐⭐⭐ (good but slower)
- **Architect Mode:** ⭐⭐⭐⭐⭐ (best reasoning)
- **Debug Mode:** ⭐⭐⭐⭐⭐ (deep analysis)

**Recommendation:** Use when quality matters more than speed

### Qwen3-235B-Q3 (Alternative Reasoning)
- **Ask Mode:** ⭐⭐ (slow)
- **Code Mode:** ⭐⭐⭐ (capable but slow)
- **Architect Mode:** ⭐⭐⭐⭐⭐ (excellent)
- **Debug Mode:** ⭐⭐⭐⭐⭐ (very deep)

**Recommendation:** Use for complex architecture when >65K context needed

---

## Ollama vs llama.cpp Comparison

### Testing Methodology

**When Ollama model is ready:**
```bash
# Load model in Ollama
ollama pull glm4.7  # or appropriate model

# Run comparison
./scripts/compare-ollama-llamacpp.sh glm4.7 /mnt/ai-models/GLM-4.7-Flash-Q8/GLM-4.7-Flash-UD-Q8_K_XL.gguf
```

**Metrics to Compare:**
1. **Inference Speed**
   - Prompt processing (t/s)
   - Text generation (t/s)
   - Time to first token

2. **API Overhead**
   - HTTP request/response latency
   - JSON serialization/deserialization
   - Connection pooling efficiency

3. **Memory Usage**
   - Base memory footprint
   - Peak memory during inference
   - Memory leaks over time

4. **Ease of Use**
   - API simplicity
   - Integration with editors
   - Multi-model switching

**Expected Results:**
- llama.cpp: Faster raw inference (no API overhead)
- Ollama: Easier integration, better for production
- Trade-off: Speed vs Developer Experience

**Current Status:**
- ❌ Ollama model not ready (model creation incomplete)
- ✅ llama.cpp baseline tests complete
- ⏸️ Awaiting Ollama model completion for comparison

---

## Credits

**Testing framework:**
- llama.cpp benchmarks
- AMD Strix Halo toolboxes by kyuz0
- VTT benchmark suite

**Prompt engineering:**
- Based on real-world coding assistant scenarios
- Tested against production use cases
- Validated with VV Collective team workflows

---

**Last Updated:** 2026-01-22
**Status:** Framework complete, Ollama comparison pending model availability
