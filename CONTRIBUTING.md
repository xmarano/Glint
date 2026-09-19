# Contributing to Glint

Glint’s v1.0.0 scope is a native, Codex-powered, clipboard-first macOS assistant. Keep changes small and preserve that working loop. Apple Foundation Models, Screen mode, Claude, multimodal requests, and provider switching are planned work, not current functionality.

## Getting started

Use macOS 14+ and a Swift 6 toolchain. From the project directory:

```sh
make help
make build
make test
make verify
```

Make wraps the scripts in `scripts/`; it is not required. `bash scripts/build.sh debug` builds a debug app. The Xcode project and Swift package share `Sources/`. The test script supplies CLT framework/plugin compatibility paths when necessary. Desktop tests require a logged-in graphical session.

Default tests do not require Codex credentials or network access. `GLINT_LIVE_TESTS=1 make test` explicitly enables two real Codex acceptance requests and requires an installed, authenticated CLI. Never provide live credentials to untrusted contributions or test code. See [VERIFICATION.md](VERIFICATION.md) for the smoke harness and manual checks.

## Proposing a change

For a significant feature or architectural change, discuss its scope before implementation. Bug reports should include the app/source version, macOS/toolchain version, reproduction steps using synthetic content, expected behavior, and actual behavior. Do not attach unredacted logs, screenshots, local paths, or credentials. Security reports belong in the [private reporting process](SECURITY.md), not public issues.

Keep pull requests focused. Explain behavior changes, tests run, known limitations, and any privacy or permission implications. Include regression tests for fixes and update documentation when user-visible behavior changes. Use meaningful commits and review the complete diff, including newly added files, before submitting.

## Engineering boundaries

- Keep the app native Swift/AppKit/SwiftUI; keep provider-specific code out of UI views.
- Preserve global-shortcut focus behavior, cancellation, and newest-request clipboard ownership.
- Do not add global keystroke recording, automatic screen capture, query history, analytics, or automatic paste.
- Keep AI/subprocess work off the main thread. Do not weaken environment filtering or path-free diagnostics.
- Do not add hidden network fallbacks. Future visual context must require explicit capture and deliberate consent before external transmission.
- Use mock providers and synthetic secrets for default tests; do not make them depend on a model, account, or cloud service.

## Files and publication hygiene

Do not commit `.build/`, generated `build/` products, local configuration, credential files, signing material, crash reports, or Xcode user state. Respect `.gitignore`; never force-add artifacts simply to make a build work. Inspect staged diffs and untracked files individually.

Documentation images belong in `docs/images/` only after visual and metadata review. Do not use the excluded Settings screenshot. The debug harness exports only Glint’s input/success views; it does not capture the desktop. Preserve the existing brand assets and record provenance for replacements.

`make clean` removes generated Swift products and the app bundle, not source assets or reviewed images. It refuses symlinked build locations. Avoid concurrent independent clean/build commands.

## License

Glint uses the [MIT License](LICENSE). Submit only contributions you have the right to share under that license, and retain appropriate third-party notices.
