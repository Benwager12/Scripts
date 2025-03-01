# Install winget for user
function InstallWinget {
    $API_URL = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
    $DOWNLOAD_URL = $(Invoke-RestMethod $API_URL).assets.browser_download_url |
    Where-Object {$_.EndsWith(".msixbundle")}

    try {
        Invoke-WebRequest -URI $DOWNLOAD_URL -OutFile winget.msixbundle -UseBasicParsing
    } catch {
        Write-Host "Failed to download Winget, please try again later." -ForegroundColor Red
        exit
    }
    Add-AppxPackage winget.msixbundle
    Remove-Item winget.msixbundle
}

function GetNodeVersion {
    try {
        $nodeVersion = node -v
    } catch {
        return "0"
    }
    if ($nodeVersion.StartsWith("v")) {
        $nodeVersion = $nodeVersion.Substring(1)
    }
    $nodeVersion = $nodeVersion.Split(".")[0]
    return [decimal]$nodeVersion
}

function TestWindowsTerminal {
    try {
        $wtVersion = wt nt "echo Hi"
        return $null -ne $wtVersion
    } catch {
        return $false
    }
}

function IsGitInstalled {
    $gitVersion = git --version
    return $null -ne $gitVersion
}

# Choose directory to install AI
$installDir = Read-Host "Enter the directory where the AI folder will be (default is $pwd)"
if ($installDir -eq "") {
    $installDir = $pwd
}

if (-not (Test-Path $installDir)) {
    Write-Host "Directory does not exist" -ForegroundColor Red
    exit
}

# Ask user what they'd like their AI directory to be called
$aiDir = Read-Host "Enter the name of the AI directory (default is AI)"
if ($aiDir -eq "") {
    $aiDir = "AI"
}

# Create the AI directory if it doesn't exist
$aiPath = Join-Path $installDir $aiDir
if (-not (Test-Path $aiPath)) {
    $ignored = New-Item -Path $aiPath -ItemType Directory
} else {
    Write-Host "AI directory already exists" -ForegroundColor Yellow
    $itemsInDirectory = Get-ChildItem $aiPath | Measure-Object
    if ($itemsInDirectory.Count -gt 0) {
        Write-Host "AI directory is not empty" -ForegroundColor Red
        exit
    }
}

# Check if the user has winget installed, if not, download and install it
try {
    $wingetVersion = winget --version
    Write-Host "Winget is installed, version is $wingetVersion" -ForegroundColor Green
} catch {
    # Prompt the user if they want to install Winget, if not, exit
    $installWinget = Read-Host "Winget is not installed, would you like to install it? (Y/N)"
    if ($installWinget -eq "Y" -or $installWinget -eq "y" -or $installWinget -eq "") {
        InstallWinget
    } else {
        exit
    }
    Write-Host "Winget has been installed, version is $(winget --version)" -ForegroundColor Green
}

# Install nodejs version is less than 18
if ((GetNodeVersion) -lt 18) {
    $installNodeJS = Read-Host "Node.js is not installed, would you like to install it? (Y/N)"
    if ($installNodeJS -eq "Y" -or $installNodeJS -eq "y" -or $installNodeJS -eq "") {
        winget install -e --id Node.NodeJS
    } else {
        exit
    }
} else {
    Write-Host "Node.js is installed and the version is 18 or higher." -ForegroundColor Green
}

# Install git if not installed
if (!(IsGitInstalled)) {
    $installGit = Read-Host "Git is not installed, would you like to install it? (Y/N)"
    if ($installGit -eq "Y" -or $installGit -eq "y" -or $installGit -eq "") {
        winget install -e --id Git.Git
    } else {
        exit
    }
} else {
    Write-Host "Git is installed." -ForegroundColor Green
}

# Install Kobold into AI directory
Write-Host "Installing Kobold into directory"
$koboldUrl = "https://github.com/LostRuins/koboldcpp/releases/latest/download/koboldcpp.exe"
try {
    Invoke-WebRequest -URI $koboldUrl -OutFile "$aiPath\koboldcpp.exe"
} catch {
    Write-Host "Failed to download Kobold, please try again later." -ForegroundColor Red
}

# Make a model directory in AI directory
$modelPath = Join-Path $aiPath "Models"
try {
    $ignored = New-Item -Path $modelPath -ItemType Directory
    Start-Sleep -Seconds 1
} catch {
    Write-Host "Failed to create Models directory" -ForegroundColor Red
}

# Clone sillytavern
Write-Host "Cloning SillyTavern into directory"
try {
    git clone "https://github.com/SillyTavern/SillyTavern" "$aiPath\SillyTavern"
} catch {
    Write-Host "Failed to clone SillyTavern, please try again later." -ForegroundColor Red
}

# Ask user if they would like to install launch script
$InstallLaunch = Read-Host "Would you like to install the launch script? (Y/N)"
if ($InstallLaunch -eq "Y" -or $InstallLaunch -eq "y" -or $InstallLaunch -eq "") {
    $launchScriptURL = "https://missingember.info/Scripts/Launch.ps1"
    try {
        Invoke-WebRequest -URI $launchScriptURL -OutFile "$aiPath\Launch.ps1" -UseBasicParsing

        # Make launch batch file
        $LaunchBatContents = "@echo off`nPowershell.exe -ExecutionPolicy Bypass -File `".\Launch.ps1`""
        $ignored = New-Item -Path "$aiPath\Launch.bat" -ItemType File -Value $LaunchBatContents
    } catch {
        Write-Host "Failed to download Launch script, please try again later." -ForegroundColor Red
    }
}

Write-Host "Installation complete" -ForegroundColor Green
Write-Host "Now what's recommended is to install a model, you can do this by placing the model in the Models directory in the AI directory."

# Ask user if they would like to install a model
$OpenModelPage = Read-Host "Would you like to open the download page for the current recommended model? (Y/N)"
if ($OpenModelPage -eq "Y" -or $OpenModelPage -eq "y" -or $OpenModelPage -eq "") {
    Start-Process "https://missingember.info/Models"
}
