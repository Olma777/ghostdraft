**English** · [Русский](README.ru.md)

# ghostdraft

Ephemeral scratchpad for sensitive text — part of the
[Paranoid Tools](https://github.com/Di-kairos/paranoid-tools) ecosystem.

Write or view a seed phrase, password or key so that once you close it, no copy is
left in the usual places (`~/.*_history`, tmp, recent docs, editor backups/viminfo).

[![CI](https://github.com/Di-kairos/ghostdraft/actions/workflows/ci.yml/badge.svg)](https://github.com/Di-kairos/ghostdraft/actions/workflows/ci.yml)
![License: MIT](https://img.shields.io/badge/license-MIT-green)
![platform](https://img.shields.io/badge/platform-macOS-blue)
![windows](https://img.shields.io/badge/Windows-beta-orange)
![shellcheck](https://img.shields.io/badge/shellcheck-passing-brightgreen)

> **Status: early (v0.1.3).** `pipe` (view without writing to disk) and `new` (a draft
> in an open vault / RAM disk → `$EDITOR` → shred + clean editor traces on exit) are
> ready, including the optional `--clipboard` (dangerous, gated behind confirmation +
> auto-clear).

## Install

Checksum-verified install from the release tag — verify-then-run (don't trust, verify).
Piping a script into a shell means running code you haven't read, so prefer this:

```bash
base=https://github.com/Di-kairos/ghostdraft/releases/latest/download
curl -fsSLO "$base/install.sh"
curl -fsSLO "$base/SHA256SUMS"
shasum -a 256 -c SHA256SUMS --ignore-missing   # verifies install.sh
less install.sh                                  # read it
bash install.sh                                  # pulls ghostdraft + checksum, verifies, installs
```

Quick form (if you already trust the source):

```bash
curl -fsSL https://github.com/Di-kairos/ghostdraft/releases/latest/download/install.sh | bash
```

`install.sh` pulls the binary and `SHA256SUMS` from the immutable release tag and verifies
the hash **before** installing. Environment variables: `GHOSTDRAFT_VERSION` (pin a specific
tag instead of `latest`), `GHOSTDRAFT_DEST` (install path), `GHOSTDRAFT_BASE_URL` (override
the source for forks/tests).

> **Integrity vs authenticity (honest scope).** The checksum proves the binary matches the
> `SHA256SUMS` from the same release — it catches corruption and stops you running code off
> the moving `main` branch. But the checksum and the binary arrive over the same channel: it
> does **not** defend against an attacker who rewrites *both* (the release itself). For
> authenticity you need a signature / Homebrew.

> The current public release is **v0.1.3** (signed, with `install.sh` + `SHA256SUMS`).
> Pin it for reproducibility with `GHOSTDRAFT_VERSION=0.1.3` instead of `latest`.

## Usage

```bash
ghostdraft new             # ephemeral draft in an open vault / RAM disk
ghostdraft new --clipboard # + copy to clipboard, auto-clear after N s (DANGEROUS, see below)
pbpaste | ghostdraft pipe  # view from the clipboard, write NOTHING to disk
ghostdraft version         # show the version (also -v / --version)
ghostdraft --help          # help (also -h)
```

## Architecture

- Single-file Bash, zero dependencies. Native macOS primitives (`hdiutil` for the RAM disk,
  `$EDITOR`/nano). `new` prefers to write **inside an open securetrash vault**.
- The shared core (`lib/common.sh`) is **vendored** inline from securetrash, pinned to a
  git ref; `tools/vendor-common.sh --check` catches drift in CI. See `paranoid-tools/README.md`.

## Where `new` writes the draft (by priority)

1. **`$GHOSTDRAFT_DIR`** — if set and writable (override for your own workflows; on-disk
   security is then your responsibility).
2. **An open securetrash vault** (`/Volumes/SecretVault`, overridable via `$ST_VAULT_VOLUME`)
   — encrypted; closing the vault gives crypto-shred.
3. **A RAM disk** (`hdiutil attach -nomount ram://` + HFS+) — lives in RAM, gone on detach at
   exit; not synced, never lands on the SSD.
4. **None of these available → refuse** (exit 3). It does NOT silently write to `/tmp` on APFS.

## Scope & limitations

Honesty about limits is the ecosystem's whole point — and it's especially easy to slip into
snake oil here, so we do **not** promise "zero traces":

- **macOS has no `/dev/shm`**; `/tmp` and `$TMPDIR` live on APFS (on disk). The only real
  in-memory location is a RAM disk (`hdiutil attach -nomount ram://`), which is what we use.
- **What we clean on exit:** the draft itself (`securetrash shred`, otherwise overwrite + rm),
  vim swap/undo (`.swp`/`.swo`/`.swn`/`.un~`), nano backups (`file~`), and detach of our own
  RAM disk.
- **What we cannot clean** (and say so honestly): terminal scrollback, the OS swap, and
  `~/.viminfo` (registers / last yank / search history). These are out of the tool's reach.
- **`--clipboard` is dangerous for a seed** (clipboard managers + Universal Clipboard sync the
  buffer to iCloud onto other devices) — it is OFF by default, requires confirmation when
  enabled; auto-clear after `${GHOSTDRAFT_CLIP_SECS:-20}`s, but only if the buffer hasn't
  changed, and it does NOT undo a copy already made.
- **Fallback shred on SSD is not a guarantee** (exactly what securetrash warns about); real
  erasure comes from RAM-disk detach or crypto-shred of a closed vault.

## Windows (beta)

A PowerShell port now exists in [`windows/README.md`](windows/README.md). It mirrors the
macOS logic — RAM disk (ImDisk / third-party) with on-disk fallback shred, clipboard
clearing, and cleanup of Notepad/editor backups and jump lists / recent.

> **Beta:** the Windows port is logic-tested (Pester on CI) but not yet validated on real
> Windows hardware. See [`windows/README.md`](windows/README.md).

## License

[MIT](LICENSE). Report security issues via [SECURITY.md](SECURITY.md); contributions via
[CONTRIBUTING.md](CONTRIBUTING.md).
