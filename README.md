# MacOSSpecs

A tiny native macOS menu bar app that shows live CPU / Memory / GPU / Temperature metrics at a glance, so you can spot the source of lag, throttling, or a runaway process without opening Activity Monitor.

> **This project was written end-to-end by Claude AI (Anthropic, Claude Opus 4.6).**
> Every line of Swift, every shell script, the CI workflow, and this README were generated through a conversation with Claude. No code was hand-authored.

## Install (one line)

```bash
curl -fsSL https://raw.githubusercontent.com/AzySir/macos-specs/main/scripts/install.sh | bash
```

That's it. The installer:

1. Shallow-clones the repo into a temp dir under `/tmp`.
2. Builds from source with `swiftc` (Xcode Command Line Tools required).
3. Drops `MacOSSpecs.app` into `/Applications`.
4. Strips the Gatekeeper quarantine attribute (ad-hoc signed).
5. Installs a CLI launcher at `/usr/local/bin/macos-specs` so you can run `macos-specs` from any terminal.
6. Enables launch-at-login on first run.
7. Removes the temp clone — nothing stays behind.

Re-run the same command to upgrade.

### Prerequisites

- macOS 13 or later
- Xcode Command Line Tools: `xcode-select --install` (one-time, ~1 GB)

## What you see

**Menu bar**, always visible — a coloured dot for each metric followed by its value:

```
● CPU 12%   ● RAM 17.9G   ● GPU 34%   ● 52°C
```

**Popover**, click the bar item — big coloured donut ring per metric, a live sparkline, the raw value, expand CPU or Memory to see the top 5 processes consuming that resource, and a dedicated temperature row.

## Features

- **Four live metrics** — CPU %, memory used / total + pressure, GPU %, CPU temperature (°C).
- **Per-metric colours** — pick your own for CPU, Memory, GPU, and each thermal-severity level.
- **Sparkline history** — last 60 samples per metric drawn inline under each row.
- **Click-to-expand processes** — click the CPU row to see the top 5 CPU hogs, click Memory to see the top 5 RAM hogs.
- **Settings panel** — refresh interval, severity thresholds, colour customisation, menu-bar toggles, and launch-at-login.
- **Launch at login** — one click in settings registers the app via `SMAppService`.
- **Borderless popover** — custom `NSPanel` anchored directly under the status item; no system arrow or gap.
- **Zero runtime dependencies** — pure AppKit + SwiftUI + Combine + IOKit. No third-party Swift packages.

## Metrics & how they're sourced

| Metric | Source |
| --- | --- |
| CPU % | `host_statistics(HOST_CPU_LOAD_INFO)` |
| Memory used / total / pressure | `host_statistics64(HOST_VM_INFO64)` + `sysctl hw.memsize` |
| GPU % | `IOAccelerator` → `PerformanceStatistics["Device Utilization %"]` |
| CPU temperature | `IOHIDEventSystemClient` (private API, works on Apple Silicon) |
| Thermal state | `ProcessInfo.thermalState` |
| Top processes | `/bin/ps -A -o pid=,pcpu=,rss=,comm=` |
| Fan RPM | SMC (stub — Intel only; Apple Silicon TBD) |

## Launch at login

Enabled automatically on first launch (i.e. the first time the install script runs it). If you don't want it, open the popover → gear icon → toggle **Launch at login** off. Your choice is remembered — the auto-enable only fires once, on the very first run. The app uses `SMAppService.mainApp.register()` under the hood, so macOS manages it in *System Settings → General → Login Items* like any other well-behaved menu bar app.

## Build from source (manual)

If you'd rather do it by hand:

```bash
git clone https://github.com/AzySir/macos-specs.git /tmp/macos-specs
cd /tmp/macos-specs
./scripts/install.sh          # build + install + cleanup
# -- or just build without installing: --
./scripts/build-app.sh && open build/MacOSSpecs.app
```

`install.sh` is idempotent — running it from a local checkout builds in place and skips the clone/cleanup step.

## Uninstall

```bash
pkill MacOSSpecs
rm -rf /Applications/MacOSSpecs.app
sudo rm -f /usr/local/bin/macos-specs
defaults delete dev.macos-specs 2>/dev/null || true
# login item is removed automatically when the app is deleted
```

## How it was built

Built in one continuous conversation with Claude Opus 4.6 in Claude Code. The conversation included:

- Initial scoping & architecture decisions (menu bar app style, metric APIs, install flow).
- Swift package scaffolding, `Info.plist`, SMC/IOHID bindings, AppKit + SwiftUI interop.
- CI workflow (`.github/workflows/release.yml`) for tagged releases on the `macos-14` runner.
- Many, many iterations of UI polish — donut rings, sparklines, per-metric colouring, spacing, panel vs popover behaviour — based on back-and-forth screenshots.

If you want to fork this and extend it, Claude is a capable pair — hand it this README plus the source tree and ask.

## Security

CI runs [Trivy](https://github.com/aquasecurity/trivy) on every push, every pull request, and on a daily schedule (07:00 UTC). The scan covers:

- **Vulnerabilities** in any dependency that sneaks in.
- **Secrets** accidentally committed (API keys, tokens, private keys).
- **Misconfigurations** in shell scripts, workflows, plists, etc.
- **License** issues.

Findings are published to the repository's **Security → Code scanning alerts** tab, and the PR build fails on `HIGH`/`CRITICAL` severity. See `.github/workflows/security.yml`.

## License

MIT. See `LICENSE` (add your own if publishing).
