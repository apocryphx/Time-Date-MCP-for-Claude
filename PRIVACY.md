# Privacy Policy

**Time & Date MCP Server (ESTimeDateMCP)**
Last updated: April 13, 2026

## Overview

This extension reads the current date, time, and timezone from your Mac's system clock and provides it to Claude. It does not collect, store, or transmit any personal data.

## Data Collection

This extension collects **no data**. Specifically:

- **No personal information** is collected, stored, or processed
- **No usage analytics** or telemetry are sent anywhere
- **No network requests** are made — the tool operates entirely offline
- **No files** on your system are read, written, or modified
- **No data** is shared with third parties

## How It Works

The extension runs as a local subprocess launched by Claude Desktop. It reads your system clock using macOS APIs (`NSDate`, `NSTimeZone`, `NSCalendar`) and returns the result to Claude over a local stdio pipe. No information leaves your machine beyond the Claude Desktop conversation you are already participating in.

## Data Retention

No data is retained. Each call reads the current time and returns it immediately. Nothing is cached or persisted.

## Third-Party Sharing

No data is shared with any third party. The extension has no network capability.

## Contact

For questions about this privacy policy, open an issue at:
https://github.com/apocryphx/Time-Date-MCP-for-Claude/issues
