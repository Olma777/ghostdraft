# Changelog

Все заметные изменения ghostdraft. Формат — [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/),
версионирование — [SemVer](https://semver.org/lang/ru/).

## [Unreleased]

## [0.1.3] — 2026-06-25

Первый выпуск с поддержкой Windows.

### Added
- **Windows PowerShell port (beta):** `windows/ghostdraft.ps1` + `windows/install.ps1`.
  `pipe` читает stdin и печатает в терминал, ничего не пиша на диск. `new [--clipboard]`
  редактирует эфемерный черновик и по выходу делает shred + чистку editor-следов.
  ЧЕСТНО: на Windows нет встроенного RAM-диска, поэтому без открытого vault черновик
  ложится во временный файл НА ДИСКЕ (ACL только для юзера) + best-effort overwrite-shred;
  реальная эфемерность — только внутри открытого vault securetrash (BitLocker VHDX,
  crypto-shred при закрытии). `--clipboard` опасен (история Win+V + Cloud Clipboard),
  по умолчанию ВЫКЛ, фоновой авто-очистки на Windows нет. Pester покрывает оркестровку
  с замоканными editor/shred/clipboard (windows-CI).

## [0.1.2] — 2026-06-24

Релиз догоняет ассеты до исходников: hardening установщика и подписи, осевший
в `main` после тега `v0.1.1`, теперь попадает в публичный релиз.

### Security
- **install.sh fail-closed:** отсутствие `SHA256SUMS.sig` на релизе теперь прерывает
  установку (обход для старых релизов — `ALLOW_UNSIGNED_LEGACY=1`); отсутствие `ssh-keygen`
  больше не молчит, а громко предупреждает, что подпись не проверена (только целостность).
- **Подпись релиза fail-closed:** `release.yml` прерывает выпуск (`exit 1`), если
  `RELEASE_SIGNING_KEY` не задан, — неподписанный релиз невозможен.

## [0.1.1] — 2026-06-22

### Added
- **Подпись релизов (Ed25519, опциональная):** CI подписывает `SHA256SUMS`, `install.sh`
  авто-проверяет подпись поверх контрольной суммы (мягкая деградация). Pubkey в `SECURITY.md`.
- Homebrew `Formula/ghostdraft.rb`, `LICENSE`/`SECURITY.md`/`CONTRIBUTING.md`,
  English-primary README + `README.ru.md`, флаги `-v`/`--version`, `-h`/`--help`.

### Fixed
- **Уникальное имя тома RAM-диска** (суффикс из urandom) + mountpoint из `diskutil`: фикс
  коллизии параллельных инстансов и промаха detach по фиксированному имени.
- **Офлайн `vendor --check`:** хеш вшитого common-блока против запиннутого SHA, без сети.

### Changed
- Честный `desc` в Homebrew-формуле — «RAM disk, not on-disk temp» вместо «leaves no disk trace».

## [0.1.0] — 2026-06-19

Первый функциональный срез: эфемерный черновик для чувствительного текста на macOS.

### Added
- **`ghostdraft pipe`** — прочитать stdin, напечатать в терминал, на диск НЕ писать
  ничего (`pbpaste | ghostdraft pipe`). Самый безопасный режим; честно предупреждает,
  что scrollback терминала всё равно держит текст в памяти.
- **`ghostdraft new`** — эфемерный черновик в `$EDITOR`/nano с выбором места по приоритету:
  `GHOSTDRAFT_DIR` (override) → открытый vault securetrash (`/Volumes/SecretVault`,
  переопределяемо `ST_VAULT_VOLUME`) → RAM-диск (`hdiutil attach -nomount ram://` + HFS+).
  Если безопасного места нет — **честный отказ** (exit 3), без молчаливой записи в `/tmp`
  на APFS. По выходу (trap EXIT/INT/TERM): shred черновика (`securetrash shred`, иначе
  overwrite+rm), чистка editor-следов (vim `.swp`/`.swo`/`.swn`/`.un~`, nano backup),
  detach RAM-диска, если создали его.
- **`ghostdraft new --clipboard`** — опционально положить черновик в системный буфер с
  явным подтверждением (опасно: clipboard-менеджеры + iCloud Universal Clipboard синкает
  буфер на другие устройства). Авто-очистка через `${GHOSTDRAFT_CLIP_SECS:-20}`с, но только
  если буфер не сменился (не затираем то, что пользователь скопировал позже).
- Вендоринг общего ядра `lib/common.sh` из securetrash inline-маркерами + CI-чек дрейфа
  (pin git-ref + SHA256).
- Дистрибуция: checksum-verified `install.sh` (бинарь + `SHA256SUMS` с релизного тега),
  `release.yml` собирает ассеты на push тега `v*`.

### Honest limitations
- ghostdraft НЕ обещает «ноль следов» там, где ОС физически может оставить копию.
  **Не можем вычистить:** scrollback терминала, swap ОС, `~/.viminfo` (регистры/последний
  yank/история поиска) — об этом утилита говорит прямо.
- На macOS `/dev/shm` НЕТ; настоящая in-memory — только RAM-диск. Fallback-shred на SSD —
  **не гарантия** (ровно об этом предупреждает securetrash); реальное стирание даёт
  RAM-disk detach или crypto-shred закрытого vault. Подробности — `README.md`
  «Scope & limitations».
- `--clipboard` опасен и по умолчанию ВЫКЛ; авто-очистка НЕ отменяет уже снятую копию.

### Tests
- bats 21/21 (scaffold + `pipe` + `new` + `--clipboard`), shellcheck clean (`--severity=style`).
- Тесты идут на Linux-CI через PATH-стаб `uname` (→ Darwin для `require_macos`) +
  portable `stat` (GNU `-c` / BSD `-f`); macOS-примитивы (`hdiutil`/`diskutil`) тесты не
  трогают (`GHOSTDRAFT_DIR` override / `GHOSTDRAFT_DISABLE_RAM`).
- Real-device smoke на macOS: `new` создал RAM-диск, открыл редактор, по выходу сделал
  shred и detach (регрессия subshell-leak покрыта).

[Unreleased]: https://github.com/Di-kairos/ghostdraft/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/Di-kairos/ghostdraft/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/Di-kairos/ghostdraft/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/Di-kairos/ghostdraft/releases/tag/v0.1.0
