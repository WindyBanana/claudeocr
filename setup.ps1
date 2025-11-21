# Claude OCR Setup Script for Windows PowerShell
# Run this with: powershell -ExecutionPolicy Bypass -File setup.ps1

$ErrorActionPreference = "Stop"

# Color output functions
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Cyan }
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Header {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "  $args" -ForegroundColor Blue
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
}

# Check if uv is installed
function Test-UvInstalled {
    try {
        $null = Get-Command uv -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Get uv version
function Get-UvVersion {
    try {
        $version = (uv --version 2>$null | Select-Object -First 1)
        return $version
    } catch {
        return "unknown"
    }
}

# Check Python version
function Test-Python {
    Write-Info "Checking Python version..."

    try {
        $pythonVersion = (python --version 2>&1) -replace "Python ", ""
        Write-Success "Python $pythonVersion found"

        $versionParts = $pythonVersion.Split('.')
        $major = [int]$versionParts[0]
        $minor = [int]$versionParts[1]

        if ($major -eq 3 -and $minor -ge 12) {
            Write-Success "Python version is compatible (3.12+)"
            return $true
        } else {
            Write-Warning "Python 3.12+ recommended (found $pythonVersion)"
            Write-Info "The project may still work, but consider upgrading"
            return $true
        }
    } catch {
        Write-Error "Python 3 not found"
        Write-Info "Please install Python 3.12+ from: https://www.python.org/downloads/"
        Write-Info "Make sure to check 'Add Python to PATH' during installation"
        return $false
    }
}

# Install uv
function Install-Uv {
    Write-Info "Installing uv for Windows..."
    Write-Info "This will download and run the official uv installer"
    Write-Host ""

    try {
        Invoke-Expression "& { $(Invoke-RestMethod https://astral.sh/uv/install.ps1) }"
        Write-Success "uv installed successfully!"

        # Refresh PATH for current session
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        return $true
    } catch {
        Write-Error "Installation failed: $_"
        return $false
    }
}

# Setup project
function Initialize-Project {
    Write-Header "Setting Up Project"

    # Check if .env exists
    if (-not (Test-Path .env)) {
        Write-Info "Creating .env file from template..."
        if (Test-Path .env.example) {
            Copy-Item .env.example .env
            Write-Success "Created .env file"
            Write-Warning "Please edit .env and add your API keys:"
            Write-Host "  ANTHROPIC_API_KEY=your-key-here"
            Write-Host "  OPENAI_API_KEY=your-key-here (optional)"
        } else {
            Write-Warning ".env.example not found, creating blank .env"
            New-Item -ItemType File -Path .env -Force | Out-Null
        }
    } else {
        Write-Success ".env file already exists"
    }

    # Install dependencies
    Write-Info "Installing Python dependencies..."
    try {
        uv sync
        Write-Success "Dependencies installed"
    } catch {
        Write-Error "Failed to install dependencies: $_"
        return $false
    }

    # Create directories
    Write-Info "Creating required directories..."
    $directories = @("input", "processed", "failed", "review", "logs")
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    Write-Success "Directories created"

    return $true
}

# Confirm action
function Confirm-Action {
    param([string]$message)

    $response = Read-Host "$message [y/N]"
    return ($response -eq 'y' -or $response -eq 'Y')
}

# Main script
Write-Header "Claude OCR Setup Script"

Write-Info "This script will check for uv and install it if needed."
Write-Host ""

# Check Python
if (-not (Test-Python)) {
    Write-Error "Python check failed. Please install Python 3.12+ first."
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host ""

# Check if uv is installed
if (Test-UvInstalled) {
    $version = Get-UvVersion
    Write-Success "uv is already installed: $version"
    Write-Host ""

    if (Confirm-Action "Do you want to proceed with project setup?") {
        if (Initialize-Project) {
            Write-Success "Setup complete!"
        } else {
            Write-Error "Setup failed."
            exit 1
        }
    } else {
        Write-Info "Setup cancelled."
        exit 0
    }
} else {
    Write-Warning "uv is not installed"
    Write-Host ""
    Write-Info "uv is required to manage Python dependencies for this project."
    Write-Info "It will be installed to your user directory (no admin rights required)."
    Write-Host ""
    Write-Info "Installation method: Official PowerShell installer"
    Write-Host ""

    if (Confirm-Action "Do you want to install uv now?") {
        if (Install-Uv) {
            # Verify installation
            if (Test-UvInstalled) {
                $version = Get-UvVersion
                Write-Success "Verified: $version"
                Write-Host ""

                if (Confirm-Action "Do you want to proceed with project setup?") {
                    if (Initialize-Project) {
                        Write-Success "Setup complete!"
                    } else {
                        Write-Error "Setup failed."
                        exit 1
                    }
                } else {
                    Write-Info "Setup cancelled. Run this script again when ready."
                    exit 0
                }
            } else {
                Write-Warning "uv was installed but not found in PATH."
                Write-Info "Please restart PowerShell and run this script again."
                exit 1
            }
        } else {
            Write-Error "Installation failed."
            exit 1
        }
    } else {
        Write-Info "Installation cancelled."
        Write-Info "You can install uv manually from: https://docs.astral.sh/uv/"
        exit 0
    }
}

Write-Host ""
Write-Header "Next Steps"
Write-Host ""
Write-Host "1. Add your API key to .env:"
Write-Host "   notepad .env" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Add images to process:"
Write-Host "   copy your_photos\*.jpg input\" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Run the program:"
Write-Host "   uv run python main.py" -ForegroundColor Cyan
Write-Host ""
Write-Host "For more information, see:"
Write-Host "  - README.md - Complete documentation"
Write-Host "  - QUICK_REFERENCE.md - Quick start guide"
Write-Host "  - VALIDATION_GUIDE.md - Validation system details"
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
