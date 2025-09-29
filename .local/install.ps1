Param(
    [string]$TargetDirectory = "mimir-onprem",
    [string]$EnvFile,
    [switch]$NoUp,
    [switch]$NoInteractive,
    [string]$GitRef
)

$ErrorActionPreference = 'Stop'

$owner = if ($env:GITHUB_OWNER) { $env:GITHUB_OWNER } else { 'smartdataHQ' }
$repo = if ($env:GITHUB_REPO) { $env:GITHUB_REPO } else { 'cxs' }
$githubPath = '.local'
$defaultRef = if ($env:DEFAULT_GITHUB_REF) { $env:DEFAULT_GITHUB_REF } else { 'main' }
$githubRef = if ($GitRef) { $GitRef } elseif ($env:GITHUB_REF) { $env:GITHUB_REF } else { $defaultRef }

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
$null = New-Item -ItemType Directory -Path $tempDir
$downloadRoot = Join-Path $tempDir 'download'
$null = New-Item -ItemType Directory -Path $downloadRoot

function Cleanup {
    if (Test-Path $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force
    }
}

function Get-EnvValue {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][string]$Key
    )

    if (-not (Test-Path $File)) {
        return $null
    }

    foreach ($line in Get-Content -LiteralPath $File) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $parts = $trimmed.Split('=', 2)
        if ($parts.Count -lt 2) { continue }
        if ($parts[0].Trim() -eq $Key) {
            $value = $parts[1].Trim()
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            return $value
        }
    }
    return $null
}

function Invoke-DockerLogin {
    param(
        [Parameter(Mandatory = $true)][string]$Registry,
        [Parameter(Mandatory = $true)][string]$Username,
        [Parameter(Mandatory = $true)][string]$Token
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'docker'
    $psi.Arguments = "login $Registry -u $Username --password-stdin"
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $process.Start() | Out-Null
    $process.StandardInput.WriteLine($Token)
    $process.StandardInput.Close()

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "Docker login failed: $stderr"
    }
    if ($stdout) { Write-Verbose $stdout }
}

function New-GitHubHeaders {
    param(
        [string]$Token,
        [string]$Accept
    )
    $headers = @{ 'User-Agent' = 'cxs-installer' }
    if ($Token) { $headers['Authorization'] = "token $Token" }
    if ($Accept) { $headers['Accept'] = $Accept }
    return $headers
}

function Save-GitHubFile {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Destination,
        [string]$Token
    )
    $headers = New-GitHubHeaders -Token $Token -Accept 'application/vnd.github.v3.raw'
    $destDir = Split-Path -Path $Destination -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Invoke-WebRequest -Uri $Url -Headers $headers -OutFile $Destination
}

function Get-GitHubFolder {
    param(
        [Parameter(Mandatory = $true)][string]$Owner,
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Destination,
        [string]$Token,
        [string]$Ref
    )

    $uri = "https://api.github.com/repos/$Owner/$Repo/contents/$Path"
    if ($Ref) {
        $uri = "$uri?ref=$Ref"
    }

    $headers = New-GitHubHeaders -Token $Token -Accept 'application/vnd.github.v3+json'
    try {
        $items = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    } catch {
        throw "GitHub request failed for $uri: $($_.Exception.Message)"
    }

    if ($items -isnot [System.Collections.IEnumerable]) {
        $items = @($items)
    }

    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    foreach ($item in $items) {
        $targetPath = Join-Path $Destination $item.name
        switch ($item.type) {
            'file' { Save-GitHubFile -Url $item.url -Destination $targetPath -Token $Token }
            'symlink' { Save-GitHubFile -Url $item.url -Destination $targetPath -Token $Token }
            'dir' { Get-GitHubFolder -Owner $Owner -Repo $Repo -Path $item.path -Destination $targetPath -Token $Token -Ref $Ref }
            default { Write-Verbose "Skipping unsupported item type: $($item.type) at $($item.path)" }
        }
    }
}

