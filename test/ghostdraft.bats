# Тесты ghostdraft (pack 1: scaffold — вендоринг + skeleton + dispatcher).
setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../ghostdraft"
}

@test "version prints semver" {
  run bash "$SCRIPT" version
  [ "$status" -eq 0 ]
  [[ "$output" == *"ghostdraft"* ]]
  [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "no args prints usage and exits non-zero" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "help prints usage and exits zero" {
  run bash "$SCRIPT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "unknown command exits non-zero" {
  run bash "$SCRIPT" bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown command"* ]]
}

@test "vendored common is present and provides primitives" {
  run bash -c "source '$SCRIPT' 2>/dev/null; type info >/dev/null && type confirm >/dev/null && type require_macos >/dev/null && echo OK"
  [[ "$output" == *"OK"* ]]
}

@test "sourcing the script does not run the dispatcher" {
  run bash -c "source '$SCRIPT'; echo SOURCED_OK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SOURCED_OK"* ]]
  [[ "$output" != *"Usage:"* ]]
}

@test "vendor --check passes (no drift)" {
  run bash "${BATS_TEST_DIRNAME}/../tools/vendor-common.sh" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"синхронен"* ]] || [[ "$output" == *"sync"* ]]
}

# Фейковый редактор: пишет известный маркер в переданный файл и запоминает путь.
# Через него тестируем жизненный цикл `new` headless (без TTY, без реального RAM-диска).
_fake_editor() {
  local ed="$1"
  cat > "$ed" <<'SH'
#!/usr/bin/env bash
printf 'DRAFT-CONTENT' > "$1"
printf '%s\n' "$1" > "${GD_EDITED_PATH:?}"
stat -f '%Lp' "$1" > "${GD_EDITED_MODE:?}"
SH
  chmod +x "$ed"
}

@test "new opens editor on a draft inside GHOSTDRAFT_DIR" {
  work="$(mktemp -d)"; ed="$work/ed"; _fake_editor "$ed"
  export GD_EDITED_PATH="$work/edited" GD_EDITED_MODE="$work/mode"
  run env GHOSTDRAFT_DIR="$work/draftdir" EDITOR="$ed" bash "$SCRIPT" new
  [ "$status" -eq 0 ]
  edited="$(cat "$work/edited")"
  [[ "$edited" == "$work/draftdir/"* ]]
  rm -rf "$work"
}

@test "new shreds the draft file on exit (nothing left)" {
  work="$(mktemp -d)"; ed="$work/ed"; _fake_editor "$ed"
  export GD_EDITED_PATH="$work/edited" GD_EDITED_MODE="$work/mode"
  run env GHOSTDRAFT_DIR="$work/draftdir" EDITOR="$ed" bash "$SCRIPT" new
  [ "$status" -eq 0 ]
  edited="$(cat "$work/edited")"
  [ ! -e "$edited" ]
  run bash -c "grep -rl 'DRAFT-CONTENT' '$work/draftdir' 2>/dev/null"
  [ -z "$output" ]
  rm -rf "$work"
}

@test "new creates the draft with 600 perms" {
  work="$(mktemp -d)"; ed="$work/ed"; _fake_editor "$ed"
  export GD_EDITED_PATH="$work/edited" GD_EDITED_MODE="$work/mode"
  run env GHOSTDRAFT_DIR="$work/draftdir" EDITOR="$ed" bash "$SCRIPT" new
  [ "$status" -eq 0 ]
  [ "$(cat "$work/mode")" = "600" ]
  rm -rf "$work"
}

@test "new cleans vim swap/undo and nano backup of the draft" {
  work="$(mktemp -d)"; dir="$work/draftdir"
  # редактор создаёт побочные editor-следы рядом с черновиком
  cat > "$work/ed" <<'SH'
#!/usr/bin/env bash
printf 'DRAFT-CONTENT' > "$1"
d="$(dirname "$1")"; b="$(basename "$1")"
printf 'swap' > "$d/.$b.swp"
printf 'undo' > "$d/.$b.un~"
printf 'backup' > "$d/$b~"
printf '%s\n' "$1" > "${GD_EDITED_PATH:?}"
stat -f '%Lp' "$1" > "${GD_EDITED_MODE:?}"
SH
  chmod +x "$work/ed"
  export GD_EDITED_PATH="$work/edited" GD_EDITED_MODE="$work/mode"
  run env GHOSTDRAFT_DIR="$dir" EDITOR="$work/ed" bash "$SCRIPT" new
  [ "$status" -eq 0 ]
  run bash -c "ls -A '$dir' 2>/dev/null"
  [ -z "$output" ]
  rm -rf "$work"
}

# Регрессия: _pick_draft_dir несёт ram-dev третьим полем через stdout (не через
# глобал в $(...)). Раньше RAM-диск утекал без detach из-за subshell. Контракт:
# вывод = "<dir>\t<kind>\t<ram_dev>" (ram_dev пуст для override/vault).
@test "_pick_draft_dir emits the ram-dev field (no-subshell-leak contract)" {
  work="$(mktemp -d)"
  out="$(source "$SCRIPT"; GHOSTDRAFT_DIR="$work" _pick_draft_dir)"
  fields="$(awk -F'\t' '{print NF}' <<<"$out")"
  [ "$fields" -eq 3 ]
  [[ "$out" == "$work"$'\t'override$'\t'* ]]
  rm -rf "$work"
}

