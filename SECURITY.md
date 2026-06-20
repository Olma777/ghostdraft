# Security Policy

ghostdraft is a security tool, so its own correctness matters. Its whole point
is letting you write or view a secret (a seed, password, or key) without leaving
a copy in the usual places — so a bug that quietly leaves the secret behind
defeats the tool. If you find a vulnerability, please report it responsibly.

## Reporting a vulnerability

**Do not open a public issue for an exploitable vulnerability.**

Use GitHub's private vulnerability reporting:

1. Go to the repository's **Security** tab → **Report a vulnerability**
   (<https://github.com/Di-kairos/ghostdraft/security/advisories/new>).
2. Describe the issue, affected versions, and a reproduction if possible.

You'll get a response as soon as reasonably possible. Once a fix is ready, the
advisory is published and you'll be credited unless you prefer to stay anonymous.

## Scope

In scope:

- Anything that causes ghostdraft to **claim a guarantee it does not provide**
  (the project's whole point is honesty about where a secret can end up).
- The draft never reaching a safe location: silently writing the draft to
  on-disk `/tmp` / `$TMPDIR` (APFS) instead of an open vault or RAM disk, or
  proceeding when no safe location exists instead of refusing (exit 3).
- Cleanup failures on exit: the draft not being shredded, or editor residue
  (vim `.swp`/`.swo`/`.swn`/`.un~`, nano `file~`) being left behind next to it.
- The RAM disk not being detached on exit, leaving the draft volume mounted.
- `--clipboard` behaving worse than documented: copying without the explicit
  confirmation, or the auto-clear wiping a *different* clipboard the user set
  after the draft (it must only clear if the clipboard still matches the draft).
- File-permission or path-handling issues (e.g. the draft created without `600`,
  or the shred/clean routines touching files outside the draft).
- Privilege or injection issues in the shell code.

Out of scope:

- **Terminal scrollback, OS swap, and `~/.viminfo`** (registers, last yank,
  search history). These are documented limitations the tool cannot scrub —
  it says so on exit. That's the honest premise, not a bug (see the README
  "Scope & limitations").
- **Fallback overwrite on an SSD is not a guarantee.** When `securetrash shred`
  is unavailable, ghostdraft falls back to overwrite + `rm`, which is best-effort
  on SSD/APFS — exactly the limitation securetrash documents. Real erasure comes
  from RAM-disk detach or closing the encrypted vault (crypto-shred).
- **Using `--clipboard` against the documented warning.** Clipboard managers and
  iCloud Universal Clipboard may keep or sync a copy; this is off by default,
  warned about, and confirmed. Auto-clear cannot undo a copy already taken.
- **On-disk safety of `GHOSTDRAFT_DIR`.** If you point the draft at your own
  path, its on-disk safety is on you — that's the documented contract.

## Supported versions

The latest released version receives security fixes. ghostdraft is pre-1.0;
older tags are not maintained.
