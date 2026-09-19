<p align="center">
  <img src="Resources/Brand/Glint-icon.png" alt="Glint app icon" width="128" height="128">
</p>

# Glint

Native AI, a shortcut away.

[![macOS 14+](docs/images/badges/macos.svg)](#requirements)
[![Swift 6](docs/images/badges/swift.svg)](#development)
[![CI](https://github.com/xmarano/Glint/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/xmarano/Glint/actions/workflows/ci.yml)
[![License: MIT](docs/images/badges/license.svg)](LICENSE)

Glint is a lightweight macOS menu bar assistant. Ask from a floating input above your current app, get a concise answer through Codex CLI, and paste it where you need it.

**Shortcut → ask → Enter → copied → ⌘V.** No chat window to manage, no automatic typing into your documents.

This README describes the **v1.0.0 Codex MVP, currently in release preparation**. Apple Foundation Models, on-device generation, Screen mode, Claude, and provider switching are planned—not available in v1.0.0.

## A small interface, out of your way

![Glint floating input with an empty “Ask anything…” field](docs/images/input-preview.png)

![Glint’s compact “Copied” confirmation](docs/images/success-preview.png)

*Reviewed native UI captures. The input capture shows an earlier Glint mark; the current app icon is shown above. These are actual view renderings, not mockups.*

## Why Glint?

Keep working in your editor, browser, or document. Glint handles the request in the background and puts the answer on the clipboard; you decide where to paste it. Built with Swift, AppKit, and SwiftUI—no Electron, web frontend, or bundled third-party packages.

### Features

- Configurable global shortcut with a native recorder and practical conflict checks.
- Compact floating input near the bottom of the relevant display, with focused typing and non-key status feedback.
- Codex CLI requests without opening Terminal; concise-response instructions preserve detail and formatting when requested.
- Plain-text clipboard output, with brief processing, success, and error states.
- Menu bar actions for Ask, Settings, Test Codex, cancellation, and manual copying.
- Settings for the shortcut, Codex executable, and automatic copying.
- Cancellation and newest-request ownership prevent stale answers from overwriting newer results.

## How it works

1. Press the configured shortcut while working in another app.
2. Type a request and press Enter. The input becomes a small processing indicator.
3. When Glint shows **Copied**, press **⌘V** in your app.

For example, `What is 12 * 12?` should produce `144`. A request for Python squares from 1 to 10 should produce `[x**2 for x in range(1, 11)]`, not a tutorial. Output is prompted, not guaranteed; review answers before using them.

Escape closes the input. Pressing the shortcut again while input is open closes it; pressing it during processing cancels that request and opens a new one. If automatic copying is disabled, use **Copy Last Answer** in the menu; that single answer stays in memory until copied, replaced, cancelled, or the app quits.

## Requirements

- macOS 14 or later.
- Swift 6 toolchain through Apple Command Line Tools, or Xcode 16 or later for the Xcode project.
- Installed and authenticated Codex CLI, with network access and an account able to use it. Integration has been verified with CLI **0.153.4**; older versions may lack required options.

Apple Intelligence is **not required** for v1.0.0. Native macOS UI does not mean local AI inference: the Codex provider can send submitted text off-device.

## Build and first run

From a source checkout:

```sh
cd Glint
make build
open build/Glint.app
```

Without Make: `bash scripts/build.sh`. The output is an ad-hoc signed app for local use, not a Developer ID–signed or notarized distribution. Alternatively, open `Glint.xcodeproj` and run the Glint target. See [verification coverage](VERIFICATION.md) for tested and untested build paths.

Authenticate Codex separately with `codex login` if needed. Launch Glint, open **Settings**, and use **Test Codex** to verify the integration. This sends a fixed arithmetic question and leaves your clipboard unchanged. Glint does not open Terminal during normal requests or manage your credentials.

If discovery fails, use **Settings → Choose…** to select the Codex executable. Discovery checks configured and common installation locations without executing shell startup files. Custom Node-based installations also need their runtime on the app’s available PATH; a standalone executable avoids that dependency.

## Global shortcut

The preferred default is **Control–Option–Space**. On first configuration, Glint checks enabled macOS shortcuts and attempts registration; it tries alternative chords if needed. Your saved shortcut is not silently replaced if it later becomes unavailable.

In **Settings → Global shortcut**, click the recorder and press the new chord. Command or Control is required; Escape cancels recording. A rejected change preserves the previous shortcut. macOS cannot reliably detect every shortcut intercepted by another app, so choose a different chord if another tool also reacts. Glint never changes other applications’ settings.

## Provider: Codex CLI

Codex is the **only implemented provider** in v1.0.0. Glint sends the request through stdin and accepts only a completed final answer from JSONL output after a successful process exit. It asks for the *minimum useful answer*, not an arbitrary one-sentence limit.

Requests use an empty private working directory, ephemeral sessions, disabled history, and restricted tool settings. Personal Codex model/provider/MCP/hook configuration is deliberately ignored; existing authentication and applicable managed settings still apply. Only a reviewed environment allowlist reaches the child process. See [architecture and security boundaries](ARCHITECTURE.md#process-and-privacy-boundaries) for details.

## Privacy

- Only deliberately submitted text and Glint’s instructions are supplied as request content. No global keylogging, screenshot capture, selected-text capture, analytics, or conversation history.
- No Accessibility, Input Monitoring, Screen Recording, microphone, or Automation permission is required for the current workflow.
- Queries and responses are handled in memory. Production logs contain technical status and timing, not full prompts, responses, or raw CLI diagnostics.
- Glint writes answers to the system clipboard; it does not read your existing clipboard or simulate paste. Other clipboard managers may retain copied answers.
- Codex authentication, cache/service behavior, and provider data policies remain outside Glint’s control. The CLI is a trusted external executable, not isolated by a new Glint sandbox. A crash or cleanup failure can leave a private temporary working directory.

There is **no offline/on-device inference claim for v1.0.0**. Report vulnerabilities privately using [SECURITY.md](SECURITY.md).

## Development

| Command | Purpose |
| --- | --- |
| `make help` | List commands; also the default `make` action. |
| `make build` / `make app` | Build and ad-hoc sign the release app. |
| `make run` | Build and open Glint; does not restart an existing copy. |
| `make test` | Run tests without live Codex requests by default. |
| `make clean` | Remove Swift build products and the generated app; retain assets/previews. |
| `make verify` | Check syntax, build, run tests, and verify the app signature. |

Make is optional. Direct equivalents are `bash scripts/build.sh`, `bash scripts/test.sh`, `bash scripts/clean.sh`, and `bash scripts/verify.sh`. Use `bash scripts/build.sh debug` for a debug app. `swift build` and the Xcode project compile the same sources. The test script automatically handles supported CLT installations that need Swift Testing framework/plugin lookup adjustments.

Desktop tests need a logged-in graphical session and use private pasteboards. To explicitly send the two fixed acceptance prompts through your authenticated Codex account:

```sh
GLINT_LIVE_TESTS=1 make test
```

For a clean check, run `make clean` then `make verify`; do not run independent build/clean commands concurrently. See [CONTRIBUTING.md](CONTRIBUTING.md) and [VERIFICATION.md](VERIFICATION.md) for test coverage and the native smoke harness.

[CI](.github/workflows/ci.yml) runs `make verify` on macOS for pushes to `main` and pull requests targeting `main`, with live AI tests disabled and no Codex credentials required. The workflow is prepared for publication; hosted execution and its badge remain pending until pushed and run on GitHub. No release badge is shown before a release exists.

## Architecture

Small native components separate shortcut registration, panel presentation, request coordination, prompt construction, subprocess handling, settings, and clipboard writes. The `AIProvider` protocol keeps the UI independent of Codex-specific execution. See [ARCHITECTURE.md](ARCHITECTURE.md).

## Roadmap

**Not part of v1.0.0.** Planned v1.1.0 work: native Apple Foundation Models integration, availability-aware provider selection, explicit Screen mode with image context, and optional Claude Code support. These require implementation and verification; image support and OS requirements must be established before shipping. No silent cloud fallback or unconsented external screenshot upload is planned.

Later possibilities include selected-text context, voice, and optional insertion. None are implemented. The clipboard-first Ask workflow remains the baseline.

## Contributing

Small, focused contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md), review the [changelog](CHANGELOG.md), and use the private reporting process for security issues.

## License

[MIT](LICENSE) · Copyright (c) 2026 xmarano.
