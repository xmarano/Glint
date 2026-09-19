# Changelog

Versions follow Semantic Versioning (`v1.0.0`, not `v.1.0.0`). An unreleased entry describes the release being prepared, not an available tag or download.

## v1.0.0 — 2026-09-19

Initial Codex-based macOS MVP. The following capabilities are implemented in the current source:

### Features

- Native Swift/AppKit/SwiftUI menu bar application.
- Configurable global shortcut, native recorder, persistent preferences, and practical conflict handling.
- Floating input with focused typing, compact processing/success/error states, and relevant-display placement.
- Codex CLI provider with executable discovery, stdin requests, final-answer JSONL extraction, and sanitized errors.
- Concise-response prompt builder that preserves requested explanations and formatting.
- Plain-text clipboard output, optional manual copying, cancellation, and newest-request ownership.
- Settings and a Test Codex action that leaves the clipboard unchanged.

### Privacy and reliability

- No global keylogging, application query history, analytics, screen capture, or automatic paste.
- Explicit subprocess environment allowlist and discovery without interactive shell startup.
- Private per-request working directories with path-free cleanup diagnostics.
- Bounded output, request timeout, cancellation, and interruptible pipe handling.

### Development

- Shared Swift package/Xcode source layout, optional Make commands, and build/test/verification scripts.
- Provider, coordinator, desktop, and security regression tests; live acceptance checks remain opt-in.
- MIT license, contributor/security documentation, and reviewed UI previews.
- GitHub-hosted macOS CI with provider-independent tests, read-only permissions, and no live AI requests.

### Distribution

- Source release only; no prebuilt, Developer ID-signed, or notarized application is attached.

Apple Foundation Models, Apple Intelligence integration, Screen mode, Claude, multimodal requests, and provider switching are **not included**. Planned work is described in the [roadmap](README.md#roadmap); it is not a v1.1.0 release entry.
