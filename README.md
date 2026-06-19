# ghostdraft

Эфемерный черновик для чувствительного текста — часть экосистемы
[Paranoid Tools](https://github.com/Di-kairos/paranoid-tools).

Написать/просмотреть seed, пароль или ключ так, чтобы после закрытия следов не
осталось в обычных местах (`~/.*_history`, tmp, recent docs, editor backups/viminfo).

> **Статус: ранний (v0.1.0, scaffold).** Сейчас готов каркас: вендоринг общего ядра
> + dispatcher. Логика (`new`, `pipe`, shred, чистка editor-истории, `--clipboard`) —
> в следующих паках.

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

## Scope & limitations

> Раздел будет дополнен по мере реализации ядра. Принцип экосистемы: честно про пределы —
> здесь особенно легко скатиться в снейкойл, поэтому НЕ обещаем «ноль следов»:
> - **на macOS `/dev/shm` НЕТ**; `/tmp`/`$TMPDIR` лежат на APFS (на диске). Настоящая
>   память — только RAM-диск (`hdiutil attach -nomount ram://`). Реализуем честно или
>   помечаем in-memory как Linux-only;
> - **swap и scrollback терминала** ОС может оставить — перечисляем, не скрываем;
> - **`--clipboard` для seed опасен** (clipboard-менеджеры + Universal Clipboard синкает
>   буфер в iCloud на другие устройства) — по умолчанию ВЫКЛ, с предупреждением;
> - чистим editor-следы: vim `.swp`/`.un~` **и `viminfo`**, nano backup, VSCode history.

## Windows-эквивалент

Планируется во вторую очередь: RAM-диск (ImDisk/сторонний), очистка clipboard,
Notepad/editor backups, jump lists / recent. Порт — как у securetrash.
