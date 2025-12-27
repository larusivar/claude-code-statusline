# Claude Code Statusline

A minimal, fast statusline for [Claude Code](https://github.com/anthropics/claude-code).

```
Claude Sonnet 4 | ███▓▓░░░░░░░░│ 31% +1.5k -287 [2h|↓1.2m↑0.3m|$4]
                  ↑↑↑ ↑↑ ↑
                  │││ ││ └── Light cyan: this turn's tokens
                  │││ └──── Medium teal: cache growth during session
                  └──────── Dark teal: baseline at session start
```

## Features

- **Model name** — current model in teal
- **Context usage bar** — three-segment visualization:
  - **Dark teal:** cached tokens at session start
  - **Medium teal:** cache growth during session
  - **Light cyan:** tokens added this turn
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
| Bar: baseline | 30 | Dark teal |
| Bar: growth | 73 | Medium teal |
| Bar: new | 116 | Light cyan |
| Bar separator | 167 | Red |
| Lines added | 33 | Blue |
| Lines removed | 208 | Orange |
| Session stats | 102, 179 | Gray, gold |

See [256 colors cheat sheet](https://www.ditig.com/256-colors-cheat-sheet) for options.

## How It Works

Claude Code passes JSON to the statusline script via stdin. The script uses a single `jq` call to extract all values, then pure bash to render the output.

### Architecture

- **Single jq subprocess** — all JSON parsing in one call using `@sh` for safe variable extraction
- **Lightweight session tracking** — stores baseline in `/tmp/`, single file read per render
- **~110 lines** — minimal, readable code
- **Auto-cleanup** — `/tmp/` files expire on reboot, 1-in-20 chance of pruning old files

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

## Limitations

- Requires `jq` (not bundled)
- Session tracking only works when Claude Code provides `session_id` in the JSON
- Colors require 256-color terminal support
- Session ID cached in `/tmp/`, lost on reboot (bar resets to single-segment)

## Troubleshooting

### Statusline not showing

1. Check `jq` is installed: `which jq`
2. Verify the script is executable: `chmod +x ~/.claude/statusline.sh`
3. Test manually: `echo '{"model":{"display_name":"Test"}}' | ~/.claude/statusline.sh`

### Colors look wrong

Your terminal needs 256-color support. Most modern terminals support this, but you may need to set `TERM=xterm-256color`.

## Changelog

### v2.1.1

- Fixed: cost validation (could show "null" for malformed input)
- Fixed: session ID handling (truncate to 64 chars, allow dashes)
- Improved: inlined number formatting (avoids subshells)
- Added: Limitations section in README

### v2.1.0

- Restored multi-segment context bar (baseline/growth/new)
- Lightweight session tracking via `/tmp/`

### v2.0.0

- Removed session tracking and MCP counting for simplicity
- Single jq call architecture
- ~70 lines

### v1.1.0

- Fixed MCP counting logic
- Fixed edge cases (empty values, float costs)
- Added robustness checks

## License

MIT
