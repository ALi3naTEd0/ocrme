param(
    [Parameter(Mandatory=$false)]
    [string]$InputFile = $null,
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "assets/logo.ico"
)

# Auto-detect best input file if not specified
if ($null -eq $InputFile) {
    # Prefer logo_mobile.svg for squared icons (better for app icons)
    if (Test-Path "assets/logo_mobile.svg") {
        $InputFile = "assets/logo_mobile.svg"
        Write-Host "Using logo_mobile.svg for icon conversion (best for app icons)"
    }
    elseif (Test-Path "assets/logo.svg") {
        $InputFile = "assets/logo.svg"
        Write-Host "Using logo.svg for icon conversion"
    }
    else {
        Write-Error "No logo files found in assets directory. Please provide an input file."
        exit 1
    }
}

# Function to check if a command exists
function Test-Command($command) {
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        if (Get-Command $command) { return $true }
    }
    catch {
        return $false
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
}

# Check if ImageMagick is available
$hasImageMagick = Test-Command "magick"

if (-not $hasImageMagick) {
    Write-Host "ImageMagick not found. Attempting to install with Chocolatey..."
    
    # Check for Chocolatey, install if not present
    if (-not (Test-Command "choco")) {
        Write-Host "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
    
    # Install ImageMagick
    Write-Host "Installing ImageMagick..."
    choco install imagemagick -y
    
    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # Check if install was successful
    $hasImageMagick = Test-Command "magick"
    if (-not $hasImageMagick) {
        Write-Error "Failed to install ImageMagick. Icon conversion will not be performed."
        exit 1
    }
}

# Convert SVG to ICO
Write-Host "Converting $InputFile to $OutputFile"
$iconSizes = @(16, 32, 48, 64, 128, 256)
$tmpFiles = @()

foreach ($size in $iconSizes) {
    $tmpFile = [System.IO.Path]::GetTempFileName() + ".png"
    magick convert -background transparent $InputFile -resize ${size}x${size} $tmpFile
    $tmpFiles += $tmpFile
}

# Combine all sizes into one ICO file
magick convert $tmpFiles $OutputFile

# Clean up temporary files
foreach ($tmpFile in $tmpFiles) {
    Remove-Item $tmpFile
}

Write-Host "Icon conversion complete: $OutputFile"
