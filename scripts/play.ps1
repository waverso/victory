# Starts the title with the settings this fork is played with.
#   scripts\play.ps1                      the executable in victory.toml's game_dir
#   scripts\play.ps1 -Exe <path>          another copy's executable
# -Safe          without the newer, faster ways (the first thing to try when something is wrong)
# -RayTracing    the title's own ray-traced indirect light: lit interiors, about a third slower
# -Fit           for 8 GB of video memory and 12 threads: fewer textures kept ahead, fewer list workers
# -Height <n>    renders at n lines of a 16:9 picture (576: 1024x576), FidelityFX scales it to the output
# -RenderScale   the same as a fraction of the output (0.2667)
# -Build         target\diag (the default) or target\release
# -More          other settings: -More @{VICTORY_PANEL='1'}
# The run's output goes to logs\play-<time>.log. Run it from a normal window, not as administrator.
param(
    [string]$Exe,
    [switch]$Safe,
    [switch]$RayTracing,
    [switch]$Fit,
    [ValidateRange(0, 4320)][int]$Height = 0,
    [ValidateRange(0.1, 1.0)][double]$RenderScale,
    [ValidateSet('diag', 'release')][string]$Build = 'diag',
    [hashtable]$More = @{}
)
$root = Split-Path -Parent $PSScriptRoot
$settings = @{
    VICTORY_TEXTURE_NO_WAIT = '1'; VICTORY_RELAY = '2'; VICTORY_WIDE_BACK = '1'; VICTORY_CARD_REHASH_RUNS = '1'
    VICTORY_JOIN_COPIES = '1'; VICTORY_INDIRECT_WINDOW = '1'; VICTORY_RELAY_COPY = '1'; VICTORY_CARD_STEPS = '2'
    VICTORY_INDIRECT_BATCH = '2'; VICTORY_MAP_THREADS = '1'; VICTORY_TITLE_PRIORITIES = '0'; VICTORY_CARD_AWAKE = '1'
    VICTORY_SHOW_AFTER = '1'; VICTORY_AMBIENT = '0.8'; VICTORY_D3D12_DRED = 'light'
}
if ($Safe) {
    $settings.VICTORY_UNDER_WIDE = '0'; $settings.VICTORY_LAND_ECHO = '0'
} else {
    $settings.VICTORY_THIN = '1'; $settings.VICTORY_JOIN_PARTS = '8'; $settings.VICTORY_UPLOAD_AHEAD = '1'
}
if ($Fit) {
    $settings.VICTORY_RIPE_BLOCKS = '4'; $settings.VICTORY_TEXTURE_ROOM_PERCENT = '85'; $settings.VICTORY_THIN_THREADS = '4'
}
if ($Height -gt 0) { $RenderScale = $Height / 2160 }
if ($RenderScale) { $settings.VICTORY_RENDER_SCALE = $RenderScale.ToString([Globalization.CultureInfo]::InvariantCulture) }
if ($RayTracing) { $settings.VICTORY_BVH_BUILDER = '1' }
foreach ($k in $More.Keys) { $settings[$k] = $More[$k] }

$victory = Join-Path $root "target\$Build\victory.exe"
if (-not (Test-Path $victory)) { Write-Host "No $victory. Build it first: scripts\build.cmd"; return }
if (-not $Exe) {
    $toml = Join-Path $root 'victory.toml'
    $line = if (Test-Path $toml) { Select-String -Path $toml -Pattern "^\s*game_dir\s*=\s*'([^']+)'" | Select-Object -First 1 }
    if (-not $line) { Write-Host "No -Exe given and no game_dir in victory.toml (copy victory.example.toml)."; return }
    $Exe = Join-Path $line.Matches[0].Groups[1].Value 'game_scarlett_master.exe'
}
if (-not (Test-Path $Exe)) { Write-Host "No $Exe."; return }
$Exe = (Resolve-Path $Exe).Path

# (Other settings left over in this window go; where your files are stays.)
$paths = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR'
Get-ChildItem Env:VICTORY_* | Where-Object { $_.Name -notin $paths } | ForEach-Object { Remove-Item "Env:$($_.Name)" }
foreach ($k in $settings.Keys) { Set-Item "Env:$k" $settings[$k] }

$logs = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$log = Join-Path $logs "play-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$os = Get-CimInstance Win32_OperatingSystem
Write-Host ''
Write-Host "  $Exe" -ForegroundColor Cyan
Write-Host ("  RAM / commit : {0} GB / {1} GB" -f [math]::Round($os.TotalVisibleMemorySize / 1MB, 1), [math]::Round($os.TotalVirtualMemorySize / 1MB, 1))
if ($RenderScale) { Write-Host ("  render scale : {0:0.####} ({1}x{2} of 3840x2160)" -f $RenderScale, [math]::Round(3840 * $RenderScale), [math]::Round(2160 * $RenderScale)) }
Write-Host "  log          : $log"
Write-Host ''
# victory.toml is looked for in the current folder.
$p = Start-Process $victory -ArgumentList @('run', "`"$Exe`"", '--execute') -WorkingDirectory $root -NoNewWindow -PassThru `
     -RedirectStandardError $log -RedirectStandardOutput ($log -replace '\.log$', '.out.log')
$null = $p.Handle
$p.WaitForExit()
Write-Host "  exit code : $($p.ExitCode)"
