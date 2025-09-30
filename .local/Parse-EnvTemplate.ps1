function Parse-EnvTemplate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TemplateFile,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Object', 'Json')]
        [string]$OutputFormat = 'Object'
    )

    if (-not (Test-Path $TemplateFile)) {
        throw "Template file not found: $TemplateFile"
    }

    $prompts = @()
    $currentStep = ""
    $currentDepends = ""
    $lines = Get-Content $TemplateFile

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Check for step headers
        if ($line -match '^#\s*Step\s+(\d+):\s*(.+)$') {
            $currentStep = $matches[1]
            $currentDepends = ""
            continue
        }

        # Check for @depends directive
        if ($line -match '^#\s*@depends:(.+)$') {
            $currentDepends = $matches[1]
            continue
        }

        # Check for @prompt directive
        if ($line -match '^#\s*@prompt:(.+)$') {
            $directive = $matches[1]
            $parts = $directive -split '\|'

            if ($parts.Count -lt 5) {
                Write-Warning "Invalid @prompt directive: $line"
                continue
            }

            $step = $parts[0].Trim()
            $required = $parts[1].Trim() -eq 'true'
            $type = $parts[2].Trim()
            $description = $parts[3].Trim()
            $default = $parts[4].Trim()

            # Find next variable name
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                $nextLine = $lines[$j]
                if ($nextLine -match '^([A-Z_]+)=') {
                    $varName = $matches[1]

                    # Use currentStep if step is "auto"
                    if ($step -eq 'auto') {
                        $step = $currentStep
                    }

                    $prompt = [PSCustomObject]@{
                        Variable    = $varName
                        Step        = [int]$step
                        Required    = $required
                        Type        = $type
                        Description = $description
                        Default     = $default
                        Depends     = $currentDepends
                    }

                    $prompts += $prompt
                    $currentDepends = ""
                    break
                }
            }
        }
    }

    if ($OutputFormat -eq 'Json') {
        return $prompts | ConvertTo-Json
    } else {
        return $prompts
    }
}

function Prompt-SecretFromMetadata {
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Metadata,

        [Parameter(Mandatory=$true)]
        [string]$OutputFile
    )

    $varName = $Metadata.Variable
    $description = $Metadata.Description
    $type = $Metadata.Type
    $required = $Metadata.Required
    $default = $Metadata.Default

    # Convert type to default value
    switch ($type) {
        'auto-generate-16' { $default = 'AUTO_GENERATE:16' }
        'auto-generate-24' { $default = 'AUTO_GENERATE:24' }
        'auto-generate-32' { $default = 'AUTO_GENERATE:32' }
        'auto-generate-44' { $default = 'AUTO_GENERATE:32' }
    }

    # Call existing Prompt-Secret function (would need to be imported)
    # This is just a demo showing the structure
    Write-Host ""
    Write-Host "📋 $varName`: $description" -ForegroundColor Cyan

    if ($default) {
        if ($default.StartsWith('AUTO_GENERATE:')) {
            $genLength = [int]($default.Split(':')[1])
            $default = Generate-Random -Length $genLength
            Write-Host "   Auto-generated: $default" -ForegroundColor Green
        }
        Write-Host "   Default: $default" -ForegroundColor Yellow
    }

    if ($required) {
        Write-Host "   (REQUIRED)" -ForegroundColor Red
    } else {
        Write-Host "   (OPTIONAL - press Enter to skip)" -ForegroundColor Gray
    }

    $value = Read-Host "   Enter value"

    if (-not $value -and $default) {
        $value = $default
    } elseif (-not $value -and $required) {
        Write-Host "   ❌ This field is required." -ForegroundColor Red
        return Prompt-SecretFromMetadata -Metadata $Metadata -OutputFile $OutputFile
    }

    # Write to output file
    if ($value) {
        "$varName=`"$value`"" | Out-File -FilePath $OutputFile -Append -Encoding UTF8
    }

    return $value
}

# Example usage
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "=== Parsing .env.example.sensitive ===" -ForegroundColor Cyan
    Write-Host ""

    $prompts = Parse-EnvTemplate -TemplateFile ".env.example.sensitive"

    # Group by step
    $promptsByStep = $prompts | Group-Object -Property Step | Sort-Object Name

    foreach ($group in $promptsByStep) {
        Write-Host "Step $($group.Name):" -ForegroundColor Yellow
        foreach ($prompt in $group.Group) {
            Write-Host "  - $($prompt.Variable): $($prompt.Description)" -ForegroundColor Gray
            Write-Host "    Type: $($prompt.Type), Required: $($prompt.Required)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}