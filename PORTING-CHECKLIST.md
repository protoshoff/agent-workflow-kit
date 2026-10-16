# PORTING-CHECKLIST.md - decisions the new project's GK must make BEFORE workers start

Write each answer into `.gatekeeper/BOARD.md` (RESUME block / sections) and the placeholders in `KICKOFF.md`. "Original" = the example value from the setup this kit was extracted from, so you see the shape.

| # | Decision | Where it lands | Original (example only) |
|---|---|---|---|
| 1 | **Operator + handle in gates.** Display name and lowercase handle; the handle is the board `gate` value and the tracker username | `{{OPERATOR}}`, `{{OPERATOR_HANDLE}}`, `live-board.html` `OP` | operator "Mike", gate value `mike`; agentIds `mike-<role>` |
| 2 | **Peer team / other operator** (or none: delete `relay`/`peer` gates and "Pass along") | `{{PEER_TEAM}}` | a second operator whose sessions share the repos; cross-team holds go through both operators |
| 3 | **Lanes and owners.** One lane = repo(s) + backend module + owner; a lane gets one worker | roster + BOARD Sessions table | 5 lanes (customer web, pro dashboard, admin, customer mobile, infra/ops) + a "crew apps" lane held back |
| 4 | **Repos** and which are single-repo vs multi-repo; base/main branch name; PR target; "no rebase, merge main in" rule | `{{BACKEND_REPO}}`, `{{MAIN_BRANCH}}` | 9 separate git repos, `master`, PRs to `master` on the org repo |
| 5 | **Tracker + status rules.** Which tool, the claim call, done status, the "note first, status last, read back" rule, who may close | `{{TRACKER}}`, `{{TRACKER_CLAIM_CALL}}`, `{{DONE_STATUS}}`, rule 4 | Mantis; `assigned`+handler in one call; `feedback` only when live in prod; operator closes manually |
| 6 | **Deploy targets, environments, clusters.** Staging before prod; what "pin" means (full SHA); first-parent-only, forward-only; deploy tool; deploy-window lease (who may claim) | `{{DEPLOY_TOOL}}`, `{{DEPLOY_WINDOW_MECHANISM}}`, rule 3 | 2 ECS clusters (prod/staging), 7 services, a deploy script pinned to the SHA, a memory-service lease (20 min default, 60 max) |
| 7 | **Money / high-blast paths** that trigger guarded mode instead of solo | `{{HIGH_BLAST_PATHS}}`, `{{MONEY_LENS}}`, global routing table | payments app, stripe lib, commission, invoices, subscriptions; the rule: a one-customer operator question is a read-only prod query first, NOT the guarded mode |
| 8 | **Shared-code single-owner rule** and **migration serialization**: who may claim, how recorded (tracker note), whether GK may grant file-scoped claims when file sets are provably disjoint | `{{SHARED_CODE_PATHS}}`, BOARD "Shared-code claims" | `libs/common` single owner; one migration slot at a time; GK file-scoped claims allowed by operator ruling |
| 9 | **The hard rules** (keep these, they prevent merge chaos): shared code single-owner; migrations serialized; one lane owns its tickets end to end; goes are first-hand; every merge has CLEARED @ SHA + green CI | BOARD RESUME, global CLAUDE.md | "the 3 hard rules" + merge gate checklist |
| 10 | **Oracles (tests that really execute).** For each surface: which test/CI step fails if the change is wrong? Run the `oracle-scout` agent; where the answer is "nothing", the missing oracle is the deliverable before any workflow | planning doc; routing table | backend real-Postgres integration specs = oracle; mobile offline tests mocked the DAO, CI compiled but never ran device tests = no oracle |
| 11 | **Heavy-test wrapper** (serialize full suites, cap workers) and **pre-push check** | `{{HEAVY_TEST_WRAPPER}}`, `{{PRE_PUSH_CHECK}}` | a lock-file wrapper, `maxWorkers=2`; a type-check ratchet before push |
| 12 | **Memory location + architecture**: durable facts in a git-reviewed dir loaded each session; ephemeral task state in the memory service/MCP; size cap of the always-loaded index | project `CLAUDE.md`, `{{MEMORY_PROJECT_ID}}` | `garbago-knowledge/memory/` (index capped ~24KB) + agentdesk memory MCP for task_state |
| 13 | **Standing read-only exceptions** granted per tab, and their limit (counts and names only, never DB reads/writes/secrets) | `{{STANDING_EXCEPTION}}`, `{{GRANT_DATE}}` | read-only CloudWatch queries + ECS task-def reads by GK and Deploys |
| 14 | **Timezone for LOG/board** | `{{TZ}}` | America/Phoenix |
| 15 | **Roster** actually needed (delete unused roles from `roster.txt` + KICKOFF) and the cap on workers one person can follow | `roster.txt` | 3 workers at a time was the human limit |
| 16 | **Nightly checks**: what Deploys checks (log markers + a control proving the logs were read), report time, GK backstop time, how many clean nights retire a marker | BOARD "Scheduled prompts" | ~22:45 local check, GK backstop 15 min later, 7 clean nights |
| 17 | **Compaction policy** window value | `AUTO_COMPACT_WINDOW` | 500000 (50% of 1M) |
| 18 | **Drain mode** rule for when the operator is away | KICKOFF GK routine | one unattended night burned ~80% of two days' tokens |
| 19 | **Docs-on-change duty** (does a feature change need a help-doc ticket?) and the done-means-documented rule | BOARD / CLAUDE.md | help-center articles are code; grep routes/keywords on change |
| 20 | **Cost cap**: subagent concurrency, which agents are Opus vs Sonnet | `settings.fragment.json`, `claude-home/agents/*.md` | cap 8; `refuter` opus, `retriever`/`digester` sonnet |
| 21 | **Secrets policy**: where credentials live, who may read, "names not values" | global CLAUDE.md | never print env or secret payloads; 5 prior leaks motivated it |
| 22 | **Peer-team deploy coordination** (announce what a forward-only deploy carries; no blanket freeze) | BOARD | each side deploys its own work |

Also decide before the first worker: the live-board URL (publish first), the first tickets per worker, and who writes the first `DEPLOYS-HANDOFF.md` (an example of that file shape is not included because it is full of project state; it listed prod/staging revisions, queue order, rules, and "Mike-only waits").