# Download example env file if missing (frictionless)
function Download-Example {
    param(
        [string]$ExampleName,
        [string]$TargetExample
    )
    $rawUrl = "https://raw.githubusercontent.com/$owner/$repo/$defaultRef/$githubPath/$ExampleName"
    if (-not (Test-Path $TargetExample)) {
        Write-Host "Downloading $ExampleName from GitHub..."
        Invoke-WebRequest -Uri $rawUrl -OutFile $TargetExample -UseBasicParsing
    }
}

# Generate random password/key
function Generate-Random {
    param([int]$Length = 16)
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes)
    return [Convert]::ToBase64String($bytes) -replace '[/+=]', '' | Select-Object -First $Length
}

# Prompt for a secret with description and optional default
function Prompt-Secret {
    param(
        [string]$VarName,
        [string]$Description,
        [string]$DefaultValue,
        [bool]$IsRequired
    )
    
    Write-Host ""
    Write-Host "📋 $VarName`: $Description" -ForegroundColor Cyan
    
    if ($DefaultValue) {
        if ($DefaultValue.StartsWith("AUTO_GENERATE:")) {
            $genLength = [int]($DefaultValue.Split(':')[1])
            $DefaultValue = Generate-Random -Length $genLength
            Write-Host "   Auto-generated: $DefaultValue" -ForegroundColor Green
        }
        Write-Host "   Default: $DefaultValue" -ForegroundColor Yellow
    }
    
    if ($IsRequired) {
        Write-Host "   (REQUIRED)" -ForegroundColor Red
    } else {
        Write-Host "   (OPTIONAL - press Enter to skip)" -ForegroundColor Gray
    }
    
    $value = Read-Host "   Enter value"
    
    if (-not $value) {
        if ($DefaultValue) {
            $value = $DefaultValue
        } elseif ($IsRequired) {
            Write-Host "   ❌ This field is required. Please enter a value." -ForegroundColor Red
            return Prompt-Secret -VarName $VarName -Description $Description -DefaultValue $DefaultValue -IsRequired $IsRequired
        }
    }
    
    # Validate based on var type
    switch -Regex ($VarName) {
        "DOCKER_PAT" {
            if ($value -and $value -notmatch "^(ghp_|dckr_)") {
                Write-Host "   ⚠️  Warning: Docker PAT should start with 'ghp_' or 'dckr_'" -ForegroundColor Yellow
            }
        }
        ".*_PASSWORD" {
            if ($value -and $value.Length -lt 8) {
                Write-Host "   ⚠️  Warning: Password should be at least 8 characters" -ForegroundColor Yellow
            }
        }
        "OPENAI_API_KEY" {
            if ($value -and $value -notmatch "^sk-") {
                Write-Host "   ⚠️  Warning: OpenAI API key should start with 'sk-'" -ForegroundColor Yellow
            }
        }
        "FERNET_KEY_PATTERN" {
            if ($value -and $value.Length -ne 44) {
                Write-Host "   ❌ Error: Fernet key must be exactly 44 base64 characters" -ForegroundColor Red
                Write-Host "   Current length: $($value.Length)" -ForegroundColor Gray
                Write-Host "   Auto-generating a valid key..." -ForegroundColor Yellow
                $value = Generate-Random -Length 32
                Write-Host "   Generated: $value" -ForegroundColor Green
            }
        }
    }
    
    return $value
}

