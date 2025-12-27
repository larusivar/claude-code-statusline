# Claude Code Statusline

A custom statusline for [Claude Code](https://github.com/anthropics/claude-code) that shows context usage, session stats, and more.

```
Claude Sonnet 4 | ███░░░░░░░░░░░│ 31% mcp:4 +1.5k -287 [2h|↓1.2m↑0.3m|$4]
```

## Features

- **Model name** — current model in teal
- **Context usage bar** — visual representation of your context window:
  - Dark teal: cached tokens from session start
  - Medium teal: session growth (new cache since start)
  - Light cyan: tokens added this turn
  - Red separator marks the end
- **Percentage** — how much of the context window is used
- **MCP servers** — count of active MCP servers (if any)
- **Lines changed** — `+added` `-removed` during session
- **Session stats** — `[hours|↓input↑output|$cost]`

## Installation

### Requirements

- `jq` — install with `brew install jq` (macOS) or `apt install jq` (Linux)

### Setup

1. Download the script:
   ```bash
   curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/larusivar/claude-code-statusline/main/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Add to your Claude Code settings (`~/.claude/settings.json`):
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh"
     }
   }
   ```

3. Restart Claude Code to see the statusline.

## Customization

### Colors

Edit the color variables at the top of `statusline.sh`:

```bash
C_MODEL=73    # Model name: teal
C_DIM=102     # Dim text: gray
C_CACHED=30   # Cached tokens: dark teal
C_GROWTH=73   # Session growth: medium teal
C_NEW=116     # New tokens: light cyan
C_SEP=167     # Bar separator: red
C_MCP=109     # MCP count: muted cyan
C_ADD=33      # Lines added: blue
C_DEL=208     # Lines removed: orange
C_UP=179      # Upload: gold
```

Colors use the 256-color palette. See [256 colors cheat sheet](https://www.ditig.com/256-colors-cheat-sheet) for options.

### Bar Width

Change `BAR_WIDTH` to adjust the context bar size:

```bash
BAR_WIDTH=15  # Default (14 blocks + 1 separator)
```

## How It Works

Claude Code passes JSON to the statusline script via stdin. The script parses it with `jq` and renders the output.

### Input JSON Structure

```json
{
  "model": { "display_name": "Claude Sonnet 4" },
  "workspace": { "current_dir": "/path/to/project" },
  "session_id": "abc123",
  "context_window": {
    "context_window_size": 200000,
    "current_usage": {
      "input_tokens": 5000,
      "cache_creation_input_tokens": 2000,
      "cache_read_input_tokens": 30000
    },
    "total_input_tokens": 500000,
    "total_output_tokens": 150000
  },
  "cost": {
    "total_cost_usd": 2.50,
    "total_duration_ms": 3600000,
    "total_lines_added": 500,
    "total_lines_removed": 100
  }
}
```

### Session Tracking

The script caches the initial cache size at session start (`~/.claude/statusline-cache/`). This lets it show:
- **Cached base** — tokens that were already cached when you started
- **Session growth** — new cache created during your session
- **New tokens** — tokens added in the current turn

Cache files are automatically cleaned up after 7 days.

## Troubleshooting

### Statusline not showing

1. Check `jq` is installed: `which jq`
2. Verify the script is executable: `chmod +x ~/.claude/statusline.sh`
3. Test manually: `echo '{"model":{"display_name":"Test"}}' | ~/.claude/statusline.sh`

### Colors look wrong

Your terminal needs 256-color support. Most modern terminals support this, but you may need to set `TERM=xterm-256color`.

### MCP count not showing

The script looks for `.mcp.json` in your workspace directory. If you're using global MCP servers only, the count won't appear.

## License

MIT
