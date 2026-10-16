# Standing rules - every project, every session (generic spine; merge into ~/.claude/CLAUDE.md)

## Always track the work in the todo tool
- Any task with more than one step gets a todo list before the work starts (TodoWrite, or TaskCreate/TaskUpdate where those are the tools you have). Exactly one item in progress; mark each completed the moment it is done; add items as new work appears.
- The tool exists only because `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` is set in `~/.claude/settings.json` `env`. Do not remove it.
- If neither TodoWrite nor TaskCreate is in your tool list (check deferred tools too), say so in your first message instead of silently working without it.

## Gos and secrets (hard rules)
- A **go** for a merge, staging deploy, prod deploy, prod DB read/write, secret write or money operation is typed by the operator first-hand in the tab of the session that will do it. Nobody relays a go, a board answer is never a go, a scheduled prompt never widens a standing exception. A merge go never covers a deploy; a staging go never covers prod.
- Never print a secret value. Report key NAMES only. That includes `get-secret-value`, `printenv`, `env`, and dumping `process.env`. No hand-rolled redactors.
- Verify every claim yourself (SHA, CI, deploy) with the tool that owns the fact; a ticket's status is not evidence.

## Working mode - routed by blast radius, not by difficulty
The routing question is never "is this hard". It is: *if the answer is confidently wrong, what catches it, and when?* Nothing catching it is what buys a workflow.

| Situation | Mode |
|---|---|
| Changing high-blast code ({{HIGH_BLAST_PATHS}}: money, auth, migrations, prod data) or a question no executing test can settle | guarded mode: cheap-wide evidence, then adversarial refutation; read-only, proposes, never edits |
| Operator question about one specific customer/account | read-only prod query FIRST, then solo from live rows plus code at the deployed SHA. Send only an unresolved claim with no executing test to ONE `refuter` |
| Cross-service deploy ordering; migrations that split a state machine | workflow, adversarial panel |
| Reviewing a branch or PR | diff-scoped review with the explicit file list |
| Several agents would each read the same memory/planning corpus | digest once (`digester`), inject the brief |
| A wrong answer is caught by a compiler, a test that really executes, or a human looking at a screen | solo, no workflow |
| Mechanical, well-specified, single-file | solo, no workflow |
| Unknown-size discovery, or a stateful surface with no oracle | workflow - but first ask whether the missing oracle is the actual deliverable (`oracle-scout`) |

## Token cost is a hard constraint
- Spend is dominated by CONTEXT (cache-read + cache-write was 86% in one measured day), not thinking; subagents were 73% and main loop 27%. Every new agent pays a fresh cache-write of its whole prefix: fan-out width is a direct cost.
- The concurrency cap (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`) is per session; N sessions x cap is the real ceiling.
- Call count drives cost, not thread age: an idle thread is free; never close one to save tokens.
- Do not pin effort/ultracode globally; the operator picks the tier per thread (the model picker writes `modelSettings.<model>.effortLevel` by design).
- Sessions auto-compact at ~50% of the window (see `CLAUDE_CODE_AUTO_COMPACT_WINDOW`); keep state durable at all times.

## Any workflow you author
- **Cheap-wide, expensive-narrow.** Retrieval, enumeration and citation run on `retriever`/`digester` (sonnet, low effort). Judgment, refutation and synthesis run on `refuter` or unpinned. Never fan out the big model to read files.
- **Fan-out caps at the machine's CPU budget** (8 on a 10-CPU box). A 18-agent wave runs in three batches: slower AND three times the tokens.
- **One corpus read per run, not N.** Digest once, inject the brief.
- **Every verifier returns an artifact**: a command and its output, a `path:line`, or a mutation and the test that went red. Prose is not a verdict.
- **Log what you dropped.** A cap, a top-N or a skipped stage that is silent reads as full coverage.
- Serialize the edits, parallelize the thinking: a workflow cannot write conflicting edits to one file.

## Still mandatory
1. Write memory at every milestone. 2. Durable plans and decision docs to the project's planning dir. 3. Correct the record when you are wrong: the ticket, the plan and the memory, not just the chat. 4. A rule triggered by the shape of a tool call belongs in a hook, not in memory.
