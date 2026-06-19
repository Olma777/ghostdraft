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

@test "new is deferred (exit 2) — pack 2a/2b boundary" {
  run bash "$SCRIPT" new
  [ "$status" -eq 2 ]
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
