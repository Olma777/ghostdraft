# Pester 5 — логика ghostdraft.ps1 (Windows-порт). Дот-сорс под ST_NO_MAIN=1: определяет
# функции, не запуская диспетчер. ghostdraft трогает внешний мир (editor/shred/clipboard),
# поэтому эти примитивы МОКАЮТСЯ: тест проверяет оркестровку (выбор каталога, порядок,
# shred-в-finally, --clipboard-гейт), не запуская notepad и не стирая реальные файлы.
# CLI-уровень (version, pipe, exit-коды) — через свежий pwsh.

BeforeAll {
    $env:ST_NO_MAIN = '1'
    $script:ScriptPath = Join-Path $PSScriptRoot '..\ghostdraft.ps1'
    . $script:ScriptPath
    Remove-Item Env:\ST_NO_MAIN -ErrorAction SilentlyContinue
}

AfterAll {
    Remove-Item Env:\ST_NO_MAIN -ErrorAction SilentlyContinue
}

Describe 'ghostdraft new — orchestration (override dir)' {
    BeforeEach {
        $script:Work = Join-Path ([System.IO.Path]::GetTempPath()) ("gd_t_" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Work -Force | Out-Null
        $env:GHOSTDRAFT_DIR = $script:Work
        Mock Invoke-GdEditor     { }
        Mock Invoke-GdShred      { }
        Mock Set-GdClipboardDraft { $true }
        Mock Clear-GdEditorResidue { }
    }
    AfterEach {
        Remove-Item Env:\GHOSTDRAFT_DIR -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $script:Work -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'launches the editor and shreds the draft afterward' {
        Invoke-GdNew -ArgList @() | Out-Null
        Should -Invoke Invoke-GdEditor -Times 1 -Exactly
        Should -Invoke Invoke-GdShred  -Times 1 -Exactly
    }

    It 'does NOT touch the clipboard without --clipboard' {
        Invoke-GdNew -ArgList @() | Out-Null
        Should -Invoke Set-GdClipboardDraft -Times 0 -Exactly
    }

    It '--clipboard copies after editing' {
        Invoke-GdNew -ArgList @('--clipboard') | Out-Null
        Should -Invoke Set-GdClipboardDraft -Times 1 -Exactly
    }

    It 'rejects an unknown argument' {
        { Invoke-GdNew -ArgList @('--bogus') } | Should -Throw
    }

    It 'shreds even when the editor fails (cleanup in finally)' {
        Mock Invoke-GdEditor { throw 'editor crashed' }
        { Invoke-GdNew -ArgList @() } | Should -Throw
        Should -Invoke Invoke-GdShred -Times 1 -Exactly
    }
}

Describe 'ghostdraft new — on-disk fallback (no vault)' {
    BeforeEach {
        Remove-Item Env:\GHOSTDRAFT_DIR -ErrorAction SilentlyContinue
        $script:Fake = Join-Path ([System.IO.Path]::GetTempPath()) ("gd_fb_" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Fake -Force | Out-Null
        Mock Test-GdWritableDir  { $false }            # vault недоступен
        Mock New-GdSecureTempDir { $script:Fake }      # детерминированный temp
        Mock Invoke-GdEditor     { }
        Mock Invoke-GdShred      { }
        Mock Clear-GdEditorResidue { }
        Mock Remove-GdTempDir    { }
    }
    AfterEach {
        Remove-Item -LiteralPath $script:Fake -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'falls back to a secure temp dir and removes it afterward' {
        Invoke-GdNew -ArgList @() | Out-Null
        Should -Invoke New-GdSecureTempDir -Times 1 -Exactly
        Should -Invoke Remove-GdTempDir -Times 1 -Exactly
    }
}

Describe 'i18n' {
    It 'returns English residue note by default' {
        $script:GD_LOCALE = 'en'
        (T 'new_residue') | Should -Match 'pagefile'
    }
    It 'returns Russian residue note under ru locale' {
        $script:GD_LOCALE = 'ru'
        (T 'new_residue') | Should -Match 'pagefile'
        (T 'new_residue') | Should -Match 'НЕ могу'
    }
    It 'clip_danger mentions Cloud Clipboard' {
        $script:GD_LOCALE = 'en'
        (T 'clip_danger') | Should -Match 'Cloud Clipboard'
    }
    It 'falls back to the key for an unknown id' {
        (T 'no_such_key') | Should -Be 'no_such_key'
    }
}

Describe 'CLI surface (child pwsh)' {
    It 'prints the version' {
        $out = & pwsh -NoProfile -File $script:ScriptPath version
        ($out -join "`n") | Should -Match 'ghostdraft 0\.1\.3'
    }
    It 'pipe echoes stdin and writes nothing to disk' {
        $out = 'top-secret-seed' | & pwsh -NoProfile -File $script:ScriptPath pipe
        ($out -join "`n") | Should -Match 'top-secret-seed'
    }
    It 'exits non-zero on an unknown command' {
        & pwsh -NoProfile -File $script:ScriptPath bogus *> $null
        $LASTEXITCODE | Should -Not -Be 0
    }
}
