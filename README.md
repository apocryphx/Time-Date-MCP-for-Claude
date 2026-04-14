# Time & Date MCP Server

A native macOS MCP server that gives Claude the current date, time, and timezone. Built in Objective-C with zero dependencies — a single compiled binary that communicates over stdio.

## Why

Claude doesn't always know what time it is. This MCP server fixes that by exposing a `get_current_datetime` tool that returns the local date, time, timezone, and day of week from the user's Mac.

## Install

### Option 1: Download the .mcpb bundle

1. Download `ESTimeDateMCP.mcpb` from [Releases](https://github.com/apocryphx/Time-Date-MCP-for-Claude/releases)
2. Open Claude Desktop settings
3. Drag the `.mcpb` file onto "Drag .MCPB or .DXT files here to install"

### Option 2: Build from source

Requires Xcode.

```bash
git clone https://github.com/apocryphx/Time-Date-MCP-for-Claude.git
cd Time-Date-MCP-for-Claude
xcodebuild -scheme ESTimeDateMCP -configuration Release build
```

The build automatically packages `ESTimeDateMCP.mcpb` in the project root via a custom build phase.

To install manually without the `.mcpb`, add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "datetime": {
      "command": "/path/to/ESTimeDateMCP"
    }
  }
}
```

## Tool

### `get_current_datetime`

Returns the current date and time from the local machine. No arguments.

**Example response:**

```json
{
  "iso8601": "2026-04-13T16:00:49-07:00",
  "date": "2026-04-13",
  "time": "16:00:49",
  "day_of_week": "Monday",
  "timezone": "America/Los_Angeles",
  "timezone_abbreviation": "PDT",
  "utc_offset": "-07:00",
  "utc_offset_seconds": -25200,
  "unix_timestamp": 1776121249
}
```

## How It Works

The server is a standalone Objective-C command-line tool that implements the [Model Context Protocol](https://modelcontextprotocol.io) over stdio (JSON-RPC 2.0). Claude Desktop launches it as a subprocess, sends requests on stdin, and reads responses from stdout.

No HTTP server, no Node.js, no Python — just a ~74KB native binary.

## Project Structure

```
ESTimeDateMCP/
├── ESTimeDateMCP/
│   ├── main.m                    # MCP server implementation
│   ├── Info.plist                # Bundle metadata
│   └── ESTimeDateMCP.entitlements
├── ESTimeDateMCP.xcodeproj/      # Xcode project
├── bundle/
│   ├── manifest.json             # MCPB manifest (v0.3)
│   ├── icon.png                  # Extension icon
│   └── server/                   # Binary copied here by build phase
└── ESTimeDateMCP.mcpb            # Packaged bundle (built automatically)
```

## Requirements

- macOS (Apple Silicon or Intel)
- Xcode (to build from source)
- Claude Desktop (to use the extension)

## Privacy Policy

This extension collects no data. It reads your Mac's system clock and returns the result to Claude over a local pipe. No network requests, no analytics, no data leaves your machine. For complete privacy information, see our [privacy policy](https://github.com/apocryphx/Time-Date-MCP-for-Claude/blob/main/PRIVACY.md).

### Data Collection
- No personal information is collected or stored
- No network requests are made — fully offline
- No data is shared with third parties
- No data is retained between calls

## License

MIT