@test "new --clipboard copies the draft to the clipboard after confirm" {
  work="$(mktemp -d)"; bin="$work/bin"; mkdir -p "$bin"
  printf '#!/usr/bin/env bash\ncat >> "$CLIP_LOG"\n' > "$bin/pbcopy"
  printf '#!/usr/bin/env bash\ncat "$CLIP_STATE" 2>/dev/null || true\n' > "$bin/pbpaste"
  chmod +x "$bin/pbcopy" "$bin/pbpaste"
  ed="$work/ed"; _fake_editor "$ed"
  export GD_EDITED_PATH="$work/edited" GD_EDITED_MODE="$work/mode"
  export CLIP_LOG="$work/clip.log" CLIP_STATE="$work/clip.state"; : > "$CLIP_LOG"
  # CLIP_SECS=1: авто-очистка лишь дописывает пустоту в append-log — assertion ниже
  # (grep DRAFT-CONTENT) race-safe; держим коротко, чтобы не плодить фоновые sleep.
  run env PATH="$bin:$PATH" GHOSTDRAFT_DIR="$work/d" GHOSTDRAFT_CLIP_SECS=1 \
    ST_ASSUME_YES=1 EDITOR="$ed" bash "$SCRIPT" new --clipboard
  [ "$status" -eq 0 ]
  grep -q 'DRAFT-CONTENT' "$CLIP_LOG"
  rm -rf "$work"
}

@test "new --clipboard does NOT copy when confirm is declined" {
  work="$(mktemp -d)"; bin="$work/bin"; mkdir -p "$bin"
  printf '#!/usr/bin/env bash\ncat >> "$CLIP_LOG"\n' > "$bin/pbcopy"
  printf '#!/usr/bin/env bash\ntrue\n' > "$bin/pbpaste"
  chmod +x "$bin/pbcopy" "$bin/pbpaste"
  ed="$work/ed"; _fake_editor "$ed"
  export GD_EDITED_PATH="$work/edited" GD_EDITED_MODE="$work/mode"
  export CLIP_LOG="$work/clip.log"; : > "$CLIP_LOG"
  run env PATH="$bin:$PATH" GHOSTDRAFT_DIR="$work/d" EDITOR="$ed" \
    bash "$SCRIPT" new --clipboard <<< "no"
  [ "$status" -eq 0 ]
  run grep -q 'DRAFT-CONTENT' "$CLIP_LOG"
  [ "$status" -ne 0 ]
  rm -rf "$work"
}

@test "_clip_clear_if_match clears only when clipboard still holds our content" {
  work="$(mktemp -d)"; bin="$work/bin"; mkdir -p "$bin"
  printf '#!/usr/bin/env bash\ncat > "$CLIP_STATE"\n' > "$bin/pbcopy"
  printf '#!/usr/bin/env bash\ncat "$CLIP_STATE" 2>/dev/null || true\n' > "$bin/pbpaste"
  chmod +x "$bin/pbcopy" "$bin/pbpaste"
  export CLIP_STATE="$work/state"
  printf 'OUR-SECRET' > "$CLIP_STATE"
  PATH="$bin:$PATH" bash -c "source '$SCRIPT'; _clip_clear_if_match 'OUR-SECRET'"
  [ -z "$(cat "$CLIP_STATE")" ]
  printf 'USER-LATER-COPY' > "$CLIP_STATE"
  PATH="$bin:$PATH" bash -c "source '$SCRIPT'; _clip_clear_if_match 'OUR-SECRET'"
  [ "$(cat "$CLIP_STATE")" = "USER-LATER-COPY" ]
  rm -rf "$work"
}

@test "new refuses honestly when no safe location is available" {
  work="$(mktemp -d)"
  run env -u GHOSTDRAFT_DIR ST_VAULT_VOLUME="$work/nonexistent" \
    GHOSTDRAFT_DISABLE_RAM=1 EDITOR=true bash "$SCRIPT" new
  [ "$status" -eq 3 ]
  rm -rf "$work"
}

@test "pipe echoes stdin to stdout" {
  run bash -c "printf 'secret-seed-123' | bash '$SCRIPT' pipe"
  [ "$status" -eq 0 ]
  [[ "$output" == *"secret-seed-123"* ]]
}

@test "pipe preserves multi-line input" {
  run bash -c "printf 'line1\nline2\nline3' | bash '$SCRIPT' pipe"
  [ "$status" -eq 0 ]
  [[ "$output" == *"line1"* ]]
  [[ "$output" == *"line2"* ]]
  [[ "$output" == *"line3"* ]]
}

@test "pipe handles empty stdin (status 0, no crash)" {
  run bash -c "printf '' | bash '$SCRIPT' pipe"
  [ "$status" -eq 0 ]
}

@test "pipe writes nothing to disk" {
  work="$(mktemp -d)"
  before="$(find "$work" -type f | wc -l)"
  ( cd "$work" && printf 'top-secret' | bash "$SCRIPT" pipe >/dev/null )
  after="$(find "$work" -type f | wc -l)"
  [ "$before" -eq "$after" ]
  # содержимое не утекло во временные файлы рабочей папки
  run bash -c "grep -rl 'top-secret' '$work' 2>/dev/null"
  [ -z "$output" ]
  rm -rf "$work"
}

@test "vendor --check detects drift in the vendored block" {
  work="$(mktemp -d)"; mkdir -p "$work/tools"
  cp "${BATS_TEST_DIRNAME}/../ghostdraft" "$work/ghostdraft"
  cp "${BATS_TEST_DIRNAME}/../tools/vendor-common.sh" "$work/tools/"
  sed 's/_ST_COMMON_LOADED=1/_ST_COMMON_LOADED=999/' "$work/ghostdraft" > "$work/ghostdraft.mut"
  mv "$work/ghostdraft.mut" "$work/ghostdraft"
  run bash "$work/tools/vendor-common.sh" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"ДРЕЙФ"* ]] || [[ "$output" == *"drift"* ]]
  rm -rf "$work"
}
