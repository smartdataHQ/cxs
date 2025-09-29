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

# Setup env files interactively/frictionless (cross-platform compatible)
function Setup-EnvFiles {
    param(
        [string]$TargetDir
    )
    $nonSensitive = '.env.non-sensitive'
    $sensitive = '.env.sensitive'
    $exampleNon = "$githubPath/.env.example.non-sensitive"
    $exampleSensitive = "$githubPath/.env.example.sensitive"

    # Download examples if missing
    Download-Example $exampleNon $nonSensitive
    Download-Example $exampleSensitive $sensitive

    # Auto-copy non-sensitive (ready with defaults)
    if (-not (Test-Path $nonSensitive)) {
        Copy-Item $nonSensitive $nonSensitive  # Already downloaded
        Write-Host "Created $nonSensitive with defaults. Edit if needed (e.g., ports)."
    }

    # For sensitive: Copy keys-only, prompt to edit if not interactive
    if (-not (Test-Path $sensitive)) {
        Copy-Item $sensitive $sensitive  # Already downloaded
        Write-Host "Created $sensitive (keys-only template)."
        if (-not $NoInteractive) {
            Write-Host "Opening Notepad for $sensitive. Fill secrets (e.g., DOCKER_PAT), save, then press Enter to continue."
            notepad $sensitive
            $null = Read-Host "After editing $sensitive, press Enter to continue"
        } else {
            Write-Host "Run without -NoInteractive, but fill $sensitive manually before rerun."
            exit 1
        }
    }

    # Set $envFilesResolved to these local files
    $envFilesResolved = @()
    $envFilesResolved += (Resolve-Path $nonSensitive).ProviderPath
    $envFilesResolved += (Resolve-Path $sensitive).ProviderPath
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

    $composeArgs = @('-f', 'docker-compose.mimir.onprem.yml', 'up', '-d')
    $envFileForAuth = $null

    if ($envFilesResolved.Count -gt 0) {
        $composeArgs = @()
        foreach ($env in $envFilesResolved) {
            $composeArgs += '--env-file', $env  # Absolute paths ensure compose finds them
        }
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
        throw 'Docker CLI is required.'
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
    $voyageKey = Get-EnvValue -File $envFileForAuth -Key 'VOYAGE_API_KEY'
    $unstructuredKey = Get-EnvValue -File $envFileForAuth -Key 'UNSTRUCTURED_API_KEY'
    $secretKey = Get-EnvValue -File $envFileForAuth -Key 'SECRET_KEY'

    if (-not $clickhousePass -or -not $redisPass -or -not $openaiKey -or -not $voyageKey -or -not $unstructuredKey -or -not $secretKey) {
        throw "Required secrets missing in last env file ($envFileForAuth): CLICKHOUSE_PASSWORD, REDIS_PASSWORD, OPENAI_API_KEY, VOYAGE_API_KEY, UNSTRUCTURED_API_KEY, SECRET_KEY. Fill .env.sensitive and rerun."
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

    Write-Host 'Installation complete. Verify with "docker compose ps" from '$stackTarget'.'
}
finally {
    Cleanup
}
