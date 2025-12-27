# Claude Code Statusline

A minimal, fast statusline for [Claude Code](https://github.com/anthropics/claude-code).

```
Claude Sonnet 4 | ████░░░░░░░░░░│ 31% +1.5k -287 [2h|↓1.2m↑0.3m|$4]
```

## Features

- **Model name** — current model in teal
- **Context usage bar** — visual percentage of context window used
- **Percentage** — exact context usage
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

Colors are defined inline using 256-color codes. Edit the script to change:

| Element | Color Code | Description |
|---------|------------|-------------|
| Model name | 73 | Teal |
| Bar fill | 30 | Dark teal |
| Bar separator | 167 | Red |
| Lines added | 33 | Blue |
| Lines removed | 208 | Orange |
| Session stats | 102, 179 | Gray, gold |

See [256 colors cheat sheet](https://www.ditig.com/256-colors-cheat-sheet) for options.

## How It Works

Claude Code passes JSON to the statusline script via stdin. The script uses a single `jq` call to extract all values, then pure bash to render the output.

### Architecture (v2.0)

- **Single jq subprocess** — all JSON parsing in one call using `@sh` for safe variable extraction
- **~70 lines** — minimal, readable code
- **No filesystem I/O** — no session cache files
- **No external file reads** — removed MCP counting (was causing multiple jq calls)

### Input JSON Structure

```json
{
  "model": { "display_name": "Claude Sonnet 4" },
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

## Troubleshooting

### Statusline not showing

1. Check `jq` is installed: `which jq`
2. Verify the script is executable: `chmod +x ~/.claude/statusline.sh`
3. Test manually: `echo '{"model":{"display_name":"Test"}}' | ~/.claude/statusline.sh`

### Colors look wrong

Your terminal needs 256-color support. Most modern terminals support this, but you may need to set `TERM=xterm-256color`.

## Changelog

### v2.0.0

- **Breaking:** Removed session cache tracking (multi-segment bar)
- **Breaking:** Removed MCP server counting
- Reduced to single jq call (was 1-4 calls)
- Reduced to ~70 lines (was 190+ lines)
- Faster execution, no filesystem I/O

### v1.1.0

- Fixed MCP counting logic
- Fixed edge cases (empty values, float costs)
- Added robustness checks

## License

MIT
