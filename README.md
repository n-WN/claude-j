# claude-j

A drop-in wrapper around [Claude Code](https://docs.claude.com/en/docs/claude-code/overview)
that auto-tiles every subagent into its own [zellij](https://zellij.dev) pane,
so you can watch them work in parallel.

```
┌────────────────────────┬───────┐
│                        │ agent1│  ← first subagent splits Right (~2/7)
│                        ├───────┤
│      claude-main       │ agent2│  ← subsequent split Down,
│       (~5/7 wide)      ├───────┤     heights auto-rebalance to total/N
│                        │ agent3│
└────────────────────────┴───────┘
```

Each pane tails one agent's transcript only — streams stay isolated,
no interleaving. Idle for 30 minutes → pane self-closes; activity
resumes → pane re-opens.

## Demo

> _Asciinema cast goes here once recorded — see [`demo/record.sh`](demo/record.sh)._

## Why

Claude Code's built-in `Agent` tool is opaque: you fire it, you get the
final result. With `claude-j` you see every tool call, every reply, in
real time, in a side pane that doesn't disturb your main conversation.

Useful when:
- spawning many agents in parallel and wanting to babysit them all at once
- debugging a slow subagent that's stuck on something
- handing the screen to a colleague who wants to watch the work happen

## How it works

No Claude binaries are patched. The wrapper relies entirely on
on-disk artifacts that Claude Code already produces:

| Component | Job |
|---|---|
| `claude-j` | renames the current pane → forks a watcher pinned to its own PID → `exec claude`. After exec, PID = claude's PID, so the watcher can find the right session via `~/.claude/sessions/<pid>.json`. |
| `subagent-watch` | polls `~/.claude/projects/<cwd>/<session>/subagents/` every 0.5s. New `agent-<id>.meta.json` → `zellij run` a fresh pane. |
| `subagent-render` | per-pane Python tailer: pretty-prints `user`/`assistant`/`tool_use`/`tool_result` events from one `agent-<id>.jsonl`. Writes a `.alive-<id>` sentinel; trap-removes it on exit. Self-exits after `SUBAGENT_IDLE_CLOSE_SECS` (default 1800) of no new lines. |
| `subagent-rebalance` | after every spawn: `zellij action list-panes --json` → equalise heights of all `agent:*` panes via iterative `resize` calls (zellij has no absolute resize, only ±5% steps). |

The "spawn signal" is the appearance of `agent-<id>.meta.json` on disk —
that's Claude's own write, observable without hooking any internals.
The wrapper ignores agents whose `jsonl` is still empty so stillborn
agents don't open empty panes.

When the renderer self-exits on idleness, `--close-on-exit` on the zellij
pane collapses it. The watcher notices `.alive-<id>` is gone *and* the
agent's `jsonl` has grown since last spawn → reopens a fresh pane.

## Requirements

- macOS or Linux
- [zellij](https://zellij.dev) ≥ 0.44 (for `list-panes --json --geometry` and `-p <pane-id>` resize)
- [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) ≥ 2.1.x
- `jq`, `python3` ≥ 3.10

## Install

```bash
git clone https://github.com/<you>/claude-j.git
cd claude-j
./install.sh         # symlinks bin/* into ~/bin
```

Make sure `~/bin` is on your `PATH`.

## Usage

```bash
zellij                # start (or attach) a zellij session
claude-j              # inside it, instead of `claude`
```

Spawn a subagent the way you normally would and watch the right column
populate. Override defaults via env vars:

```bash
SUBAGENT_IDLE_CLOSE_SECS=600 claude-j     # close idle panes after 10 min
SUBAGENT_RESIZE_STEPS=5 claude-j          # narrower right column (5×5% shrink)
```

There's also a manual escape hatch:

```bash
subagent-pane                  # opens one big pane that follows ALL subagents
subagent-pane --list           # list current session's subagents
subagent-render --list         # same, for scripting
```

## Known limits

| Limit | Why | Workaround |
|---|---|---|
| Right column ≈ 30%, not exactly 5/7 (28.6%) | zellij `resize` is incremental (~5% per step) | bump `SUBAGENT_RESIZE_STEPS` |
| Heights rebalance to within ±2 rows of equal | zellij resize step ≈ 3 rows on a 60-row column — finer is impossible without overriding the whole layout | accept it; it's visually equal |
| Focus dance fragile if you manually focus a non-claude pane right before a spawn | watcher uses direction-based focus — no focus-by-id in zellij CLI | stay in the claude pane while spawning |
| Resuming an old session re-opens panes for *every* prior subagent that has content | `FIRST_SEEN` is in-memory, fresh on each `claude-j` invocation | open a PR if this annoys you — it's a 5-line patch |

## Design notes

- **Why fs polling, not a Node hook into the Anthropic SDK?**
  We considered `NODE_OPTIONS=--require=hook.js` to intercept Agent
  dispatch — would give ~10ms spawn latency vs ~300ms here. Rejected
  because every Claude Code release re-mangles its bundle, so the hook
  would break on upgrades. The fs signal is in the public API surface
  Claude already commits to.

- **Why per-pane renderer instead of one demuxer?**
  Stream isolation is enforced by construction: each pane is a separate
  process tailing exactly one file. No interleaving possible. The
  `.alive-<id>` sentinel pattern (write on start, trap-remove on exit)
  lets the watcher distinguish "pane closed by user/idle" from "agent
  truly done", and re-spawn precisely when there's new data.

- **JSON field names are hardcoded.**
  zellij's `list-panes --json` shape is undocumented. Field names
  (`title`, `pane_rows`, `pane_y`, `is_plugin`, `exited`, `id` as bare int)
  were probed against zellij 0.44 and are likely to change in major
  releases. If `subagent-rebalance` silently does nothing, that's the
  first place to look.

- **Session id detection has three strategies, in order.**
  1. Walk parent process tree → match against `~/.claude/sessions/<pid>.json`. Only works when you're a child of the claude process.
  2. Scan all `~/.claude/sessions/*.json` for live PIDs whose `cwd` matches `$PWD`; pick the one with newest `updatedAt`.
  3. Fall back to "session whose most recent user-typed message has the latest timestamp".

## License

MIT — see [`LICENSE`](LICENSE).
