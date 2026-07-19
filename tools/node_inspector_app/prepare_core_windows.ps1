$ErrorActionPreference = 'Stop'

$version = '1.13.14'
$zipSha256 = 'f580782c6dd10f7691c66cea1d7c421813c5fbf7e305d1ee7ce0c3a40d196341'
$exeSha256 = 'db0d779948214cf761011d154c3a5da36df20394fa01a9fc798f1dc39fe9d183'
$dllSha256 = 'c7434cfa93c3041321dd19111c4de6c52b8a9531a65661ba45425d3c51ec69e2'
$assetDirectory = Join-Path $PSScriptRoot 'assets\core'
$executable = Join-Path $assetDirectory 'sing-box.exe'
$library = Join-Path $assetDirectory 'libcronet.dll'

New-Item -ItemType Directory -Force -Path $assetDirectory | Out-Null
if ((Test-Path $executable) -and (Test-Path $library)) {
    $existingHash = (Get-FileHash -Algorithm SHA256 $executable).Hash.ToLowerInvariant()
    $existingLibraryHash = (Get-FileHash -Algorithm SHA256 $library).Hash.ToLowerInvariant()
    if (($existingHash -eq $exeSha256) -and ($existingLibraryHash -eq $dllSha256)) {
        Write-Host "sing-box $version is ready."
        exit 0
    }
}
Remove-Item -Force -ErrorAction SilentlyContinue $executable, $library

$archive = Join-Path $env:TEMP "sing-box-$version-windows-amd64.zip"
$extractDirectory = Join-Path $env:TEMP "node-inspector-sing-box-$version"
$url = "https://github.com/SagerNet/sing-box/releases/download/v$version/sing-box-$version-windows-amd64.zip"

Write-Host "Downloading sing-box $version from the official SagerNet release..."
Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
$archiveHash = (Get-FileHash -Algorithm SHA256 $archive).Hash.ToLowerInvariant()
if ($archiveHash -ne $zipSha256) {
    Remove-Item -Force $archive
    throw "sing-box ZIP checksum mismatch. Expected $zipSha256, got $archiveHash"
}

if (Test-Path $extractDirectory) {
    Remove-Item -Recurse -Force $extractDirectory
}
Expand-Archive -Path $archive -DestinationPath $extractDirectory -Force
$sourceDirectory = Join-Path $extractDirectory "sing-box-$version-windows-amd64"
Copy-Item -Force (Join-Path $sourceDirectory 'sing-box.exe') $executable
Copy-Item -Force (Join-Path $sourceDirectory 'libcronet.dll') $library
Copy-Item -Force (Join-Path $sourceDirectory 'LICENSE') (Join-Path $assetDirectory 'LICENSE')

$installedHash = (Get-FileHash -Algorithm SHA256 $executable).Hash.ToLowerInvariant()
$installedLibraryHash = (Get-FileHash -Algorithm SHA256 $library).Hash.ToLowerInvariant()
if ($installedHash -ne $exeSha256) {
    Remove-Item -Force $executable
    throw "sing-box executable checksum mismatch. Expected $exeSha256, got $installedHash"
}
if ($installedLibraryHash -ne $dllSha256) {
    Remove-Item -Force $library
    throw "libcronet.dll checksum mismatch. Expected $dllSha256, got $installedLibraryHash"
}

Remove-Item -Force $archive
Remove-Item -Recurse -Force $extractDirectory
Write-Host "sing-box $version is ready and verified."
