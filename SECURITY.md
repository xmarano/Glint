# Security policy

## Report privately

Do **not** disclose vulnerabilities, exploit details, tokens, personal data, or sensitive screenshots in public issues, pull requests, discussions, or logs.

Prefer [GitHub private vulnerability reporting for Glint](https://github.com/xmarano/Glint/security/advisories/new) when the repository’s **Report a vulnerability** option is available. This feature must be enabled by a repository administrator; this policy file alone does not enable it, and its availability has not been confirmed as part of release preparation.

If private reporting is unavailable, open an issue containing **only** a request such as “Please enable private vulnerability reporting or provide a private reporting channel.” Do not include the vulnerability, affected component, reproduction details, or attachments. Wait for a private channel before sharing sensitive information. This follows [GitHub’s reporting guidance](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/report-privately).

In the private report, include:

- Affected app/source version and relevant macOS/Codex versions.
- Impact and concise reproduction steps using synthetic data where possible.
- A minimal proof of concept and any suggested mitigation.

Even in private reports, omit real credentials and unrelated personal data. Coordinate disclosure with maintainers while the report is assessed. Response times and fixes are best-effort; there is no guaranteed response SLA or bounty program stated here.

## Scope and version status

The current documented baseline is the Codex-based **v1.0.0 MVP in release preparation**. Report issues against the current source, identifying a revision when available. No v1.0.0 tag or release is established by these documentation files. Apple Foundation Models, Screen mode, Claude, and provider switching are not implemented or covered as existing features.

## Security boundaries

- Glint collects only text deliberately submitted in its own input. Registered hotkeys are not a global keyboard recorder.
- Codex is an external, trusted executable using existing authentication. Requests may leave the machine; v1.0.0 is not an on-device/offline AI product.
- Glint filters the subprocess environment, disables major Codex tools/integrations, and requests ephemeral execution. This is not an OS sandbox around the CLI binary. Applicable provider policies and CLI-owned authentication/cache data still apply.
- Answers replace the system clipboard. Other applications or clipboard managers may access or retain them.
- Request working directories use owner-only permissions and best-effort cleanup. A crash can leave a directory behind. Logs must not include prompts, responses, raw CLI errors, or sensitive paths.

See [ARCHITECTURE.md](ARCHITECTURE.md) for implementation details and [VERIFICATION.md](VERIFICATION.md) for coverage and limitations. Source and image scanning reduce publication risk but cannot prove the absence of every encoded secret.
