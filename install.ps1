<#
.SYNOPSIS
    Installs (or uninstalls) Turnbased Anytime for Pillars of Eternity 1. No compilation required.

.DESCRIPTION
    Turnbased Anytime lets you switch between real-time-with-pause and turn-based ("Tactical")
    combat at runtime from a keybind - including mid-combat, both directions.

    Install:
      1. copies the sidecar (LoomTurnbasedAnytime.dll) into the game's Managed folder,
      2. backs up Assembly-CSharp.dll (once), and
      3. injects one call to LoomTurnbasedAnytime.Bootstrap.Tick() at the top of
         GameState.Update() with the bundled Mono.Cecil.dll.

    Needs only Windows PowerShell (5.1+, built into Windows) - no .NET SDK, no C# compiler. Run it
    from the extracted release folder (the one that also contains LoomTurnbasedAnytime.dll and
    Mono.Cecil.dll). Close the game first.

.PARAMETER GameDir
    Path to the Pillars of Eternity install folder (contains PillarsOfEternity_Data). Auto-detected
    if omitted; you are prompted if it can't be found.

.PARAMETER Uninstall
    Cleanly remove Turnbased Anytime: surgically strips only its hook call + assembly reference (so
    other mods that hook the same method are left intact) and deletes LoomTurnbasedAnytime.dll.

.EXAMPLE
    ./install.ps1

.EXAMPLE
    ./install.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [string]$GameDir,
    [switch]$Uninstall,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Normalize-PathInput([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    $p = $path.Trim()
    if ($p.Length -ge 2 -and (($p.StartsWith('"') -and $p.EndsWith('"')) -or ($p.StartsWith("'") -and $p.EndsWith("'")))) {
        $p = $p.Substring(1, $p.Length - 2).Trim()
    }
    return [Environment]::ExpandEnvironmentVariables($p)
}

function Get-SteamRoots {
    $roots = New-Object System.Collections.Generic.List[string]
    foreach ($regPath in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $props = Get-ItemProperty -LiteralPath $regPath -ErrorAction Stop
            foreach ($name in @('SteamPath','InstallPath')) {
                $value = Normalize-PathInput $props.$name
                if ($value -and (Test-Path -LiteralPath $value)) { $roots.Add($value) }
            }
        } catch { }
    }
    foreach ($root in @($roots.ToArray())) {
        $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path -LiteralPath $vdf)) { continue }
        try {
            foreach ($line in Get-Content -LiteralPath $vdf) {
                if ($line -match '"path"\s+"([^"]+)"') {
                    $library = ($Matches[1] -replace '\\\\', '\')
                    if ($library -and (Test-Path -LiteralPath $library)) { $roots.Add($library) }
                }
            }
        } catch { }
    }
    return $roots.ToArray() | Where-Object { $_ } | Select-Object -Unique
}

function Get-CandidateGameDirs {
    $guesses = New-Object System.Collections.Generic.List[string]
    foreach ($root in Get-SteamRoots) { $guesses.Add((Join-Path $root 'steamapps\common\Pillars of Eternity')) }
    foreach ($g in @(
        'C:\Program Files (x86)\Steam\steamapps\common\Pillars of Eternity',
        'C:\Program Files\Steam\steamapps\common\Pillars of Eternity',
        'D:\SteamLibrary\steamapps\common\Pillars of Eternity',
        'E:\SteamLibrary\steamapps\common\Pillars of Eternity'
    )) { $guesses.Add($g) }
    return $guesses.ToArray() | Where-Object { $_ } | Select-Object -Unique
}

function Test-GameDir([string]$dir) {
    if ([string]::IsNullOrWhiteSpace($dir)) { return $false }
    return Test-Path -LiteralPath (Join-Path $dir 'PillarsOfEternity_Data\Managed\Assembly-CSharp.dll')
}

function Find-GameDir {
    foreach ($g in Get-CandidateGameDirs) { if (Test-GameDir $g) { return $g } }
    return $null
}

function Resolve-GameDir([string]$dir) {
    $try = Normalize-PathInput $dir
    if ([string]::IsNullOrWhiteSpace($try)) { return $dir }
    try {
        $leaf = Split-Path -Leaf $try
        if ($leaf -ieq 'Assembly-CSharp.dll' -or $leaf -ieq 'PillarsOfEternity.exe') { $try = Split-Path -Parent $try }
        if (Test-Path -LiteralPath $try) { $try = (Get-Item -LiteralPath $try).FullName } else { $try = [System.IO.Path]::GetFullPath($try) }
    } catch { return $dir }
    while ($try -and -not (Test-GameDir $try)) {
        $parent = Split-Path $try -Parent
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $try) { break }
        $try = $parent
    }
    if (Test-GameDir $try) { return $try }
    return $dir
}

