# Repository metadata and release preparation

Target: [xmarano/Glint](https://github.com/xmarano/Glint).

These are proposed GitHub settings, not a claim that remote settings have been applied.

## Current description — v1.0.0

> Native macOS menu bar AI assistant with a global shortcut, Codex CLI, and concise answers copied to your clipboard.

Current topics:

```text
macos swift swiftui ai-assistant productivity menu-bar-app codex clipboard
```

Do not add Apple Foundation Models, Apple Intelligence, local-AI, or offline-AI topics to advertise roadmap work. No tool-calling topic: the current provider deliberately disables tools.

## Future description — only after the corresponding v1.1.0 features ship

> Native, local-first AI assistant for macOS, powered by Apple Foundation Models, with optional external providers and a clipboard-first workflow.

Retain applicable current topics and add these only after implementing and verifying the capabilities:

```text
apple-foundation-models apple-intelligence on-device-ai local-ai
```

Consider `screen-capture` after explicit Screen mode ships and `claude-code` after that provider ships. Defer `offline-ai` until network-disconnected operation has actually been verified. Native framework/image support and OS requirements must be validated before these descriptions become current.

## Badges

README currently uses three local static SVG badges: macOS 14+, Swift 6, and MIT. They do not depend on an external badge service, remote release, or workflow.

- CI badge: targets `xmarano/Glint/actions/workflows/ci.yml` on `main`. The workflow exists locally; its remote status endpoint cannot be validated before publication. Hosted execution is pending, not a reported pass.
- Release badge: add only after the first tag/release is published. Do not display an unreleased version as a published download.

## Before v1.0.0 publication

- Verify the repository destination and intended public files; keep generated artifacts excluded.
- Enable and verify GitHub private vulnerability reporting. `SECURITY.md` includes a safe fallback if it is unavailable.
- App version metadata is synchronized to `1.0.0` in `Resources/Info.plist` and the About panel in `Sources/App/GlintApp.swift`. Verify the rebuilt bundle matches before tagging.
- Complete release verification, then date the changelog entry when a release actually exists.
- Reviewed README captures contain an earlier input-panel mark. Keep that caption, or replace them only with newly reviewed authentic captures; never use the excluded Settings image.

No license decision remains pending: the project uses MIT, Copyright (c) 2026 xmarano. Preparing these files does not initialize Git, apply remote settings, execute remote CI, publish artifacts, or create a release.
