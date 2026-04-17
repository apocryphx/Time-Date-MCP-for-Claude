# Building .mcpb Bundles — Reference for Claude Desktop Extensions

## What .mcpb is

ZIP archive containing `manifest.json` + server binary. Claude Desktop installs via drag-drop or double-click. Same format as legacy `.dxt` — use `.mcpb` for new work.

## CLI tool

`npx @anthropic-ai/mcpb` — no install needed. Commands:

- `init` — interactive manifest creation
- `validate <manifest>` — check schema
- `pack <dir> <output>` — create .mcpb
- `unpack <mcpb> [dir]` — extract
- `info <mcpb>` — show metadata
- `sign <mcpb>` — embed signature (broken in v2.1.2, see gotchas)
- `verify <mcpb>` — check signature
- `clean <mcpb>` — minimize bundle size

## Minimal bundle structure

```
bundle/
├── manifest.json
├── icon.png            (must be PNG, not JPEG; 512×512 recommended)
└── server/
    └── <binary>        (or index.js for type=node, etc.)
```

## Manifest v0.3 essentials

```json
{
  "manifest_version": "0.3",
  "name": "machine-name",
  "version": "1.0.0",
  "display_name": "Human Name",
  "description": "...",
  "author": { "name": "..." },
  "icon": "icon.png",
  "server": {
    "type": "binary|node|python",
    "entry_point": "server/mybin",
    "mcp_config": {
      "command": "${__dirname}/server/mybin",
      "args": []
    }
  },
  "tools": [{ "name": "foo", "description": "..." }],
  "tools_generated": true,
  "privacy_policies": ["https://..."],
  "license": "MIT",
  "compatibility": { "platforms": ["darwin", "win32", "linux"] }
}
```

`${__dirname}` resolves to the extension install dir at runtime. Can use absolute paths for companion-to-native-app pattern.

## Build flow

1. Compile binary (Xcode for native macOS)
2. Copy binary into `bundle/server/`
3. **Re-sign the copy** — `cp` loses codesign in some contexts, and unsigned + hardened runtime = silent kill by macOS. Minimum ad-hoc signing:
   ```bash
   codesign --force --sign - -o runtime --entitlements <ents> <binary>
   ```
4. Pack:
   ```bash
   npx @anthropic-ai/mcpb pack bundle/ output.mcpb
   ```

Automate in Xcode as a Run Script build phase. Requires `ENABLE_USER_SCRIPT_SANDBOXING = NO` for `npx` to work.

## Hard-won gotchas

- **Protocol version**: Claude Desktop currently requires `2025-11-25`. Server must include it in supported set or connection fails silently after initialize. Current safe set:
  ```
  ["2024-11-05", "2025-03-26", "2025-06-18", "2025-11-25", "2026-03-26"]
  ```
- **Code signing**: binary inside the packed ZIP must remain signed through pack+extract. Re-sign in bundle dir before packing.
- **Icon format**: PNG only. JPEG rejected at validation.
- **`mcpb sign` bug (v2.1.2)**: sign succeeds but verify reports "not signed" due to `node-forge`'s unimplemented PKCS#7 verify. [PR #195](https://github.com/modelcontextprotocol/mcpb/pull/195) pending. Signing has also been observed to corrupt ZIP structure — don't ship signed bundles until fixed.
- **Annotations location**: `readOnlyHint` / `destructiveHint` / `idempotentHint` / `openWorldHint` go in the server's runtime `tools/list` response, **not** in the manifest's `tools` array (manifest schema rejects them).
- **`tools_generated: true`**: tells Claude Desktop the manifest's `tools` list is representative only; trust the runtime `tools/list`. Essential for apps that reflect tools from the running process.

## Directory submission requirements

Anthropic's directory requires **macOS + Windows** portability. Native macOS-only bundles cannot be listed. GitHub-distributed is fine. Privacy policy required in README and `privacy_policies` array.

## Architecture patterns

1. **Self-contained** — binary inside the .mcpb. Works anywhere. See this repo.
2. **Companion to native app** — manifest's `command` is an absolute path to a binary inside `/Applications/MyApp.app/Contents/Helpers/`. Updates with app. No need for `${__dirname}`.
3. **App-generated configurator** — button in the native app generates a .mcpb on the fly with runtime-discovered paths. Best UX for bundled apps.

## Annotation semantics (runtime `tools/list`)

- `readOnlyHint: true` — tool doesn't modify state
- `destructiveHint: false` — no destructive updates
- `idempotentHint: true` — repeat calls produce same result
- `openWorldHint: false` — no external/network access

Defaults are pessimistic (`destructive: true`, `readOnly: false`, `openWorld: true`) — always set explicitly.

## Reference links

- **Repo**: https://github.com/modelcontextprotocol/mcpb
- **Manifest spec**: https://github.com/modelcontextprotocol/mcpb/blob/main/MANIFEST.md
- **CLI docs**: https://github.com/modelcontextprotocol/mcpb/blob/main/CLI.md
- **Examples**: https://github.com/modelcontextprotocol/mcpb/tree/main/examples
- **Building guide**: https://support.claude.com/en/articles/12922929-building-desktop-extensions-with-mcpb
- **Local submission**: https://support.claude.com/en/articles/12922832-local-mcp-server-submission-guide
- **Directory policy**: https://support.claude.com/en/articles/13145358-anthropic-software-directory-policy
- **Working macOS example**: this repository — Objective-C native binary, ad-hoc signed, Xcode build-phase automation
