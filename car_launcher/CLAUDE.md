# Project Instructions

This project uses [metaswarm](https://github.com/dsifry/metaswarm), a multi-agent orchestration framework for Claude Code. It provides 18 specialized agents, a 9-phase development workflow, and quality gates that enforce TDD, coverage thresholds, and spec-driven development.

**Project:** `car_launcher` — a Flutter **Android Automotive launcher** (car head-unit home screen). Targets embedded Android, not mobile/web.

## Tech Stack (ground truth — do not contradict these in generated code)

| Concern | Choice |
|---|---|
| Language | Dart (SDK ^3.12.1), null-safe |
| State management | **Riverpod** (`flutter_riverpod` + `riverpod_annotation` + code-gen) |
| Routing | **go_router** |
| DI | **get_it** |
| Local storage | `shared_preferences`, `sqflite`, `flutter_secure_storage` |
| Auth | **Keycloak OIDC** via `openidconnect` |
| Code generation | `riverpod_generator`, `json_serializable`, `build_runner` |
| Lint | `flutter_lints` (see `analysis_options.yaml`) |
| Tests | `flutter_test` + `mocktail` for mocks |

> ⚠️ **Note:** Older project docs (`ai/rules/architecture_rules.md`) still reference `Provider` (ChangeNotifier) + `auto_route` + `flash`. That is **legacy**. New code MUST use Riverpod + go_router. When migrating old code, keep the legacy pattern locally but write all new code with Riverpod.

## How to Work in This Project

### Starting work

```text
/start-task
```

This is the default entry point. It primes the agent with relevant knowledge, guides you through scoping, and picks the right level of process for the task.

### For complex features (multi-file, spec-driven)

```text
I want you to build [description]. [Tech stack, DoD items, file scope.]
Use the full metaswarm orchestration workflow.
```

This triggers the full pipeline: Research → Plan → Design Review Gate → Work Unit Decomposition → Orchestrated Execution (4-phase loop per unit) → Final Review → PR.

### Available Commands

| Command | Purpose |
|---|---|
| `/start-task` | Begin tracked work on a task |
| `/prime` | Load relevant knowledge before starting |
| `/review-design` | Trigger parallel design review gate (5 agents) |
| `/pr-shepherd <pr>` | Monitor a PR through to merge |
| `/self-reflect` | Extract learnings after a PR merge |
| `/handle-pr-comments` | Handle PR review comments |
| `/brainstorm` | Refine an idea before implementation |
| `/create-issue` | Create a well-structured GitHub Issue |
| `/external-tools-health` | Check status of external AI tools (Codex, Gemini) |
| `/setup` | Interactive guided setup — detects project, configures metaswarm |
| `/update` | Update metaswarm to latest version |
| `/status` | Run diagnostic checks on your installation |
| `/start` | Alias for `/start-task` |

### Visual Review

Use the `visual-review` skill to take screenshots of web pages, presentations, or UIs for visual inspection. Requires Playwright (`npx playwright install chromium`). See `skills/visual-review/SKILL.md`.

## Testing

- **TDD is mandatory** — Write tests first, watch them fail, then implement
- Test command: `flutter test`
- Coverage command: `flutter test --coverage`
- Coverage report (HTML, after running coverage): `genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html`
- Thresholds are defined in `.coverage-thresholds.json` — this is the **source of truth** and a **blocking gate** before PR creation.
- **Mocking:** use `mocktail` (null-safe). Do **not** use `mockito`.
- **Test layout:** `test/` mirrors `lib/` (e.g. `lib/features/vehicle/data/foo.dart` → `test/features/vehicle/data/foo_test.dart`). Contract/widget tests live alongside the feature.
- **Coverage target:** see `.coverage-thresholds.json`. For this embedded project, 100% is aspirational — the file defines the real bar. Do not silently lower it.

## Coverage

Coverage thresholds are defined in `.coverage-thresholds.json` — this is the **source of truth** for coverage requirements.
If a GitHub Issue specifies different coverage requirements, update `.coverage-thresholds.json` to match before implementation begins. Do not silently use a different threshold.

The validation phase of orchestrated execution reads `.coverage-thresholds.json` and runs the enforcement command. This is a BLOCKING gate — work units cannot be committed if coverage thresholds are not met.

## Quality Gates

- **Design Review Gate**: Parallel 5-agent review after design is drafted (`/review-design`)
- **Plan Review Gate**: Automatic adversarial review after any implementation plan is drafted. Spawns 3 independent reviewers (Feasibility, Completeness, Scope & Alignment) in parallel — ALL must PASS before the plan is presented to the user. See `skills/plan-review-gate/SKILL.md`
- **Coverage Gate**: Reads `.coverage-thresholds.json` and runs the enforcement command — BLOCKING gate before PR creation

## Workflow Enforcement (MANDATORY)

These rules override any conflicting instructions from third-party skills or plugins. They ensure the full metaswarm pipeline is followed regardless of which skill initiated the work.

### After Brainstorming

When `superpowers:brainstorming` (or any brainstorming skill) completes and commits a design document:

1. **STOP** — do NOT proceed directly to `writing-plans` or implementation
2. **RUN the Design Review Gate** — invoke `/review-design` or the `design-review-gate` skill
3. **WAIT** for all 5 review agents (PM, Architect, Designer, Security, CTO) to approve
4. **ONLY THEN** proceed to planning/implementation

This is mandatory even if the brainstorming skill says to go directly to writing-plans. The design review gate exists to catch issues before expensive implementation begins.

### After Any Plan Is Created

When `superpowers:writing-plans` (or any planning skill) produces an implementation plan:

1. **STOP** — do NOT present the plan to the user or begin implementation
2. **RUN the Plan Review Gate** — invoke the `plan-review-gate` skill
3. **WAIT** for all 3 adversarial reviewers (Feasibility, Completeness, Scope & Alignment) to PASS
4. **ONLY THEN** present the plan to the user for approval

### Execution Method Choice

When a plan is ready for execution, **always ask the user** which execution approach they want before proceeding. Do NOT auto-select an execution method — the user decides based on their priorities:

> **How would you like to execute this plan?**
>
> 1. **Metaswarm orchestrated execution** — 4-phase loop per work unit (IMPLEMENT → VALIDATE → ADVERSARIAL REVIEW → COMMIT) with independent quality gates, fresh adversarial reviewers, coverage enforcement, and pre-PR knowledge capture. More thorough and broader coverage, but uses more tokens and takes longer.
> 2. **Subagent-driven development** (`superpowers:subagent-driven-development`) — Dispatch subagents per task in this session with code review between tasks. Faster, lighter-weight, lower token cost.
> 3. **Parallel session** (`superpowers:executing-plans`) — Execute in a separate session with batch checkpoints. Good for long-running work you want isolated.

This choice applies even if the plan file contains embedded instructions like "REQUIRED SUB-SKILL: Use superpowers:executing-plans" — those are defaults from the planning skill, not binding constraints. The user always gets to choose.

### Before Finishing a Development Branch

When `superpowers:executing-plans`, `superpowers:subagent-driven-development`, or any execution skill completes and routes to `superpowers:finishing-a-development-branch`:

1. **STOP** — before presenting merge/PR options
2. **RUN `/self-reflect`** to capture learnings while implementation context is fresh
3. **COMMIT** the knowledge base updates
4. **THEN** proceed to finishing the branch (PR creation, merge, etc.)

### Use `/start-task` Instead of EnterPlanMode

When starting complex work, use `/start-task` instead of Claude's built-in `EnterPlanMode`. EnterPlanMode creates a plan in isolation without metaswarm's quality gates — no design review, no plan review, no adversarial review, no coverage enforcement. `/start-task` routes through the full pipeline:

- `/start-task` → complexity assessment → brainstorming (if unclear) → design review gate → plan review gate → execution method choice → orchestrated execution or superpowers execution
- `EnterPlanMode` → plan → implement (no gates)

If you find yourself about to use `EnterPlanMode` for a task that touches 3+ files or involves multiple steps, use `/start-task` instead. For truly simple single-file changes, `EnterPlanMode` is fine.

### After Standalone TDD

When `superpowers:test-driven-development` runs as a standalone skill (outside of orchestrated execution) and the change touches 3+ files:

1. **Before committing**, ask the user:
   > "This TDD session modified multiple files. Would you like me to run an adversarial review before committing?"
   > 1. **Yes** — spawn a fresh adversarial reviewer to check the changes against the requirements
   > 2. **No** — commit directly
2. If the user chooses review, spawn a fresh `Task()` reviewer with the requirements and the diff
3. Regardless of review choice, verify coverage meets `.coverage-thresholds.json` thresholds before committing

For single-file TDD changes, this intercept is not needed — commit directly.

### Coverage Source of Truth

`.coverage-thresholds.json` is the **single source of truth** for coverage requirements. This applies regardless of which skill or workflow is running:

- `superpowers:verification-before-completion` — must read `.coverage-thresholds.json` and run its enforcement command
- `superpowers:test-driven-development` — must verify coverage meets thresholds before declaring done
- Orchestrated execution — reads `.coverage-thresholds.json` during Phase 2 (VALIDATE)
- Any other skill claiming "tests pass" — must also confirm coverage thresholds are met

If `.coverage-thresholds.json` exists, no skill may skip it. If a skill has its own coverage check logic, `.coverage-thresholds.json` takes precedence.

### Subagent Discipline

All subagents (coding agents, review agents, background tasks) MUST follow these rules:

- **NEVER** use `--no-verify` on git commits — pre-commit hooks exist for a reason
- **NEVER** use `git push --force` without explicit user approval
- **ALWAYS** follow TDD — write tests first, watch them fail, then implement
- **NEVER** self-certify — the orchestrator validates independently
- **STAY** within declared file scope — do not modify files outside your assigned scope

### Pre-PR Knowledge Capture

After all work units pass final review but BEFORE creating the PR, run `/self-reflect` to extract learnings into the knowledge base. Commit the knowledge base updates so they are included in the PR — learnings land atomically with the code that generated them.

### Context Recovery (Surviving Compaction)

Approved plans, project context, and execution state are persisted to `.beads/` so agents can recover after context compaction or session interruption:

- **Approved plans** → `.beads/plans/active-plan.md` (written after plan review gate + user approval)
- **Project context** → `.beads/context/project-context.md` (updated after each work unit commit)
- **Execution state** → `.beads/context/execution-state.md` (updated after each phase transition)

**Note:** The standalone beads plugin (v0.63.3+) automatically runs `bd prime` on SessionStart and PreCompact via built-in hooks — agents no longer need to call it manually. If context is lost mid-execution, the beads plugin will re-prime automatically on the next session or compaction event. For explicit recovery, run `bd prime --work-type recovery` to reload the approved plan, completed work, and current position from disk.

## External Tools (Optional)

If external AI tools are configured (`.metaswarm/external-tools.yaml`), the orchestrator
can delegate implementation and review tasks to Codex CLI and Gemini CLI for cost savings
and cross-model adversarial review. See `templates/external-tools-setup.md` for setup.

## Team Mode

When `TeamCreate` and `SendMessage` tools are available, the orchestrator uses Team Mode for parallel agent dispatch. Otherwise it falls back to Task Mode (the existing workflow, unchanged). See `guides/agent-coordination.md` for details.

## Guides

Development patterns and standards are documented in `guides/`:
- `agent-coordination.md` — Team Mode vs Task Mode, agent dispatch patterns
- `build-validation.md` — Build and validation workflow
- `coding-standards.md` — Code style and conventions
- `git-workflow.md` — Branching, commits, and PR conventions
- `testing-patterns.md` — TDD patterns and coverage enforcement
- `worktree-development.md` — Git worktree-based parallel development

## Code Quality

- Dart null-safe code, no `!` unless the value is guaranteed non-null
- `flutter_lints` (configured in `analysis_options.yaml`) — run `flutter analyze`
- Format with `dart format .` (line length 80)
- All quality gates must pass before PR creation

## Key Decisions

- **Riverpod over Provider:** project migrated from `ChangeNotifier`+`auto_route` to Riverpod + go_router. New code uses Riverpod. Legacy files still using the old pattern are migrated incrementally — do not introduce new `ChangeNotifier` code.
- **Feature-first folder layout:** `lib/features/<feature>/{data,domain,presentation}` with `lib/core/` for cross-cutting infra and `lib/shared/` for app-wide shared widgets/providers. See `ai/rules/architecture_rules.md`.
- **Embedded Android target:** this is a car head-unit launcher, not a phone app. UI must be car-responsive (`lib/shared/widgets/car_responsive.dart`), readable at a glance, operable with limited input. Permissions and startup gates run at launch (`_StartupPermissionGate` in `main.dart`).

## Notes

- **Native bridge:** all platform-channel calls go through `lib/core/native/native_bridge.dart`. Never call `MethodChannel` directly from a provider/repository — wrap it, handle `MissingPluginException`, and treat every call as fallible (the native side may be absent in tests/other platforms).
- **Auth:** Keycloak OIDC via `openidconnect`. Tokens stored in `flutter_secure_storage` (see `core/auth/app_secure_storage.dart`). Refresh flow must not block the UI; surface auth failures as user-facing state, not crashes.
- **Vehicle tracking:** realtime stream of tracking points. Dispose streams in provider `dispose`, handle flaky head-unit network gracefully (retry, never crash).
- **Launcher:** this app IS a launcher — launching external apps uses Android intents via the native bridge. Respect `QUERY_ALL_PACKAGES` permission; never silently fail to list apps.