if ($RemainingArgs -and $RemainingArgs.Count -gt 0) {
    $GameDir = (($GameDir, $RemainingArgs) | Where-Object { $_ }) -join ' '
}
if ($GameDir) { $GameDir = Resolve-GameDir $GameDir }
if (-not (Test-GameDir $GameDir)) { $auto = Find-GameDir; if (Test-GameDir $auto) { $GameDir = $auto } }
if (-not (Test-GameDir $GameDir)) {
    Write-Host "Could not find your Pillars of Eternity installation automatically." -ForegroundColor Yellow
    Write-Host "Paste the folder that contains 'PillarsOfEternity.exe' or 'PillarsOfEternity_Data'." -ForegroundColor DarkGray
    Write-Host "Quotes are optional; paths with spaces and parentheses are OK." -ForegroundColor DarkGray
    Write-Host "Example: C:\Program Files (x86)\Steam\steamapps\common\Pillars of Eternity" -ForegroundColor DarkGray
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        $entry = Read-Host "Pillars of Eternity install path (leave blank to cancel)"
        if ([string]::IsNullOrWhiteSpace($entry)) { throw "Cancelled." }
        $candidate = Resolve-GameDir $entry
        if (Test-GameDir $candidate) { $GameDir = $candidate; break }
        Write-Host "Could not find PillarsOfEternity_Data\Managed\Assembly-CSharp.dll from that path. Try the main game folder." -ForegroundColor Yellow
    }
    if (-not (Test-GameDir $GameDir)) { throw "Could not locate the game after several attempts." }
}
Write-Host "Game folder: $GameDir" -ForegroundColor DarkGray

$managed  = Join-Path $GameDir 'PillarsOfEternity_Data\Managed'
$asmPath  = Join-Path $managed 'Assembly-CSharp.dll'
$cecilPath = Join-Path $here 'Mono.Cecil.dll'
if (-not (Test-Path $cecilPath)) { throw "Required file not found: $cecilPath (run from the extracted release folder)." }

$proc = Get-Process -Name 'PillarsOfEternity*' -ErrorAction SilentlyContinue
if ($proc) { throw "Pillars of Eternity is running (pid $($proc.Id)). Close it and re-run." }

Add-Type -Path $cecilPath
$resolver = New-Object Mono.Cecil.DefaultAssemblyResolver
$resolver.AddSearchDirectory($managed)
$rp = New-Object Mono.Cecil.ReaderParameters
$rp.ReadWrite = $false; $rp.InMemory = $true; $rp.AssemblyResolver = $resolver

if ($Uninstall) {
    $module = [Mono.Cecil.ModuleDefinition]::ReadModule($asmPath, $rp)
    try {
        if (-not ($module.AssemblyReferences | Where-Object { $_.Name -eq 'LoomTurnbasedAnytime' })) {
            Write-Host "Turnbased Anytime is not installed (no hook present). Nothing to do." -ForegroundColor Yellow
            return
        }
        $gs = $module.Types | Where-Object { $_.Name -eq 'GameState' } | Select-Object -First 1
        $update = $gs.Methods | Where-Object { $_.Name -eq 'Update' -and -not $_.IsStatic -and -not $_.HasParameters -and $_.HasBody } | Select-Object -First 1
        $il = $update.Body.GetILProcessor()
        $remove = @()
        foreach ($ins in $update.Body.Instructions) {
            if ($ins.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Call -and $ins.Operand -is [Mono.Cecil.MethodReference]) {
                $mr = [Mono.Cecil.MethodReference]$ins.Operand
                if ($mr.DeclaringType -and $mr.DeclaringType.FullName -eq 'LoomTurnbasedAnytime.Bootstrap' -and $mr.Name -eq 'Tick') { $remove += $ins }
            }
        }
        foreach ($ins in $remove) { $il.Remove($ins) }
        # Remove ALL matching references (a re-patched assembly can carry more than one).
        # Loop by index + RemoveAt: Mono.Cecil Collection.Remove($item) silently no-ops under PowerShell.
        for ($i = $module.AssemblyReferences.Count - 1; $i -ge 0; $i--) {
            if ($module.AssemblyReferences[$i].Name -eq 'LoomTurnbasedAnytime') { $module.AssemblyReferences.RemoveAt($i) }
        }
        $tmp = "$asmPath.tbanytime-tmp"; if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Force }
        $module.Write($tmp); $module.Dispose()
        Copy-Item -LiteralPath $tmp -Destination $asmPath -Force; Remove-Item -LiteralPath $tmp -Force
        Remove-Item -LiteralPath (Join-Path $managed 'LoomTurnbasedAnytime.dll') -Force -ErrorAction SilentlyContinue
        Write-Host "`nTurnbased Anytime uninstalled (hook removed, other mods untouched)." -ForegroundColor Cyan
    } finally { if ($module) { $module.Dispose() } }
    return
}