# Interactive setup for all customer secrets
function Prompt-ForSecrets {
    param([string]$SensitiveFile)
    
    Write-Host ""
    Write-Host "🔐 MimIR Setup: Customer Secrets Configuration" -ForegroundColor Magenta
    Write-Host "================================================" -ForegroundColor Magenta
    Write-Host "We'll walk through each required secret. You can:"
    Write-Host "• Press Enter to use auto-generated values (for passwords)"
    Write-Host "• Enter your own values (for API keys provided to you)"
    Write-Host "• Press Enter to skip optional items"
    Write-Host ""
    
    # Start building the env file
    @"
# .env.sensitive: Customer Secrets (Auto-generated by installer)
# Do NOT commit this file. Generated on $(Get-Date)

"@ | Out-File -FilePath $SensitiveFile -Encoding UTF8
    
    # Docker Authentication (Required)
    Write-Host "Step 1/8: Docker Authentication" -ForegroundColor Blue
    $dockerPat = Prompt-Secret -VarName "DOCKER_PAT" -Description "Docker Personal Access Token (provided to you)" -DefaultValue "" -IsRequired $true
    "DOCKER_PAT=`"$dockerPat`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8

    # Database Passwords (Required - Auto-generate)
    Write-Host "Step 2/8: Database Passwords" -ForegroundColor Blue
    $clickhousePass = Prompt-Secret -VarName "CLICKHOUSE_PASSWORD" -Description "ClickHouse database password" -DefaultValue "AUTO_GENERATE:16" -IsRequired $true
    "CLICKHOUSE_PASSWORD=`"$clickhousePass`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8
    $clickhouseLlmPass = Prompt-Secret -VarName "CLICKHOUSE_PASSWORD_LLM" -Description "ClickHouse LLM user password (press Enter to use main password)" -DefaultValue $clickhousePass -IsRequired $false
    if ($clickhouseLlmPass -and $clickhouseLlmPass -ne $clickhousePass) {
        "CLICKHOUSE_PASSWORD_LLM=`"$clickhouseLlmPass`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8
    }
    $redisPass = Prompt-Secret -VarName "REDIS_PASSWORD" -Description "Redis cache password" -DefaultValue "AUTO_GENERATE:16" -IsRequired $true
    "REDIS_PASSWORD=`"$redisPass`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8
    
    # AI/ML API Keys (Required)
    Write-Host "Step 3/8: AI/ML Service Keys" -ForegroundColor Blue
    $openaiKey = Prompt-Secret -VarName "OPENAI_API_KEY" -Description "OpenAI API key (starts with sk-)" -DefaultValue "" -IsRequired $true
    "OPENAI_API_KEY=`"$openaiKey`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8
    $voyageKey = Prompt-Secret -VarName "VOYAGE_API_KEY" -Description "Voyage AI embeddings key (uses local model if not provided)" -DefaultValue "" -IsRequired $false
    if ($voyageKey) { "VOYAGE_API_KEY=`"$voyageKey`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8 }
    $unstructuredKey = Prompt-Secret -VarName "UNSTRUCTURED_API_KEY" -Description "Unstructured.io document processing key" -DefaultValue "" -IsRequired $true
    "UNSTRUCTURED_API_KEY=`"$unstructuredKey`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8
    
    # Application Secrets (Required - Auto-generate)
    Write-Host "Step 4/8: Application Security Keys" -ForegroundColor Blue
    $secretKey = Prompt-Secret -VarName "SECRET_KEY" -Description "Main application secret key" -DefaultValue "AUTO_GENERATE:32" -IsRequired $true
    "SECRET_KEY=`"$secretKey`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8
    $tokenKey = Prompt-Secret -VarName "TOKEN_SECRET_KEY" -Description "Token signing key" -DefaultValue "AUTO_GENERATE:24" -IsRequired $true
    "TOKEN_SECRET_KEY=`"$tokenKey`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8
    $fernetKey = Prompt-Secret -VarName "FERNET_KEY_PATTERN" -Description "Encryption key (Fernet)" -DefaultValue "AUTO_GENERATE:32" -IsRequired $true
    "FERNET_KEY_PATTERN=`"$fernetKey`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8
    
    # Optional API Keys
    Write-Host "Step 5/8: Optional API Keys (press Enter to skip)" -ForegroundColor Blue
    $tavilyKey = Prompt-Secret -VarName "TAVILY_API_KEY" -Description "Tavily API key (for web search)" -DefaultValue "" -IsRequired $false
    if ($tavilyKey) { "TAVILY_API_KEY=`"$tavilyKey`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8 }
    $firecrawlKey = Prompt-Secret -VarName "FIRECRAWL_API_KEY" -Description "FireCrawl API key (for web scraping)" -DefaultValue "" -IsRequired $false
    if ($firecrawlKey) { "FIRECRAWL_API_KEY=`"$firecrawlKey`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8 }
    $azureKey = Prompt-Secret -VarName "AZURE_OPENAI_API_KEY" -Description "Azure OpenAI key (if using Azure)" -DefaultValue "" -IsRequired $false
    if ($azureKey) { "AZURE_OPENAI_API_KEY=`"$azureKey`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8 }
    $azureBase = Prompt-Secret -VarName "AZURE_OPENAI_API_BASE" -Description "Azure OpenAI endpoint (if using Azure)" -DefaultValue "" -IsRequired $false
    if ($azureBase) { "AZURE_OPENAI_API_BASE=`"$azureBase`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8 }
    $hfToken = Prompt-Secret -VarName "HF_TOKEN" -Description "HuggingFace token (for faster model downloads)" -DefaultValue "" -IsRequired $false
    if ($hfToken) { "HF_TOKEN=`"$hfToken`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8 }
    $mapsKey = Prompt-Secret -VarName "GOOGLE_MAPS_API_KEY" -Description "Google Maps API key (if using location features)" -DefaultValue "" -IsRequired $false
    if ($mapsKey) { "GOOGLE_MAPS_API_KEY=`"$mapsKey`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8 }
    
    # On-Prem Specific (Required)
    Write-Host "Step 6/8: On-Prem Configuration (Required)" -ForegroundColor Blue
    $onpremWriteKey = Prompt-Secret -VarName "ONPREM_WRITE_KEY" -Description "On-premises write key (provided for your setup)" -DefaultValue "" -IsRequired $true
    "ONPREM_WRITE_KEY=`"$onpremWriteKey`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8
    $onpremOrg = Prompt-Secret -VarName "ONPREM_ORGANIZATION" -Description "Organization name" -DefaultValue "" -IsRequired $true
    "ONPREM_ORGANIZATION=`"$onpremOrg`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8
    $onpremGid = Prompt-Secret -VarName "ONPREM_ORGANIZATION_GID" -Description "Organization group ID" -DefaultValue "" -IsRequired $true
    "ONPREM_ORGANIZATION_GID=`"$onpremGid`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8
    $onpremPartition = Prompt-Secret -VarName "ONPREM_PARTITION" -Description "Data partition identifier" -DefaultValue "" -IsRequired $true
    "ONPREM_PARTITION=`"$onpremPartition`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8

    # SFTP Integration (Optional)
    Write-Host "Step 7/8: SFTP Integration (Optional - press Enter to skip)" -ForegroundColor Blue
    $sftpUser = Prompt-Secret -VarName "SFTP_USERNAME" -Description "SFTP username for file uploads (if using SFTP)" -DefaultValue "" -IsRequired $false
    if ($sftpUser) {
        "SFTP_USERNAME=`"$sftpUser`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8
        $sftpPass = Prompt-Secret -VarName "SFTP_PASSWORD" -Description "SFTP password" -DefaultValue "" -IsRequired $false
        if ($sftpPass) { "SFTP_PASSWORD=`"$sftpPass`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8 }
    }

    # OIDC/SSO (Optional)
    Write-Host "Step 8/8: Single Sign-On (Optional - press Enter to skip)" -ForegroundColor Blue
    $oidcUrl = Prompt-Secret -VarName "OIDC_ISSUER_URL" -Description "OIDC provider URL (e.g., https://your-auth0.auth0.com)" -DefaultValue "" -IsRequired $false
    if ($oidcUrl) { 
        "OIDC_ISSUER_URL=`"$oidcUrl`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8 
        $oidcId = Prompt-Secret -VarName "OIDC_CLIENT_ID" -Description "OIDC client ID" -DefaultValue "" -IsRequired $false
        if ($oidcId) { "OIDC_CLIENT_ID=`"$oidcId`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8 }
        $oidcSecret = Prompt-Secret -VarName "OIDC_CLIENT_SECRET" -Description "OIDC client secret" -DefaultValue "" -IsRequired $false
        if ($oidcSecret) { "OIDC_CLIENT_SECRET=`"$oidcSecret`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8 }
        $cookieSecret = Prompt-Secret -VarName "OAUTH2_PROXY_COOKIE_SECRET" -Description "OAuth2 cookie secret" -DefaultValue "AUTO_GENERATE:32" -IsRequired $false
        if ($cookieSecret) { "OAUTH2_PROXY_COOKIE_SECRET=`"$cookieSecret`"" | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8 }
    }
    
    # Add fixed values
    @"

# Fixed values (do not change)
DOCKER_REGISTRY="docker.io"
DOCKER_USERNAME="quicklookup"
CLICKHOUSE_USER="default"
"@ | Out-File -FilePath $SensitiveFile -Append -Encoding UTF8

    Write-Host ""
    Write-Host "✅ Secrets configuration complete! Saved to $SensitiveFile" -ForegroundColor Green
    Write-Host ""

    # TLS Configuration Guidance
    Write-Host "🔒 TLS/SSL Configuration (Optional)" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "By default, MimIR runs on HTTP (http://localhost)."
    Write-Host "For production deployments, enable HTTPS:"
    Write-Host ""
    Write-Host "1. Generate or obtain TLS certificates:" -ForegroundColor Yellow
    Write-Host "   # PowerShell (self-signed for testing):" -ForegroundColor Gray
    Write-Host "   New-SelfSignedCertificate -DnsName 'your-domain.com' -CertStoreLocation 'Cert:\CurrentUser\My'" -ForegroundColor Gray
    Write-Host "   # Or use OpenSSL:" -ForegroundColor Gray
    Write-Host "   mkdir .local\certs" -ForegroundColor Gray
    Write-Host "   openssl req -x509 -newkey rsa:2048 -nodes -keyout .local\certs\privkey.pem -out .local\certs\fullchain.pem -days 365 -subj '/CN=your-domain.com'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Edit .env.non-sensitive:" -ForegroundColor Yellow
    Write-Host "   TLS_ENABLED=`"true`"" -ForegroundColor Gray
    Write-Host "   PUBLIC_BASE_URL=`"https://your-domain.com`"" -ForegroundColor Gray
    Write-Host "   TLS_CERTS_DIR=`".local/certs`"" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Restart containers:" -ForegroundColor Yellow
    Write-Host "   cd .local && docker compose down && docker compose up -d" -ForegroundColor Gray
    Write-Host ""
}

# Setup env files interactively/frictionless (cross-platform compatible)
function Setup-EnvFiles {
    param(
        [string]$TargetDir
    )
    # Create env files in target directory for better organization
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }
    $targetAbs = (Resolve-Path $TargetDir).ProviderPath
    $nonSensitive = Join-Path $targetAbs '.env.non-sensitive'
    $sensitive = Join-Path $targetAbs '.env.sensitive'
    $exampleNon = Join-Path $targetAbs '.env.example.non-sensitive'
    $exampleSensitive = Join-Path $targetAbs '.env.example.sensitive'

    # Download non-sensitive example and copy (ready with defaults)
    Download-Example "$githubPath/.env.example.non-sensitive" $exampleNon
    if (-not (Test-Path $nonSensitive)) {
        Copy-Item $exampleNon $nonSensitive
        Write-Host "✅ Created $nonSensitive with safe defaults."
    }

    # For sensitive: Interactive prompts instead of editor
    if (-not (Test-Path $sensitive) -and -not $NoInteractive) {
        Prompt-ForSecrets $sensitive
    } elseif (-not (Test-Path $sensitive)) {
        Write-Host "Run without -NoInteractive for guided setup, or create $sensitive manually." -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✅ Using existing $sensitive"
    }

    # Set $envFilesResolved to these target directory files
    $script:envFilesResolved = @()
    $script:envFilesResolved += $nonSensitive
    $script:envFilesResolved += $sensitive
}

# Parse comma-separated EnvFile into array (user-provided)
$envFilesResolved = @()
if ($EnvFile) {
    $envFileList = $EnvFile -split ','
    foreach ($file in $envFileList) {
        $resolved = (Resolve-Path -LiteralPath $file -ErrorAction Stop).ProviderPath
        if (Test-Path $resolved) {
            $envFilesResolved += $resolved
        } else {
            throw "Environment file not found: $file"
        }
    }
} else {
    # Frictionless: Auto-setup env files in current dir if not provided
    Setup-EnvFiles $TargetDirectory
}

$envFilesForAuth = $envFilesResolved  # All for compose; last for auth/creds

try {
    $githubToken = $env:GITHUB_TOKEN
    $githubRefFinal = $githubRef
    foreach ($envFile in $envFilesResolved) {
        $tokenFromFile = Get-EnvValue -File $envFile -Key 'GITHUB_TOKEN'
        if ($tokenFromFile) { $githubToken = $tokenFromFile }
        $refFromFile = Get-EnvValue -File $envFile -Key 'GITHUB_REF'
        if ($refFromFile) { $githubRefFinal = $refFromFile }
    }
    if (-not $githubRefFinal) { $githubRefFinal = $defaultRef }

    Write-Host 'Downloading stack via GitHub API...'
    Get-GitHubFolder -Owner $owner -Repo $repo -Path $githubPath -Destination $downloadRoot -Token $githubToken -Ref $githubRefFinal

    $stackSource = $downloadRoot

    if (-not (Test-Path $TargetDirectory)) {
        $null = New-Item -ItemType Directory -Path $TargetDirectory -Force
    }
    $targetRoot = (Resolve-Path -LiteralPath $TargetDirectory).ProviderPath
    $stackTarget = Join-Path $targetRoot '.local'

    if (Test-Path $stackTarget) {
        Remove-Item -LiteralPath $stackTarget -Recurse -Force
    }
    $null = New-Item -ItemType Directory -Path $stackTarget

    Get-ChildItem -LiteralPath $stackSource -Force | ForEach-Object {
        $destination = Join-Path $stackTarget $_.Name
        if ($_.PSIsContainer) {
            Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force
        } else {
            Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
        }
    }

    Write-Host "Stack files ready in $stackTarget"

    $composeArgs = @()
    $envFileForAuth = $null

    if ($envFilesResolved.Count -gt 0) {
        foreach ($env in $envFilesResolved) {
            $composeArgs += '--env-file', $env  # Absolute paths ensure compose finds them
        }
        $composeArgs += '-f', 'docker-compose.mimir.onprem.yml', 'up', '-d'
        $envFileForAuth = $envFilesResolved[-1]  # Last for auth
    } else {
        $localEnv = Join-Path $stackTarget '.env'
        if (Test-Path $localEnv) {
            $composeArgs = @('--env-file', $localEnv)
            $envFileForAuth = $localEnv
        } else {
            if (Test-Path (Join-Path $stackTarget '.env.example.sensitive') -or Test-Path (Join-Path $stackTarget '.env.example.non-sensitive')) {
                Write-Warning "No env files present. Copy and fill .env.example.* to .env.non-sensitive and .env.sensitive before running docker compose."
            } else {
                Write-Warning "No environment files provided. Setup .env.non-sensitive and .env.sensitive."
            }
            $NoUp = $true
        }
    }

    if ($NoUp) {
        Write-Host 'Skipping docker compose up.'
        return
    }

    if (-not (Get-Command 'docker' -ErrorAction SilentlyContinue)) {
        throw '❌ Docker CLI is required but not found. Please install Docker Desktop from https://docker.com'
    }

    # Check if Docker daemon is running
    Write-Host "🔍 Checking Docker daemon..." -ForegroundColor Yellow
    try {
        docker info *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker daemon check failed"
        }
    } catch {
        Write-Host "❌ Docker daemon is not running. Please start Docker Desktop and try again." -ForegroundColor Red
        Write-Host "   On Windows: Start Docker Desktop from Start Menu" -ForegroundColor Gray
        Write-Host "   Test with: docker run hello-world" -ForegroundColor Gray
        throw "Docker daemon not available"
    }
    Write-Host "✅ Docker daemon is running" -ForegroundColor Green

    # Check available disk space
    Write-Host "🔍 Checking disk space..." -ForegroundColor Yellow
    try {
        $drive = (Get-Item $targetRoot).PSDrive
        $freeSpaceGB = [math]::Round($drive.Free / 1GB, 1)
        if ($freeSpaceGB -lt 30) {
            Write-Host "⚠️  Warning: Only ${freeSpaceGB}GB disk space available." -ForegroundColor Yellow
            Write-Host "   Recommended: 50GB+ for AI models and data storage." -ForegroundColor Gray
            Write-Host "   Required space breakdown:" -ForegroundColor Gray
            Write-Host "     - Docker images: ~8GB" -ForegroundColor Gray
            Write-Host "     - AI models (HuggingFace): ~10GB" -ForegroundColor Gray
            Write-Host "     - Database storage: ~5-50GB (usage-dependent)" -ForegroundColor Gray
            $response = Read-Host "   Continue anyway? (y/N)"
            if ($response -notmatch '^[Yy]$') {
                throw "Installation cancelled. Please free up disk space and try again."
            }
        } else {
            Write-Host "✅ Sufficient disk space available (${freeSpaceGB}GB+)" -ForegroundColor Green
        }
    } catch {
        Write-Verbose "Could not check disk space: $_"
    }

    # Test Docker functionality
    Write-Host "🔍 Testing Docker functionality..." -ForegroundColor Yellow
    try {
        docker run --rm hello-world *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker test failed"
        }
    } catch {
        Write-Host "❌ Docker test failed. Please check Docker installation and permissions." -ForegroundColor Red
        Write-Host "   Try running: docker run hello-world" -ForegroundColor Gray
        Write-Host "   If it fails, restart Docker Desktop or check permissions." -ForegroundColor Gray
        throw "Docker functionality test failed"
    }
    Write-Host "✅ Docker is working correctly" -ForegroundColor Green

    # Check Docker memory allocation
    Write-Host "🔍 Checking Docker memory allocation..." -ForegroundColor Yellow
    try {
        $dockerMemBytes = docker info --format '{{.MemTotal}}' 2>$null
        if ($dockerMemBytes -and $LASTEXITCODE -eq 0) {
            $dockerMemGB = [math]::Round([long]$dockerMemBytes / 1GB, 1)
            if ($dockerMemGB -lt 12) {
                Write-Host "⚠️  Warning: Docker has only ${dockerMemGB}GB RAM allocated." -ForegroundColor Yellow
                Write-Host "   Recommended: 16GB+ for AI services (embeddings, anonymization)." -ForegroundColor Gray
                Write-Host "   Current requirements:" -ForegroundColor Gray
                Write-Host "     - cxs-embeddings: 6-12GB" -ForegroundColor Gray
                Write-Host "     - cxs-anonymization: 4-8GB" -ForegroundColor Gray
                Write-Host "     - Other services: ~4GB" -ForegroundColor Gray
                Write-Host "   Containers may crash with OOM (Out of Memory) errors." -ForegroundColor Gray
                Write-Host "   To increase: Docker Desktop > Settings > Resources > Memory" -ForegroundColor Gray
                $response = Read-Host "   Continue anyway? (y/N)"
                if ($response -notmatch '^[Yy]$') {
                    throw "Installation cancelled. Please increase Docker memory and try again."
                }
            } else {
                Write-Host "✅ Sufficient Docker memory allocated (${dockerMemGB}GB+)" -ForegroundColor Green
            }
        } else {
            Write-Host "⚠️  Could not determine Docker memory allocation. Proceeding..." -ForegroundColor Yellow
        }
    } catch {
        Write-Verbose "Docker memory check failed: $_"
    }

    if (-not $envFileForAuth) {
        throw 'Docker credentials must be supplied in an env file (last in -EnvFile list or .env).'
    }

    $dockerRegistry = Get-EnvValue -File $envFileForAuth -Key 'DOCKER_REGISTRY'
    if (-not $dockerRegistry) { $dockerRegistry = 'docker.io' }
    $dockerUsername = Get-EnvValue -File $envFileForAuth -Key 'DOCKER_USERNAME'
    $dockerPat = Get-EnvValue -File $envFileForAuth -Key 'DOCKER_PAT'

    if (-not $dockerUsername -or -not $dockerPat) {
        throw "DOCKER_USERNAME and DOCKER_PAT must be set in the last env file ($envFileForAuth)"
    }

    # Validate key sensitive vars before up (best practice)
    $clickhousePass = Get-EnvValue -File $envFileForAuth -Key 'CLICKHOUSE_PASSWORD'
    $redisPass = Get-EnvValue -File $envFileForAuth -Key 'REDIS_PASSWORD'
    $openaiKey = Get-EnvValue -File $envFileForAuth -Key 'OPENAI_API_KEY'
    $unstructuredKey = Get-EnvValue -File $envFileForAuth -Key 'UNSTRUCTURED_API_KEY'
    $secretKey = Get-EnvValue -File $envFileForAuth -Key 'SECRET_KEY'
    $onpremWriteKey = Get-EnvValue -File $envFileForAuth -Key 'ONPREM_WRITE_KEY'
    $onpremOrg = Get-EnvValue -File $envFileForAuth -Key 'ONPREM_ORGANIZATION'
    $onpremGid = Get-EnvValue -File $envFileForAuth -Key 'ONPREM_ORGANIZATION_GID'
    $onpremPartition = Get-EnvValue -File $envFileForAuth -Key 'ONPREM_PARTITION'

    if (-not $clickhousePass -or -not $redisPass -or -not $openaiKey -or -not $unstructuredKey -or -not $secretKey -or -not $onpremWriteKey -or -not $onpremOrg -or -not $onpremGid -or -not $onpremPartition) {
        throw "Required secrets missing in last env file ($envFileForAuth): CLICKHOUSE_PASSWORD, REDIS_PASSWORD, OPENAI_API_KEY, UNSTRUCTURED_API_KEY, SECRET_KEY, ONPREM_WRITE_KEY, ONPREM_ORGANIZATION, ONPREM_ORGANIZATION_GID, ONPREM_PARTITION. Fill .env.sensitive and rerun."
    }

    Write-Host "Logging into Docker registry $dockerRegistry..."
    Invoke-DockerLogin -Registry $dockerRegistry -Username $dockerUsername -Token $dockerPat

    $useComposePlugin = $false
    try {
        docker compose version *> $null
        if ($LASTEXITCODE -eq 0) {
            $useComposePlugin = $true
        }
    } catch {
        $useComposePlugin = $false
    }

    if (-not $useComposePlugin) {
        if (-not (Get-Command 'docker-compose' -ErrorAction SilentlyContinue)) {
            throw 'Docker Compose is not available.'
        }
    }

    Push-Location $stackTarget
    try {
        Write-Host 'Running docker compose up...'
        if ($useComposePlugin) {
            docker compose @composeArgs
        } else {
            docker-compose @composeArgs
        }
    } finally {
        Pop-Location
    }

    Write-Host ''
    Write-Host '🎉 Installation complete!' -ForegroundColor Green
    Write-Host ''

    # Post-install health check
    Write-Host '⏳ Waiting for services to start (this may take 5-10 minutes for AI model downloads)...' -ForegroundColor Yellow
    Start-Sleep -Seconds 30

    Push-Location $stackTarget
    try {
        Write-Host 'Checking service status...'
        $healthy = 0
        $unhealthy = 0
        $starting = 0

        if ($useComposePlugin) {
            $psOutput = docker compose ps 2>$null
        } else {
            $psOutput = docker-compose ps 2>$null
        }

        if ($psOutput) {
            foreach ($line in $psOutput) {
                if ($line -match '\(healthy\)') { $healthy++ }
                elseif ($line -match '\(unhealthy\)') { $unhealthy++ }
                elseif ($line -match '\(starting\)') { $starting++ }
            }
        }

        Write-Host ''
        if ($healthy -gt 0) {
            Write-Host "✅ $healthy services healthy" -ForegroundColor Green
        }
        if ($starting -gt 0) {
            Write-Host "⏳ $starting services still starting (check again in a few minutes)" -ForegroundColor Yellow
        }
        if ($unhealthy -gt 0) {
            Write-Host "⚠️  $unhealthy services unhealthy" -ForegroundColor Yellow
            Write-Host "   Check logs: cd $stackTarget && docker compose logs -f" -ForegroundColor Gray
        }
    } finally {
        Pop-Location
    }

    Write-Host ''
    Write-Host '🌐 Access your MimIR setup at: http://localhost' -ForegroundColor Cyan
    Write-Host "📊 Check status: cd $stackTarget && docker compose ps" -ForegroundColor Gray
    Write-Host "📝 View logs: cd $stackTarget && docker compose logs -f [service-name]" -ForegroundColor Gray
    Write-Host ''
    Write-Host '⚠️  Note: First startup may take 5-10 minutes as AI models download (~10GB)' -ForegroundColor Yellow
}
finally {
    Cleanup
}
