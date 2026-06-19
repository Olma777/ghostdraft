# ghostdraft

Эфемерный черновик для чувствительного текста — часть экосистемы
[Paranoid Tools](https://github.com/Di-kairos/paranoid-tools).

Написать/просмотреть seed, пароль или ключ так, чтобы после закрытия следов не
осталось в обычных местах (`~/.*_history`, tmp, recent docs, editor backups/viminfo).

> **Статус: ранний (v0.1.0).** Готовы `pipe` (просмотр без записи на диск) и `new`
> (черновик в открытом vault / на RAM-диске → `$EDITOR` → shred + чистка editor-следов
> по выходу), включая опциональный `--clipboard` (опасно, с подтверждением + авто-очистка).

## Использование

```bash
ghostdraft new            # эфемерный черновик в открытом vault / на RAM-диске
ghostdraft new --clipboard # + положить в буфер и очистить через N сек (ОПАСНО, см. ниже)
pbpaste | ghostdraft pipe # просмотреть из буфера, на диск не писать ничего
ghostdraft version
```

## Архитектура

- Single-file Bash, ноль зависимостей. Нативные примитивы macOS (`hdiutil` для RAM-диска,
  `$EDITOR`/nano). `new` предпочитает писать **внутрь открытого vault** securetrash.
- Общее ядро (`lib/common.sh`) **вендорится** из securetrash inline, пиннуто к git-ref;
  `tools/vendor-common.sh --check` ловит дрейф в CI. См. `paranoid-tools/README.md`.

## Куда `new` пишет черновик (по приоритету)

1. **`$GHOSTDRAFT_DIR`** — если задан и доступен на запись (override для своих сценариев;
   безопасность на диске — на твоей совести).
2. **Открытый vault securetrash** (`/Volumes/SecretVault`, переопределяется
   `$ST_VAULT_VOLUME`) — зашифрован; закрытие vault даёт crypto-shred.
3. **RAM-диск** (`hdiutil attach -nomount ram://` + HFS+) — живёт в RAM, исчезает при
   detach по выходу; не синкается, не ложится на SSD.
4. **Ничего из этого недоступно → отказ** (exit 3). НЕ пишем молча в `/tmp` на APFS.

## Scope & limitations

> Принцип экосистемы: честно про пределы — здесь особенно легко скатиться в снейкойл,
> поэтому НЕ обещаем «ноль следов»:
> - **на macOS `/dev/shm` НЕТ**; `/tmp`/`$TMPDIR` лежат на APFS (на диске). Настоящая
>   in-memory — только RAM-диск (`hdiutil attach -nomount ram://`), его и используем;
> - **что вычищаем по выходу:** сам черновик (`securetrash shred`, иначе overwrite+rm),
>   vim swap/undo (`.swp`/`.swo`/`.swn`/`.un~`), nano backup (`file~`), и detach нашего
>   RAM-диска;
> - **что вычистить НЕ можем** (и честно об этом говорим): scrollback терминала, swap ОС,
>   `~/.viminfo` (регистры/последний yank/история поиска). Это вне досягаемости утилиты;
> - **`--clipboard` для seed опасен** (clipboard-менеджеры + Universal Clipboard синкает
>   буфер в iCloud на другие устройства) — по умолчанию ВЫКЛ, при включении требует
>   подтверждения; авто-очистка через `${GHOSTDRAFT_CLIP_SECS:-20}`с, но лишь если буфер
>   не сменился, и она НЕ отменяет уже снятую копию;
> - **fallback-shred на SSD — не гарантия** (ровно об этом предупреждает securetrash);
>   реальное стирание даёт RAM-disk detach или crypto-shred закрытого vault.

## Windows-эквивалент

Планируется во вторую очередь: RAM-диск (ImDisk/сторонний), очистка clipboard,
Notepad/editor backups, jump lists / recent. Порт — как у securetrash.