# ---- INSTALL ----
$sidecarSrc = Join-Path $here 'LoomTurnbasedAnytime.dll'
foreach ($p in @($asmPath, $sidecarSrc)) { if (-not (Test-Path $p)) { throw "Required file not found: $p" } }

# 1. sidecar
Copy-Item -LiteralPath $sidecarSrc -Destination (Join-Path $managed 'LoomTurnbasedAnytime.dll') -Force
Write-Host "Installed LoomTurnbasedAnytime.dll" -ForegroundColor Green

# 2. backup once
$backup = "$asmPath.tbanytime-backup"
if (-not (Test-Path $backup)) { Copy-Item -LiteralPath $asmPath -Destination $backup -Force; Write-Host "Backed up Assembly-CSharp.dll -> $backup" -ForegroundColor Green }
else { Write-Host "Backup already exists: $backup" -ForegroundColor DarkGray }

# 3. inject hook
$module = [Mono.Cecil.ModuleDefinition]::ReadModule($asmPath, $rp)
try {
    if ($module.AssemblyReferences | Where-Object { $_.Name -eq 'LoomTurnbasedAnytime' }) {
        Write-Host "Already patched (hook present). DLL refreshed; nothing else to do." -ForegroundColor Yellow
        return
    }
    $gameState = $module.Types | Where-Object { $_.Name -eq 'GameState' } | Select-Object -First 1
    if (-not $gameState) { throw "Could not find type GameState." }
    $update = $gameState.Methods | Where-Object { $_.Name -eq 'Update' -and -not $_.IsStatic -and -not $_.HasParameters -and $_.HasBody } | Select-Object -First 1
    if (-not $update) { throw "Could not find GameState.Update()." }
    $sidecar   = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($sidecarSrc)
    $bootstrap = $sidecar.MainModule.Types | Where-Object { $_.FullName -eq 'LoomTurnbasedAnytime.Bootstrap' } | Select-Object -First 1
    if (-not $bootstrap) { throw "Bootstrap type not found in sidecar." }
    $tick = $bootstrap.Methods | Where-Object { $_.Name -eq 'Tick' -and $_.IsStatic -and -not $_.HasParameters } | Select-Object -First 1
    if (-not $tick) { throw "Bootstrap.Tick() not found in sidecar." }
    $importedTick = $module.ImportReference($tick)
    $il = $update.Body.GetILProcessor()
    $il.InsertBefore($update.Body.Instructions[0], $il.Create([Mono.Cecil.Cil.OpCodes]::Call, $importedTick))
    $module.AssemblyReferences.Add((New-Object Mono.Cecil.AssemblyNameReference('LoomTurnbasedAnytime', $sidecar.Name.Version)))
    $tmp = "$asmPath.tbanytime-patched"; if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Force }
    $module.Write($tmp); $module.Dispose()
    Copy-Item -LiteralPath $tmp -Destination $asmPath -Force; Remove-Item -LiteralPath $tmp -Force
    Write-Host "Patched GameState.Update -> LoomTurnbasedAnytime.Bootstrap.Tick()." -ForegroundColor Green
} finally { if ($module) { $module.Dispose() } }

Write-Host "`nTurnbased Anytime installed. Launch the game and press T (in or out of combat) to switch" -ForegroundColor Cyan
Write-Host "between real-time and turn-based. Rebind it in Options -> Controls (camera/turn group," -ForegroundColor Cyan
Write-Host "near Pass Turn / Wait Turn) like any other control." -ForegroundColor Cyan
Write-Host "To uninstall: run  install.ps1 -Uninstall  (or the uninstall.bat)." -ForegroundColor DarkGray
