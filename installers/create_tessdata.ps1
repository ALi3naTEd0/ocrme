param(
    [Parameter(Mandatory=$false)]
    [string]$TessdataFolder = "assets/tessdata"
)

# Create the tessdata directory if it doesn't exist
if (-not (Test-Path $TessdataFolder)) {
    New-Item -ItemType Directory -Path $TessdataFolder -Force
    Write-Host "Created tessdata directory: $TessdataFolder"
}

# Define core language files to download
$languages = @("eng", "spa")

# Download URL for tessdata files
$baseUrl = "https://github.com/tesseract-ocr/tessdata_fast/raw/main"

foreach ($lang in $languages) {
    $outputFile = "$TessdataFolder/$lang.traineddata"
    
    # Skip download if the file already exists
    if (Test-Path $outputFile) {
        Write-Host "Language file for $lang already exists, skipping download"
        continue
    }
    
    $url = "$baseUrl/$lang.traineddata"
    Write-Host "Downloading $lang language data from $url"
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $outputFile -ErrorAction Stop
        Write-Host "Successfully downloaded $lang language data"
    }
    catch {
        Write-Error "Failed to download $lang language data: $_"
        exit 1
    }
}

Write-Host "Tessdata preparation completed successfully"
