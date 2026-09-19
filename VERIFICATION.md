# Verification

This record covers the Codex-based v1.0.0 MVP in release preparation. It distinguishes automated coverage from manual checks; it does not certify a published release or every supported macOS configuration.

## Recorded results

Latest recorded checks: **2026-09-18**. Compilation/testing used Swift 6.4 and Apple Command Line Tools; live integration was checked with Codex CLI 0.153.4. The deployment target is macOS 14+, not a claim that every OS/toolchain combination has been tested.

| Check | Result |
| --- | --- |
| Clean release build and ad-hoc signature validation | Passed |
| `make help`, default help, `make app run` | Passed |
| `make verify`: syntax, build, default tests, signature | Passed |
| Live-enabled suite | All 26 tests across four suites passed |
| Real arithmetic request | `144` |
| Real Python request | `[x**2 for x in range(1, 11)]` (whitespace-normalized comparison) |
| Native desktop smoke harness with real Codex | Passed |
| Cleanup refusal for symlinked build locations | Passed |
| Publication-candidate source/image review | No recognizable credentials or personal paths detected |

The live suite and native smoke results are from implementation verification; documentation-only changes do not imply a new live run. The default suite has 26 declared tests and intentionally skips the live-provider test. Two CLT linker warnings about nonexistent toolchain search directories remain; builds and tests succeed. Full Xcode builds and a cross-version macOS matrix remain unverified.

## Reproduce the checks

From the project directory:

```sh
make clean
make verify
```

Make is optional: `bash scripts/verify.sh` runs the same checks. `bash scripts/test.sh` supplies Swift Testing framework/plugin paths when required by a CLT installation. Do not run independent clean/build commands concurrently.

Default tests need no Codex credentials or network access. Desktop tests require a logged-in graphical session and use private pasteboards and isolated preferences; they do not read the user's clipboard.

To deliberately send the two fixed acceptance requests to an installed, authenticated Codex CLI:

```sh
GLINT_LIVE_TESTS=1 make test
```

Do not run live credentials against untrusted test code.

## Hosted CI

The [CI workflow](.github/workflows/ci.yml) is prepared for pushes to `main` and pull requests targeting `main`. **Remote execution: NOT RUN / PENDING** until publication. Local verification does not establish a hosted-runner pass.

The job uses `macos-15` and selects its preinstalled Xcode 16.4 through `DEVELOPER_DIR`. The [runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-arm64-Readme.md) documents that installation. This constrains the toolchain without downloading one or embedding development-machine paths. Review the selection when runner images retire toolchains; a missing installation should fail visibly.

After checkout, CI prints only OS version, architecture, Xcode/Swift versions, and SDK version. `make verify` performs script/project syntax checks, the release build, the default tests, and ad-hoc signature verification in one pass. The existing test script retains dynamic CLT compatibility handling for local development; CI uses full Xcode. There is no dependency on a downloaded Apple Intelligence model or installed Codex CLI.

`GLINT_LIVE_TESTS=0` and `GLINT_SMOKE_LIVE=0` explicitly prohibit the existing opt-in live checks. The workflow uses only the official checkout action, disables checkout credential persistence, grants only `contents: read`, sets a 20-minute job limit, and cancels superseded runs. It has no secret references, uploads, signing credentials, release actions, or privileged pull-request trigger. Default desktop tests remain enabled; their graphical-session assumptions and full-Xcode compilation still require validation on the actual runner.

Phase 5 local validation (2026-09-18): clean release build, standalone default suite, and `make verify` passed. Both test runs declared 26 tests across four suites: 25 executed successfully and the live-provider test was intentionally skipped. YAML parsing, workflow trigger/permission/live-test contracts, embedded shell syntax, referenced files, relative documentation links, and the badge target passed local checks. The 53-file publication candidate scan found no recognizable credentials or personal paths; generated artifacts remain excluded. `actionlint` was not installed, so this is not an actionlint or hosted-runner result. No live AI request was made in this phase.

## Automated coverage

- Final-message JSONL extraction, completed-turn validation, malformed/failed/incomplete output rejection, and formatting preservation.
- Literal stdin transport, simultaneous stdout/stderr draining, process exit status, bounded output, timeout, and cancellation.
- Descendant-held pipes, early child exit, blocked-input cancellation, and timeout during output draining.
- Environment allowlisting using synthetic secrets, retained auth/network settings, empty default child environments, and discovery without a shell fallback.
- Owner-only request-directory permissions, successful removal, and sanitized cleanup-failure handling.
- Request replacement/cancellation and clipboard ownership; plain-text pasteboard writes; shortcut preference persistence.
- Screen location and the prohibition on documentation snapshots of Settings.

PromptBuilder's instructions are exercised through live provider/coordinator flows; a dedicated PromptBuilder unit test is not yet present. Do not infer model-answer correctness from prompt instructions alone.

## Native desktop smoke harness

The opt-in debug harness dispatches the registered Carbon event and checks native input focus, unchanged frontmost application, a non-key processing pill, answer delivery to a private pasteboard, dismissal, shortcut toggling/conflicts, and Settings rendering.

```sh
bash scripts/build.sh debug
build/Glint.app/Contents/MacOS/Glint --smoke-test
bash scripts/build.sh
```

The default harness uses a deterministic provider. Set `GLINT_SMOKE_LIVE=1` on the harness invocation to use real Codex. It may select another available default chord if the normal app is running, without changing the normal app's preferences. Quit the normal app first when testing preferred-default registration.

Snapshots are off by default. Setting `GLINT_SNAPSHOT_DIR` to an existing ignored build directory exports only the harness's input/success views, never Settings or the desktop. Review image pixels and metadata before moving any image to `docs/images/`. The harness is excluded from release builds.

## Manual acceptance checklist

- In Word/Pages, open Glint with the physical shortcut, ask `What is 12 * 12?`, wait for Copied, and paste `144`.
- In VS Code, ask for Python squares from 1 to 10 and paste the raw expression.
- Confirm Escape, repeated shortcut, click-away dismissal, and processing cancellation return control appropriately.
- Submit a newer request while another is processing; the older answer must not overwrite the clipboard.
- Check multiple monitors, full-screen applications, secure input, alternate keyboard layouts, and another app intercepting the same shortcut.
- Record an unavailable shortcut, restart with a saved shortcut, and test an invalid executable path.
- Exercise full Xcode builds and another Mac; validate Developer ID signing/notarization separately before distributing binaries.

The automated harness does not synthesize the user's global chord or paste into user documents. It is not a substitute for these manual checks.

## Publication and privacy review

Reviewed publication candidates exclude generated bundles, caches, signatures, local settings, and the unsafe Settings preview. Existing branding and the reviewed input/success images are retained; the historical panel-mark difference is captioned. Pattern scans inspect source candidates and generated files separately without printing potential secret values.

No recognizable credentials were detected in the recorded scans. Generated binaries/caches can contain personal filesystem paths and must remain excluded. Scanning cannot prove the absence of every encoded secret, and `make verify` is not a secret scanner.

Glint keeps request content in memory, but the trusted Codex executable can communicate off-device and maintain its own authentication/cache data. Crashes or cleanup failures can leave private working directories; arbitrary descendant processes are not recursively terminated. These are documented boundaries, not offline or isolation guarantees.

See [SECURITY.md](SECURITY.md) for private reporting and [repository preparation](docs/REPOSITORY.md) for release metadata, reporting-channel activation, and badges. Apple Foundation Models, Screen mode, Claude, and provider switching have no implementation or verification coverage yet.
