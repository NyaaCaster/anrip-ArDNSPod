param(
    [string]$Action = "all",
    [switch]$SkipPull,
    [switch]$Help
)

$ProjectName = "dnspod-ddns"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Help {
    Write-Host "DNSPod DDNS Docker Build Script"
    Write-Host ""
    Write-Host "Usage: .\build.ps1 [-Action <action>] [-SkipPull] [-Help]"
    Write-Host ""
    Write-Host "Actions:"
    Write-Host "  all      - Execute all steps (default)"
    Write-Host "  pull     - Update code only"
    Write-Host "  build    - Build image only"
    Write-Host "  restart  - Restart container only"
    Write-Host "  clean    - Clean images only"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\build.ps1"
    Write-Host "  .\build.ps1 -SkipPull"
    Write-Host "  .\build.ps1 -Action build"
}

if ($Help) {
    Show-Help
    exit 0
}

Write-Host ""
Write-Host "========================================"
Write-Host "  DNSPod DDNS Docker Build Script"
Write-Host "========================================"
Write-Host ""

Set-Location $ProjectDir

# Step 1: Update code
if ($Action -eq "all" -or $Action -eq "pull") {
    if (-not $SkipPull) {
        Write-Host "Step 1/6: Updating code..." -ForegroundColor Cyan
        if (Test-Path ".git") {
            git pull origin main
            Write-Host "Code updated." -ForegroundColor Green
        } else {
            Write-Host "Not a git repository, skipping." -ForegroundColor Yellow
        }
        Write-Host ""
    }
}

# Step 2: Stop container
if ($Action -eq "all" -or $Action -eq "restart") {
    Write-Host "Step 2/6: Stopping container..." -ForegroundColor Cyan
    $container = docker ps -a --filter "name=$ProjectName" --format "{{.Names}}"
    if ($container) {
        docker stop $ProjectName 2>$null
        Write-Host "Container stopped." -ForegroundColor Green
    } else {
        Write-Host "Container not found, skipping." -ForegroundColor Yellow
    }
    Write-Host ""
}

# Step 3: Remove old image
if ($Action -eq "all") {
    Write-Host "Step 3/6: Removing old image..." -ForegroundColor Cyan
    $image = docker images --filter "reference=$ProjectName*" --format "{{.Repository}}:{{.Tag}}"
    if ($image) {
        docker rmi -f $image 2>$null
        Write-Host "Old image removed." -ForegroundColor Green
    } else {
        Write-Host "No old image found, skipping." -ForegroundColor Yellow
    }
    Write-Host ""
}

# Step 4: Build image
if ($Action -eq "all" -or $Action -eq "build") {
    Write-Host "Step 4/6: Building image..." -ForegroundColor Cyan
    docker-compose build --no-cache
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Image built successfully." -ForegroundColor Green
    } else {
        Write-Host "Build failed." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# Step 5: Start container
if ($Action -eq "all" -or $Action -eq "restart") {
    Write-Host "Step 5/6: Starting container..." -ForegroundColor Cyan
    docker-compose up -d
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Container started." -ForegroundColor Green
        Write-Host ""
        docker ps --filter "name=$ProjectName"
    } else {
        Write-Host "Failed to start container." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# Step 6: Clean dangling images
if ($Action -eq "all" -or $Action -eq "clean") {
    Write-Host "Step 6/6: Cleaning dangling images..." -ForegroundColor Cyan
    $dangling = docker images -f "dangling=true" -q
    if ($dangling) {
        docker image prune -f
        Write-Host "Dangling images cleaned." -ForegroundColor Green
    } else {
        Write-Host "No dangling images found." -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($Action -eq "all") {
    Write-Host "========================================"
    Write-Host "  Build Complete!"
    Write-Host "========================================"
    Write-Host ""
    Write-Host "Common commands:" -ForegroundColor Yellow
    Write-Host "  View logs:    docker logs -f $ProjectName"
    Write-Host "  Manual update: docker exec $ProjectName /app/ddnspod.sh"
    Write-Host "  Restart:      docker restart $ProjectName"
    Write-Host "  Stop:         docker stop $ProjectName"
    Write-Host ""
}
