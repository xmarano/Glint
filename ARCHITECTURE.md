# Architecture

This document describes the Codex-based v1.0.0 MVP in release preparation. Glint is a macOS accessory application with an AppKit lifecycle and SwiftUI content. Everything visible runs on the main actor. The provider and process runner do not depend on UI types. Codex is the only implemented provider; Apple Foundation Models, Screen mode, Claude, multimodal requests, and provider switching remain planned work.

```text
AppDelegate / menu bar
  ├─ SettingsManager             preferences only (UserDefaults)
  ├─ ShortcutManager             Carbon hotkey, conflict checks, atomic replacement
  └─ AssistantModel              request generation, cancellation, UI state
       ├─ FloatingPanelController → PromptInputView / StatusPill
       ├─ PromptBuilder → AIProvider → CodexCLIProvider → ProcessRunner
       └─ ClipboardManager       NSPasteboard plain-text write
```

## Focus and screen placement

A borderless, nonactivating NSPanel can become key only in input state and can never become the main window. It floats across Spaces, including as a full-screen auxiliary panel. Submission orders it out before replacing the content with a smaller, non-key status pill. The working application normally remains active throughout. If Glint itself acquired activation, it restores the captured app only when Glint is still frontmost; completion never activates a previous app after the user has switched elsewhere.

The active app's window bounds select the screen with the greatest intersection. Window titles and pixels are not used. With unavailable metadata, the pointer screen provides a practical fallback without Accessibility or Screen Recording permission. Placement uses `visibleFrame` so the Dock and menu bar are respected.

## Keyboard handling

Carbon `RegisterEventHotKey` delivers the registered chord without a global keyboard monitor. Enabled system symbolic shortcuts are rejected before registration. Exclusive registration reports collisions where supported. New registration happens before old registration is released, so a failed settings change preserves a working shortcut. macOS cannot expose every application's event taps or local commands; no perfect conflict guarantee is made. Defaults are tried only on first configuration; an unavailable saved shortcut is surfaced for user correction.

The local shortcut recorder operates only while explicitly recording in Settings. The prompt uses a native NSTextField and its field editor for keyboard focus, input methods, editing, Enter and Escape. A second global press toggles input closed.

## Request ownership

`AssistantModel` owns a UUID generation and a Task. Opening a new request cancels the previous task and invalidates its generation. Every completion checks both cancellation and generation before changing state or clipboard. Dismissal timers are also generation-checked. Clipboard writes are synchronous main-actor operations with no suspension between the final validity check and the write. Testing Codex uses the same provider but preserves the clipboard.

States: hidden → input → processing → success/error → hidden. Manual-copy preference adds a transient ready state with one answer retained in memory. Cancelling clears the query and pending answer. Success lasts 1.3 seconds; errors last three seconds.

## Process and privacy boundaries

`AIProvider.ask` is the extension point for future providers. `CodexCLIProvider` is a value type using one ProcessRunner per invocation. Prompts use stdin, results use JSONL stdout, and diagnostics use bounded stderr. No shell interpolation, temporary prompt files, or last-message files are needed. Independent pipe readers avoid subprocess deadlocks. Process launch, IO and exit waiting occur on worker queues; async/await exposes them to the coordinator. A lock protects cancellation before/during launch, including a bounded termination fallback.

Codex runs with existing authentication but ignores user configuration, project instructions and rules, disables major tools/integrations, and uses an empty temporary working directory. This intentionally prioritizes text-only inline answers over normal coding-agent behavior. It is not a new security sandbox for the CLI binary itself. The process must exit successfully with a complete turn before any answer is usable.

Only technical metadata is logged. Raw CLI errors are classified into fixed user-facing diagnostics to prevent accidentally persisting an echoed prompt. The production workflow includes no query history, screenshots, clipboard reads, auto-paste, or analytics. Codex may send requests off-device, and its authentication/cache data and provider policies remain outside Glint's control.

Queries are limited to 32 KB, stdout to 2 MB, and stderr to 64 KB. A request has a 90-second timeout. The final completed agent message is accepted only with a completed turn and zero process exit; incomplete, failed, empty, or oversized output is rejected. Formatting is preserved rather than heuristically deleting prose or Markdown.

### Security hardening

- `ExecutableDiscovery` checks paths without invoking a login shell. A custom installation requiring shell initialization must instead be selected explicitly in Settings. This prevents discovery from running arbitrary startup hooks.
- `ProcessRunner` defaults to an empty environment. The Codex provider supplies the explicit allowlist below, not the app's complete environment. Required login storage and deliberately supplied Codex/OpenAI keys remain available; unrelated credentials, SSH-agent sockets, and loader/shell injection settings do not. Absolute PATH entries support Node-based installations; relative entries are discarded. This is data minimization, not a sandbox around the user-selected executable.
- `ProcessPipe` uses nonblocking parent pipe ends and 20 ms polling so neither a blocked stdin writer nor inherited descendant output pipes can strand worker queues. The overall timeout stays armed through output draining. After the direct child exits, a 500 ms drain grace is allowed, then remaining IO stops and incomplete output is rejected. Cancellation terminates the direct child, with SIGKILL after one second if needed. Arbitrary descendants are not recursively killed; the CLI must still be trusted.
- `TemporaryWorkspace` creates a random mode-0700 directory and attempts removal on every provider exit path. Cleanup failures log a fixed message without paths or raw errors. It deliberately does not sweep unrelated directories; crash recovery is not guaranteed.
- The opt-in debug snapshot harness exports only input/success views. Settings rendering remains covered, but exporting a Settings image is prohibited to avoid leaking local paths. Existing reviewed documentation images are kept separately from ignored build products.

### Subprocess environment

`ExecutableDiscovery.processEnvironment` retains only:

| Purpose | Variables |
| --- | --- |
| Home, temporary location, locale | `HOME`, `TMPDIR`, `LANG`, `LC_ALL`, `LC_CTYPE`, `TZ` |
| Existing Codex authentication | `CODEX_HOME`, `CODEX_API_KEY`, `OPENAI_API_KEY` |
| Deliberately configured network routing | `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NO_PROXY`, and their lowercase forms |
| Configured trust roots | `CODEX_CA_CERTIFICATE`, `SSL_CERT_FILE`, `SSL_CERT_DIR`, `NODE_EXTRA_CA_CERTS` |

Missing home/temporary locations use system defaults. PATH is rebuilt with the executable directory, standard runtime locations, and deduplicated absolute inherited entries. `TERM=dumb`, `NO_COLOR=1`, and `RUST_LOG=off` are enforced. Arbitrary endpoint overrides and other variables are not passed through. Proxy and CA configuration intentionally affect network routing and trust; the allowlist is not a claim that the CLI cannot access the user's files.

Settings persist only shortcut, executable selection, copy preference, and onboarding state. Requests are memory-only within Glint. A successful copy replaces the system pasteboard; other applications and clipboard managers remain able to access or retain that output.

## Build boundary

The Xcode app target and Swift package compile the same Sources directory. The package enables builds with Command Line Tools and tests without requiring full Xcode. The app bundle is assembled by `scripts/build.sh`, with LSUIElement and local ad-hoc signing. Distribution signing, notarization, and App Store sandboxing are separate release work.

The optional Makefile delegates to scripts. Default tests use mocks and synthetic data; live Codex tests require an explicit environment switch. See [VERIFICATION.md](VERIFICATION.md) for measured coverage and manual gaps, and [repository preparation](docs/REPOSITORY.md) for version metadata and publication checks. Future provider/image capabilities must be verified before changing the current text-only `AIProvider` contract or privacy boundary.
