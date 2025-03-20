# PowerShell equivalent of the Bash script
#Script to automate 95% of the steps in creating a working Integration Suite.
#Script is to be run with no subaccounts or at least none that has an entitlement to 
#the integration suite as there is only one allowed per global account.
#Created by Rodolfo Rodrigues.

# Color definitions
$ESC = [char]27
$RESET = "$ESC[0m"
$RED = "$ESC[31m"
$GREEN = "$ESC[32m"
$YELLOW = "$ESC[33m"
$BLUE = "$ESC[34m"
$MAGENTA = "$ESC[35m"
$CYAN = "$ESC[36m"
$WHITE = "$ESC[37m"
$BOLD = "$ESC[1m"
$BOLD_RED = "$ESC[1;31m"
$BOLD_GREEN = "$ESC[1;32m"
$BOLD_YELLOW = "$ESC[1;33m"
$BOLD_BLUE = "$ESC[1;34m"
$BOLD_MAGENTA = "$ESC[1;35m"
$BOLD_CYAN = "$ESC[1;36m"
$BOLD_WHITE = "$ESC[1;37m"

# Function to read credentials from file
function Read-CredentialsFromFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$CredentialsFile = "credentials.txt"
    )

    Write-Host "  $($CYAN)ℹ Reading credentials file...$($RESET)"
    
    if (Test-Path $CredentialsFile) {
        # Read first line as userid
        $userid = Get-Content $CredentialsFile -TotalCount 1
        
        # Read second line as password
        $passw = (Get-Content $CredentialsFile -TotalCount 2)[-1]
        
        Write-Host ""
        Write-Host "  $($BOLD_GREEN)✓ Credentials loaded successfully!$($RESET)"
        
        return @{
            UserId = $userid
            Password = $passw
        }
    } else {
        Write-Host ""
        Write-Host "  $($BOLD_RED)✗ Error: $CredentialsFile file not found!$($RESET)"
        Write-Host "  $($RED)Create the file in the same folder as this script.$($RESET)"
        Write-Host "  $($RED)Put your username (email) in the first line.$($RESET)"
        Write-Host "  $($RED)Put your password in the second line.$($RESET)"
        exit 1
    }
}

# Function to start processing animation
function Start-ProcessingAnimation {
    param (
        [string]$Activity,
        [ScriptBlock]$ScriptBlock
    )
    
    $job = Start-Job -ScriptBlock $ScriptBlock
    
    $i = 0
    while ($job.State -eq "Running") {
        $spinner = @('|', '/', '-', '\')[$i % 4]
        Write-Host "`r$Activity $spinner" -NoNewline
        Start-Sleep -Milliseconds 100
        $i++
    }

    # Get the console width to clear the entire line
    $consoleWidth = $Host.UI.RawUI.WindowSize.Width
    
    # Clear the entire line
    Write-Host "`r$(' ' * $consoleWidth)" -NoNewline
    Write-Host "`r" -NoNewline
    
    # Get the job output
    $result = Receive-Job -Job $job
    Remove-Job -Job $job
    
    return $result
}

# Function to ask for confirmation
function Get-Confirmation {
    param (
        [string]$Message
    )
    
    Write-Host "$($BOLD_YELLOW)$Message$($RESET) $($BOLD)(y/n)$($RESET): " -NoNewline
    $key = [Console]::ReadKey($true).Key
    Write-Host ""
    
    return ($key -eq 'Y')
}

# Function to check command existence
function Test-CommandExists {
    param (
        [string]$Command
    )
    
    # Check if command exists in PATH
    $existsInPath = $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
    
    # Check if command exists as a file in current directory
    $existsInCurrentDir = Test-Path -Path "./$Command.exe" -PathType Leaf
    $existsInCurrentDirNoExt = Test-Path -Path "./$Command" -PathType Leaf
    
    return ($existsInPath -or $existsInCurrentDir -or $existsInCurrentDirNoExt)
}

# Function to detect OS
function Get-OSType {
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        return "Windows"
    }
    elseif ($IsMacOS) {
        return "MacOS"
    }
    elseif ($IsLinux) {
        return "Linux"
    }
    else {
        # Fallback detection for older PowerShell versions
        $uname = if (Test-CommandExists "uname") { & uname } else { "" }
        if ($uname -eq "Darwin") {
            return "MacOS"
        }
        elseif ($uname -eq "Linux") {
            return "Linux"
        }
        else {
            return "Windows" # Default assumption
        }
    }
}

# Function to install CF CLI
function Install-CF {
    $osType = Get-OSType
    $installPath = "."
    
    switch ($osType) {
        "Windows" {
            Write-Host ""
            Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing CF CLI for$($RESET) $($BOLD_WHITE)Windows$($BOLD_CYAN)...$($RESET)"
            $result = Start-ProcessingAnimation -Activity "  Downloading CF CLI for Windows" -ScriptBlock {
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/cf8-cli_8.11.0_winx64.zip" -OutFile "cf-cli.zip"
                Expand-Archive -Path "cf-cli.zip" -DestinationPath $using:installPath -Force 2>$null
                
                return @{
                    Output = $output
                    ExitCode = $LASTEXITCODE
                }
            }
            Write-Host ""
            if ($result.ExitCode -eq 0) {
                Write-Host "$($BOLD_GREEN)  ✓ CF CLI installed to current directory.$($RESET)"
            } else {
                Write-Host "$($BOLD_RED)  ✗ Failed to install CF CLI. Error: $($result.Output)$($RESET)"
                exit 1
            }
        }        
        "MacOS" {
            $cpuArch = if (Test-CommandExists "uname") { & uname -m } else { "x86_64" }
            if ($cpuArch -eq "arm64" -or $cpuArch -eq "aarch64") {
                Write-Host ""
                Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing CF CLI for$($RESET) $($BOLD_WHITE)MacOS (ARM64)$($BOLD_CYAN)...$($RESET)"
                $result = Start-ProcessingAnimation -Activity "  Downloading CF CLI for MacOS (ARM64)" -ScriptBlock {
                    & curl -L "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/cf8-cli_8.11.0_macosarm.tgz" 2>$null | tar -zx
                    
                    return @{
                        Output = $output
                        ExitCode = $LASTEXITCODE
                    }
                }
            } else {
                Write-Host ""
                Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing CF CLI for$($RESET) $($BOLD_WHITE)MacOS (x64)$($BOLD_CYAN)...$($RESET)"
                $result = Start-ProcessingAnimation -Activity "  Downloading CF CLI for MacOS (x64)" -ScriptBlock {
                    & curl -L "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/cf8-cli_8.11.0_osx.tgz" 2>$null | tar -zx
                    
                    return @{
                        Output = $output
                        ExitCode = $LASTEXITCODE
                    }
                }
            }
            Write-Host ""
            if ($result.ExitCode -eq 0) {
                Write-Host "$($BOLD_GREEN)  ✓ CF CLI installed to current directory.$($RESET)"
            } else {
                Write-Host "$($BOLD_RED)  ✗ Failed to install CF CLI. Error: $($result.Output)$($RESET)"
                exit 1
            }
        }
        "Linux" {
            Write-Host ""
            Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing CF CLI for$($RESET) $($BOLD_WHITE)Linux$($BOLD_CYAN)...$($RESET)"
            $result = Start-ProcessingAnimation -Activity "  Downloading CF CLI for Linux" -ScriptBlock {
                & curl -L "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/cf8-cli_8.11.0_linux_x86-64.tgz" 2>$null | tar -zx
                
                return @{
                    Output = $output
                    ExitCode = $LASTEXITCODE
                }
            }
            Write-Host ""
            if ($result.ExitCode -eq 0) {
                Write-Host "$($BOLD_GREEN)  ✓ CF CLI installed to current directory.$($RESET)"
            } else {
                Write-Host "$($BOLD_RED)  ✗ Failed to install CF CLI. Error: $($result.Output)$($RESET)"
                exit 1
            }
        }
    }
}

# Function to install BTP CLI
function Install-BTP {
    $osType = Get-OSType
    $installPath = "."

    switch ($osType) {
        "Windows" {
            Write-Host ""
            Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing BTP CLI for$($RESET) $($BOLD_WHITE)Windows$($BOLD_CYAN)...$($RESET)"
            $result = Start-ProcessingAnimation -Activity "  Downloading BTP CLI for Windows" -ScriptBlock {
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/btp-cli-windows-amd64-2.83.0.zip" -OutFile "btp-cli.zip"
                Expand-Archive -Path "btp-cli.zip" -DestinationPath $using:installPath -Force 2>$null
    
                return @{
                    Output = $output
                    ExitCode = $LASTEXITCODE
                }
            }
            Write-Host ""
            if ($result.ExitCode -eq 0) {
                Write-Host "$($BOLD_GREEN)  ✓ BTP CLI installed to current directory.$($RESET)"
            } else {
                Write-Host "$($BOLD_RED)  ✗ Failed to install BTP CLI. Error: $($result.Output)$($RESET)"
                exit 1
            }
        }
        "MacOS" {
            $cpuArch = if (Test-CommandExists "uname") { & uname -m } else { "x86_64" }
            if ($cpuArch -eq "arm64" -or $cpuArch -eq "aarch64") {
                Write-Host ""
                Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing BTP CLI for$($RESET) $($BOLD_WHITE)MacOS (ARM64)$($BOLD_CYAN)...$($RESET)"
                $result = Start-ProcessingAnimation -Activity "  Downloading BTP CLI for MacOS (ARM64)" -ScriptBlock {
                    & curl -L "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/btp-cli-darwin-arm64-2.83.0.tar.gz"  2>$null| tar -zx
    
                    return @{
                        Output = $output
                        ExitCode = $LASTEXITCODE
                    }
                }
            } else {
                Write-Host ""
                Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing BTP CLI for$($RESET) $($BOLD_WHITE)MacOS (x64)$($BOLD_CYAN)...$($RESET)"
                $result = Start-ProcessingAnimation -Activity "  Downloading BTP CLI for MacOS (x64)" -ScriptBlock {
                    & curl -L "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/btp-cli-darwin-amd64-2.83.0.tar.gz"  2>$null| tar -zx
    
                    return @{
                        Output = $output
                        ExitCode = $LASTEXITCODE
                    }
                }
            }
            Write-Host ""
            if ($result.ExitCode -eq 0) {
                Write-Host "$($BOLD_GREEN)  ✓ BTP CLI installed to current directory.$($RESET)"
            } else {
                Write-Host "$($BOLD_RED)  ✗ Failed to install BTP CLI. Error: $($result.Output)$($RESET)"
                exit 1
            }
        }
        "Linux" {
            $cpuArch = if (Test-CommandExists "uname") { & uname -m } else { "x86_64" }
            if ($cpuArch -eq "arm64" -or $cpuArch -eq "aarch64") {
                Write-Host ""
                Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing BTP CLI for$($RESET) $($BOLD_WHITE)Linux (ARM64)$($BOLD_CYAN)...$($RESET)"
                $result = Start-ProcessingAnimation -Activity "  Downloading BTP CLI for Linux (ARM64)" -ScriptBlock {
                    & curl -L "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/btp-cli-linux-arm64-2.83.0.tar.gz" 2>$null | tar -zx
                    
                    return @{
                        Output = $output
                        ExitCode = $LASTEXITCODE
                    }
                }
            } else {
                Write-Host ""
                Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing BTP CLI for$($RESET) $($BOLD_WHITE)Linux (x64)$($BOLD_CYAN)...$($RESET)"
                $result = Start-ProcessingAnimation -Activity "  Downloading BTP CLI for Linux (x64)" -ScriptBlock {
                    & curl -L "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/btp-cli-linux-amd64-2.83.0.tar.gz" 2>$null | tar -zx
                    
                    return @{
                        Output = $output
                        ExitCode = $LASTEXITCODE
                    }
                }
            }
            Write-Host ""
            if ($result.ExitCode -eq 0) {
                Write-Host "$($BOLD_GREEN)  ✓ BTP CLI installed to current directory.$($RESET)"
            } else {
                Write-Host "$($BOLD_RED)  ✗ Failed to install BTP CLI. Error: $($result.Output)$($RESET)"
                exit 1
            }
        }
    }
}



# Main script starts here
Write-Host ""
Write-Host "  $($BOLD_CYAN)=======================================$($RESET)"
Write-Host "  $($BOLD_CYAN)SAP Integration Suite Deployment Script$($RESET)"
Write-Host "  $($BOLD_CYAN)=======================================$($RESET)"
Write-Host ""

# Check for required commands
$requiredCommands = @("btp", "cf")
$missingCommands = @()

foreach ($cmd in $requiredCommands) {
    if (-not (Test-CommandExists $cmd)) {
        $missingCommands += $cmd
    }
}

if ($missingCommands.Count -gt 0) {
    Write-Host "$($BOLD_YELLOW)  ⚠ Warning: The following required commands are missing: $($missingCommands -join ', ')$($RESET)"
    Write-Host ""
    $installMissing = Read-Host "$($MAGENTA)  Do you want to install the missing commands?$($RESET) $($WHITE)($($RESET)$($BOLD_MAGENTA)y$($RESET)$($WHITE)/$($RESET)$($BOLD_MAGENTA)n$($RESET)$($WHITE))$($RESET)"
    
    if ($installMissing -eq "y" -or $installMissing -eq "Y") {
        foreach ($cmd in $missingCommands) {
            switch ($cmd) {
                "btp" { Install-BTP }
                "cf" { Install-CF }
            }
        }
        
        # Verify installation
        $stillMissing = @()
        foreach ($cmd in $missingCommands) {
            if (-not (Test-CommandExists $cmd)) {
                $stillMissing += $cmd
            }
        }
        
        if ($stillMissing.Count -gt 0) {
            Write-Host "$($BOLD_RED)  Error: The following commands could not be installed: $($stillMissing -join ', ')$($RESET)"
        Write-Host "$($RED)  Please install them before running this script."$($RESET)
            exit 1
        } else {
            Write-Host ""
            Write-Host "$($BOLD_GREEN)  ✓ All required commands are now available.$($RESET)"
        }
    } else {
        Write-Host ""
        Write-Host "$($BOLD_RED)  Error: Missing required commands: $($missingCommands -join ', ')$($RESET)"
        Write-Host "$($RED)  Please install them before running this script."$($RESET)
        exit 1
    }
}


#
# LOGIN TO BTP CLI & EXTRACT GLOBAL ACCOUNT INFO
#


# Log in to BTP
Write-Host ""
"  $($BOLD_YELLOW)⚠ Logging in to BTP$($RESET)"
Write-Host ""

# Reading credentials
$credential = Read-CredentialsFromFile
$userid = $credential.UserId
$passw = $credential.Password

$login_output = & ./btp login --url https://cli.btp.cloud.sap --user $userid --password $passw 2>$null

# Extract the global account subdomain from login output
$global_subdomain = $login_output | Select-String -Pattern "Current target:" -Context 0,1 | 
                    ForEach-Object { $_.Context.PostContext[0] } | 
                    Select-String -Pattern "[0-9a-zA-Z]+trial" | 
                    ForEach-Object { $_.Matches[0].Value }

Write-Host ""
# Check if login was successful
if ($LASTEXITCODE -ne 0) {
    Write-Host "  $($BOLD_RED)✗ Login failed. Exiting.$($RESET)"
    exit 1
} else {
    Write-Host "  $($BOLD_GREEN)✓ Login successful!$($RESET)"
}

# Verify the extraction
### Write-Host ""
### Write-Host "  $($CYAN)Extracted global account subdomain: $($BOLD_WHITE)$global_subdomain$($RESET)"

Write-Host ""
# Get available regions
Write-Host "  $($CYAN)ℹ Fetching available regions...$($RESET)"
$regions_output = & ./btp list accounts/available-region 2>$null

# Extract global account ID
$global_account_id = $regions_output | Select-String -Pattern "global account [a-zA-Z0-9-]+" | 
                     ForEach-Object { $_.Matches[0].Value.Split(' ')[2] } | 
                     Select-Object -First 1

Write-Host ""
# Parse regions
Write-Host "  $($BOLD_BLUE)Available regions:$($RESET)"
$regions = $regions_output | Select-String -Pattern "^\w+\s+cf-" | ForEach-Object { $_.ToString().Trim().Split()[0] }

Write-Host ""
# Display regions with numbers
for ($i = 0; $i -lt $regions.Count; $i++) {
    Write-Host "  $($BOLD_CYAN)$($i+1)) $($regions[$i])$($RESET)"
}

# Get user selection
Write-Host ""
$selection = Read-Host "  $($MAGENTA)Select a region $($RESET)($($BOLD_MAGENTA)1$($RESET)-$($BOLD_MAGENTA)$($regions.Count)$($RESET))"

# Validate selection
if (-not ($selection -match "^\d+$") -or [int]$selection -lt 1 -or [int]$selection -gt $regions.Count) {
    Write-Host "  $($BOLD_RED)✗ Invalid selection. Exiting.$($RESET)"
    exit 1
}

# Get the selected region
$selected_region = $regions[[int]$selection-1]

# Create a unique subdomain based on global account ID and timestamp
$timestamp = [int](Get-Date -UFormat %s)
$unique_subdomain = "trial-$($global_account_id.Substring(0,7))-$timestamp"

Write-Host ""
$defaultName = "Trial"
$subaccountDisplayName = Read-Host -Prompt "  $($MAGENTA)Enter subaccount display name $($RESET)[$($BOLD_MAGENTA)$defaultName$($RESET)]"

# If user just pressed Enter without typing anything, use the default value
if ([string]::IsNullOrWhiteSpace($subaccountDisplayName)) {
    $subaccountDisplayName = $defaultName
}


#
# CREATE SUBACCOUNT 
#


# Create subaccount
Write-Host ""
Write-Host "  $($CYAN)Creating subaccount...$($RESET)"

$result = Start-ProcessingAnimation -Activity "  Creating subaccount" -ScriptBlock {
    $subaccount_output = & ./btp create accounts/subaccount --display-name "$using:subaccountDisplayName" --region "$using:selected_region" --subdomain "$using:unique_subdomain" 2>$null
    
    return @{
        Output = $subaccount_output
        ExitCode = $LASTEXITCODE
    }
}

$subaccount_output = $result.Output
$createSubaccountSuccess = ($result.ExitCode -eq 0)

if (-not $createSubaccountSuccess) {
    Write-Host ""
    Write-Host "  $($BOLD_RED)Failed to create subaccount. Error: $subaccount_output$($RESET)"
    exit 1
}

# Extract the subaccount ID from the output
$subaccount_id = $subaccount_output | 
                Select-String -Pattern "subaccount id:" | 
                ForEach-Object { $_.Line -replace "subaccount id:\s*", "" }

### Write-Host ""
### Write-Host "  $($BOLD_GREEN)Subaccount created successfully with ID:$($RESET) $($BOLD_WHITE)$subaccount_id$($RESET)"

# Initialize variables
$attempt = 1
$max_attempts = 15
$subaccountReady = $false

# Write the initial message
Write-Host ""
Write-Host "  $($BOLD_CYAN)Waiting for subaccount to be ready...$($RESET)"
$initialPosition = $host.UI.RawUI.CursorPosition

while ($attempt -le $max_attempts -and -not $subaccountReady) {
    # Get subaccount status
    $subaccount_output = & ./btp get accounts/subaccount "$subaccount_id" 2>$null
    
    # Extract the state value
    $subaccount_state = $subaccount_output | 
                        Select-String -Pattern "state:\s+(\w+)" -AllMatches | 
                        Where-Object { $_.Line -notmatch "state message:" } | 
                        ForEach-Object { $_.Matches.Groups[1].Value }
    
    # Default to PENDING if no state found
    if ([string]::IsNullOrEmpty($subaccount_state)) {
        $subaccount_state = "PENDING"
    }
    
    # Return to saved position
    $host.UI.RawUI.CursorPosition = $initialPosition
    
    # Create progress bar
    $progressWidth = 15  # Width of the progress bar
    $filledWidth = [Math]::Min([Math]::Floor(($attempt / $max_attempts) * $progressWidth), $progressWidth)
    $emptyWidth = $progressWidth - $filledWidth
    
    $progressBar = "  $($BLUE)Checking state $($RESET)($($BOLD_BLUE)$attempt$($RESET)/$($BOLD_BLUE)$max_attempts$($RESET)): $($YELLOW)$subaccount_state$($RESET) [$($CYAN)$('#' * $filledWidth)$(' ' * $emptyWidth)$($RESET)]"
    
    # Write the progress bar
    Write-Host $progressBar -NoNewline
    
    # Check if ready
    if ($subaccount_state -eq "OK") {
        # Save the final progress bar state
        $finalProgressBar = $progressBar
        
        # Clear the line
        $host.UI.RawUI.CursorPosition = $initialPosition
        Write-Host (" " * 100) -NoNewline
        
        # Move to a new line and write the final status
        Write-Host ""
        Write-Host $finalProgressBar
        Write-Host ""
        Write-Host "  $($BOLD_GREEN)✓ Subaccount is ready!$($RESET)"
        $subaccountReady = $true
        break
    }
    
    # Check if max attempts reached
    if ($attempt -eq $max_attempts) {
        # Save the final progress bar state
        $finalProgressBar = $progressBar
        
        # Clear the line
        $host.UI.RawUI.CursorPosition = $initialPosition
        Write-Host (" " * 100) -NoNewline
        
        # Move to a new line and write the final status
        Write-Host ""
        Write-Host $finalProgressBar
        Write-Host ""
        Write-Host "  $($BOLD_RED)✗ Subaccount did not become ready within the timeout period.$($RESET)"
        exit 1
    }
    
    # Wait before next check
    Start-Sleep -Seconds 3
    $attempt++
}

# Target the subaccount
Write-Host ""
Write-Host "  $($CYAN)Targeting subaccount...$($RESET)"

$result = Start-ProcessingAnimation -Activity "  Targeting subaccount" -ScriptBlock {
    $output = & ./btp target --subaccount "$using:subaccount_id" *>&1
    
    return @{
        Output = $output
        ExitCode = $LASTEXITCODE
    }
}

$output = $result.Output
$targetSuccess = ($result.ExitCode -eq 0)

if (-not $targetSuccess) {
    Write-Host ""
    Write-Host "  $($BOLD_RED)Failed to target subaccount. Error: $output$($RESET)"
    exit 1
}


Write-Host ""
Write-Host "  $($BOLD_GREEN)Successfully targeted subaccount.$($RESET)"


#
# CREATE & ENABLE CLOUD FOUNDRY ENVIRONMENT 
#


# Enable Cloud Foundry
Write-Host ""
Write-Host "  $($CYAN)Enabling Cloud Foundry environment...$($RESET)"

$result = Start-ProcessingAnimation -Activity "  Enabling Cloud Foundry" -ScriptBlock {
    $cf_creation_output = & ./btp create accounts/environment-instance --subaccount "$using:subaccount_id" --environment "cloudfoundry" --service "cloudfoundry" --plan "trial" --display-name "${using:unique_subdomain}_Trial" --parameters "{`"instance_name`": `"${using:unique_subdomain}_Trial`", `"org_name`": `"${using:global_subdomain}_${using:unique_subdomain}`"}" 2>$null
    
    return @{
        Output = $cf_creation_output
        ExitCode = $LASTEXITCODE
    }
}

$cf_creation_output = $result.Output
$cfEnableSuccess = ($result.ExitCode -eq 0)

if (-not $cfEnableSuccess) {
    Write-Host "  $($BOLD_RED)Failed to enable Cloud Foundry environment. Error: $cf_creation_output$($RESET)"
    exit 1
}

# Extract the environment ID from the output
$cf_env_id = $cf_creation_output | 
             Select-String -Pattern "environment id:" | 
             ForEach-Object { $_.Line -replace "environment id:\s*", "" }

# Verify the ID was captured correctly
### Write-Host ""
### Write-Host "  $($CYAN)Extracted Environment ID: $($BOLD_WHITE)$cf_env_id$($RESET)"

# Wait for CF environment to be created
Write-Host ""
Write-Host "  $($BOLD_CYAN)Waiting for Cloud Foundry environment to be ready...$($RESET)"
$initialPosition = $host.UI.RawUI.CursorPosition

$cfReady = $false
$attempt = 1
$max_attempts = 15

while ($attempt -le $max_attempts -and -not $cfReady) {
    # Get CF environment status
    $cf_env_output = & ./btp get accounts/environment-instance $cf_env_id --subaccount "$subaccount_id" 2>$null
    
    # Extract the state value
    $cf_env_state = $cf_env_output | 
                    Select-String -Pattern "state:\s+(\w+)" -AllMatches | 
                    Where-Object { $_.Line -notmatch "state message:" } | 
                    ForEach-Object { $_.Matches.Groups[1].Value }
    
    # Default to PENDING if no state found
    if ([string]::IsNullOrEmpty($cf_env_state)) {
        $cf_env_state = "PENDING"
    }
    
    # Return to saved position
    $host.UI.RawUI.CursorPosition = $initialPosition
    
    # Create progress bar
    $progressWidth = 15  # Width of the progress bar
    $filledWidth = [Math]::Min([Math]::Floor(($attempt / $max_attempts) * $progressWidth), $progressWidth)
    $emptyWidth = $progressWidth - $filledWidth
    
    $progressBar = "  $($BLUE)Checking CF state $($RESET)($($BOLD_BLUE)$attempt$($RESET)/$($BOLD_BLUE)$max_attempts$($RESET)): $($YELLOW)$cf_env_state$($RESET) [$($CYAN)$('#' * $filledWidth)$(' ' * $emptyWidth)$($RESET)]"
    
    # Write the progress bar
    Write-Host $progressBar -NoNewline
    
    # Check if ready
    if ($cf_env_state -eq "OK") {
        # Save the final progress bar state
        $finalProgressBar = $progressBar
        
        # Clear the line
        $host.UI.RawUI.CursorPosition = $initialPosition
        Write-Host (" " * 100) -NoNewline
        
        # Move to a new line and write the final status
        Write-Host ""
        Write-Host $finalProgressBar
        Write-Host ""
        Write-Host "  $($BOLD_GREEN)✓ Cloud Foundry environment is ready!$($RESET)"
        
        $cfReady = $true
        break
    }
    
    # Check if max attempts reached
    if ($attempt -eq $max_attempts) {
        # Save the final progress bar state
        $finalProgressBar = $progressBar
        
        # Clear the line
        $host.UI.RawUI.CursorPosition = $initialPosition
        Write-Host (" " * 100) -NoNewline
        
        # Move to a new line and write the final status
        Write-Host ""
        Write-Host $finalProgressBar
        Write-Host ""
        Write-Host "  $($BOLD_RED)✗ Cloud Foundry environment did not become ready within the timeout period.$($RESET)"
        exit 1
    }
    
    # Wait before next check
    Start-Sleep -Seconds 3
    $attempt++
}

$cf_api_endpoint = & ./btp get accounts/environment-instance $cf_env_id --subaccount $subaccount_id 2>$null | 
                    Select-String -Pattern '"API Endpoint":"([^"]+)"' | 
                   ForEach-Object { $_.Matches.Groups[1].Value }

$cf_org_name = & ./btp get accounts/environment-instance $cf_env_id --subaccount $subaccount_id 2>$null | 
                   Select-String -Pattern '"Org Name":"([^"]+)"' | 
                   ForEach-Object { $_.Matches.Groups[1].Value }

# Log in to CF
Write-Host ""
Write-Host "  $($CYAN)Logging in to Cloud Foundry...$($RESET)"

$result = Start-ProcessingAnimation -Activity "  Logging in to Cloud Foundry" -ScriptBlock {
    $output = & ./cf login -a "$using:cf_api_endpoint" -u "$using:userid" -p "$using:passw" -o "$using:cf_org_name" 2>$null
    
    return @{
        Output = $output
        ExitCode = $LASTEXITCODE
    }
}

Write-Host ""
# Check if login was successful
if ($result.ExitCode -ne 0) {
    Write-Host "  $($BOLD_RED)✗ Login failed. Exiting.$($RESET)"
    exit 1
} else {
    Write-Host "  $($BOLD_GREEN)✓ Login successful!$($RESET)"
}

# Create CF space
Write-Host ""
Write-Host "  $($BOLD_CYAN)Creating Cloud Foundry space (dev)...$($RESET)"

$result = Start-ProcessingAnimation -Activity "  Creating Cloud Foundry space" -ScriptBlock {
    $output = & ./cf create-space dev 2>$null
    
    return @{
        Output = $output
        ExitCode = $LASTEXITCODE
    }
}

Write-Host ""
# Check if space creation was successful
if ($result.ExitCode -ne 0) {
    Write-Host "  $($BOLD_RED)✗ Failed to create Cloud Foundry space.$($RESET)"
    exit 1
} else {
    Write-Host "  $($BOLD_GREEN)✓ Cloud Foundry space created!$($RESET)"
}

# Target CF space
Write-Host ""
Write-Host "  $($BOLD_CYAN)Targeting Cloud Foundry space (dev)...$($RESET)"

$result = Start-ProcessingAnimation -Activity "  Targeting Cloud Foundry space" -ScriptBlock {
    $output = & ./cf target -s dev 2>$null
    
    return @{
        Output = $output
        ExitCode = $LASTEXITCODE
    }
}

Write-Host ""
# Check if space target was successful
if ($result.ExitCode -ne 0) {
    Write-Host "  $($BOLD_RED)✗ Failed to target Cloud Foundry space.$($RESET)"
    exit 1
} else {
    Write-Host "  $($BOLD_GREEN)✓ Cloud Foundry space targeted!$($RESET)"
}


#
# ENABLE SERVICE PLANS
#


# SECTION 1: Add all required service plans
Write-Host ""
Write-Host "  $($BOLD_BLUE)=== Adding All Required Service Plans ===$($RESET)"
Write-Host ""

# Array of services and their plans to add with value enable
$service_plans_enable = @(
  "it-rt integration-flow",
  "it-rt api",
  "sapappstudiotrial trial"
)

# Array of services and their plans to add with value amount
$service_plans_amount = @(
  "integrationsuite-trial trial",
  "sap-build-apps free"
)

# Loop through and add all service plans with value amount first
foreach ($service_plan in $service_plans_amount) {
  $service, $plan = $service_plan.Split(" ")
  Write-Host "  $($CYAN)Adding entitlement for $service ($plan plan)...$($RESET)"
  
  $result = Start-ProcessingAnimation -Activity "  Adding entitlement for $service ($plan plan)" -ScriptBlock {
    & ./btp assign accounts/entitlement --to-subaccount $using:subaccount_id --for-service $using:service --plan $using:plan --amount 1 2>$null
    
    return @{
        ExitCode = $LASTEXITCODE
    }
  }
  
  Write-Host ""
  if ($result.ExitCode -eq 0) {
    Write-Host "  $($BOLD_GREEN)✓ Added entitlement for $service ($plan plan)!$($RESET)"
    Write-Host ""
  } else {
    Write-Host "  $($YELLOW)⚠ Failed to add entitlement for $service ($plan plan).$($RESET)"
  }
}

Write-Host ""
# Loop through and add all service plans with value enable
foreach ($service_plan in $service_plans_enable) {
  $service, $plan = $service_plan.Split(" ")
  Write-Host "  $($CYAN)Adding entitlement for $service ($plan plan)...$($RESET)"
  
  $result = Start-ProcessingAnimation -Activity "  Adding entitlement for $service ($plan plan)" -ScriptBlock {
    & ./btp assign accounts/entitlement --to-subaccount $using:subaccount_id --for-service $using:service --plan $using:plan --enable 2>$null
    
    return @{
        ExitCode = $LASTEXITCODE
    }
  }
  
  Write-Host ""
  if ($result.ExitCode -eq 0) {
    Write-Host "  $($BOLD_GREEN)✓ Added entitlement for $service ($plan plan)!$($RESET)"
    Write-Host ""
  } else {
    Write-Host "  $($YELLOW)⚠ Failed to add entitlement for $service ($plan plan).$($RESET)"
  }
}

Write-Host ""
Write-Host "  $($BOLD_GREEN)✓ All service plans have been added to the subaccount!$($RESET)"


#
# CREATE SERVICE INSTANCES & SUBSCRIPTIONS 
#

Write-Host ""
# SECTION 2: Create service instances for each entitled service
Write-Host "  $($BOLD_BLUE)=== Creating Services ===$($RESET)"

# Get subscription list in JSON format
$subscriptions_json = & ./btp --format json list accounts/subscription --subaccount "$subaccount_id" 2>$null

# Convert from JSON to PowerShell object
$subscriptions = $subscriptions_json | ConvertFrom-Json

# Find the subscription with commercialAppName = "integrationsuite-trial"
$integration_subscription = $subscriptions.applications | Where-Object { $_.commercialAppName -eq "integrationsuite-trial" }

$integration_appname = $integration_subscription.appName

Write-Host ""
# Create Process Integration Runtime service instance (integration-flow plan)
Write-Host "  $($CYAN)Creating Integration Suite subscription...$($RESET)"
$result = Start-ProcessingAnimation -Activity "  Creating Integration Suite subscription" -ScriptBlock {
    $output = & ./btp subscribe accounts/subaccount --subaccount $using:subaccount_id --to-app $using:integration_appname --plan trial 2>$null
    
    return @{
        Output = $output
        ExitCode = $LASTEXITCODE
    }
}

Write-Host ""
# Poll the subscription status until it's ready
Write-Host "  $($BOLD_CYAN)Waiting for Integration Suite subscription to be ready...$($RESET)"
Write-Host ""
$initialPosition = $host.UI.RawUI.CursorPosition

$attempt = 1
$max_attempts = 15
$subscriptionReady = $false

while ($attempt -le $max_attempts -and -not $subscriptionReady) {
    # Get subscription status in JSON format
    $subscriptions_json = & ./btp --format json list accounts/subscription --subaccount "$subaccount_id" 2>$null

    # Convert from JSON to PowerShell object
    $subscriptions = $subscriptions_json | ConvertFrom-Json
    
    # Find the integration subscription by commercialAppName
    $integration_subscription = $subscriptions.applications | Where-Object { $_.commercialAppName -eq "integrationsuite-trial" }
    
    # Extract the state value
    if ($integration_subscription) {
        $subscription_state = $integration_subscription.state
    } else {
        $subscription_state = "PENDING"
    }
    
    # Return to saved position
    $host.UI.RawUI.CursorPosition = $initialPosition
    
    # Create progress bar
    $progressWidth = 15  # Width of the progress bar
    $filledWidth = [Math]::Min([Math]::Floor(($attempt / $max_attempts) * $progressWidth), $progressWidth)
    $emptyWidth = $progressWidth - $filledWidth
    
    $progressBar = "  $($BLUE)Checking subscription $($RESET)($($BOLD_BLUE)$attempt$($RESET)/$($BOLD_BLUE)$max_attempts$($RESET)): $($YELLOW)$subscription_state$($RESET) [$($CYAN)$('#' * $filledWidth)$(' ' * $emptyWidth)$($RESET)]"
    
    # Write the progress bar
    Write-Host $progressBar -NoNewline
    
    # Check if ready
    if ($subscription_state -eq "SUBSCRIBED") {
        # Save the final progress bar state
        $finalProgressBar = $progressBar
        
        # Clear the line
        $host.UI.RawUI.CursorPosition = $initialPosition
        Write-Host (" " * 100) -NoNewline
        
        # Move to a new line and write the final status
        Write-Host ""
        Write-Host $finalProgressBar
        Write-Host ""
        Write-Host "  $($BOLD_GREEN)✓ Integration Suite subscription ($($BOLD_BLUE)$integration_appname$($RESET)$($BOLD_GREEN)) is ready!$($RESET)"
        $subscriptionReady = $true
        break
    } elseif ($subscription_state -eq "FAILED" -or $subscription_state -eq "NOT_SUBSCRIBED") {
        # Save the final progress bar state
        $finalProgressBar = $progressBar
        
        # Clear the line
        $host.UI.RawUI.CursorPosition = $initialPosition
        Write-Host (" " * 100) -NoNewline
        
        # Move to a new line and write the final status
        Write-Host ""
        Write-Host $finalProgressBar
        Write-Host ""
        Write-Host "  $($BOLD_RED)✗ Integration Suite subscription failed.$($RESET)"
        exit 1
    }
    
    # Check if max attempts reached
    if ($attempt -eq $max_attempts) {
        # Save the final progress bar state
        $finalProgressBar = $progressBar
        
        # Clear the line
        $host.UI.RawUI.CursorPosition = $initialPosition
        Write-Host (" " * 100) -NoNewline
        
        # Move to a new line and write the final status
        Write-Host ""
        Write-Host $finalProgressBar
        Write-Host ""
        Write-Host "  $($BOLD_RED)✗ Integration Suite subscription did not become ready within the timeout period.$($RESET)"
        exit 1
    }
    
    # Wait before next check
    Start-Sleep -Seconds 3
    $attempt++
}

#
# ASSIGN ROLE COLLECTIONS TO USER 
#

Write-Host ""
Write-Host "  $($CYAN)Listing all role collections and assigning them to user...$($RESET)"

# Get all role collections using JSON format
$role_collections = & ./btp --format json list security/role-collection --subaccount "$subaccount_id" | ConvertFrom-Json
$role_names = $role_collections | ForEach-Object { $_.name }

# Loop through each role collection and assign to user
foreach ($role in $role_names) {
    Write-Host ""
    Write-Host "  $($CYAN)Assigning role: $($RESET)$($BOLD_WHITE)$role$($RESET)"
    $result = Start-ProcessingAnimation -Activity "  Assigning role: $role" -ScriptBlock {
        & ./btp assign security/role-collection "$using:role" --to-user "$using:userid" --subaccount "$using:subaccount_id" 2>$null
        
        return @{
            ExitCode = $LASTEXITCODE
        }
    }
    
    if ($result.ExitCode -eq 0) {
        Write-Host "  $($BOLD_GREEN)✓ Role$($RESET) $($BOLD_BLUE)$($role)$($RESET) $($BOLD_GREEN)assigned successfully!$($RESET)"
    } else {
        Write-Host "  $($YELLOW)⚠ Could not assign role: $role$($RESET)"
    }
}


#
# WAIT FOR INTEGRATION SUITE TO BE READY 
#


# Get the Integration Suite URL
$subscription_json = & ./btp --format json list accounts/subscription --subaccount "$subaccount_id" 2>$null | ConvertFrom-Json
$integration_subscription = $subscription_json.applications | Where-Object { $_.appName -eq "$integration_appname" }
$integration_suite_url = $integration_subscription.subscriptionUrl

Write-Host ""
Write-Host "  $($BOLD_GREEN)✓ Integration Suite setup complete!$($RESET)"

Write-Host ""
Write-Host "  $($BOLD_YELLOW)⚠ Manual Activation Required ⚠$($RESET)"
Write-Host ""
Write-Host "  $($YELLOW)1. Access your Integration Suite at: $($BOLD_WHITE)$integration_suite_url$($RESET)"
Write-Host "  $($YELLOW)2. Open the '$($BOLD_WHITE)Capabilities$($RESET)$($YELLOW)' window ($($RESET)$($WHITE)Add Capabilities$($RESET)$($YELLOW)).$($RESET)"
Write-Host "  $($YELLOW)3. Activate the '$($BOLD_WHITE)Cloud Integration$($RESET)$($YELLOW)' ($($WHITE)Build Integration Scenarios$($RESET)$($YELLOW)) capability ($($BOLD_RED)required$($RESET)$($YELLOW)).$($RESET)"
Write-Host "  $($YELLOW)4. Optionally activate other capabilities as needed (Can be done later after script completion).$($RESET)"
Write-Host "  $($YELLOW)5. Wait for activation to complete (status will change to '$($GREEN)Active$($RESET)$($YELLOW)').$($RESET)"
Write-Host "  $($YELLOW)6. Return to this script and press$($RESET) '$($BOLD_WHITE)y$($RESET)' $($YELLOW)to continue.$($RESET)"

Write-Host ""
$confirmation = Get-Confirmation -Message "  Have you completed the Cloud Integration capability activation?"
if (-not $confirmation) {
    Write-Host "  $($BOLD_RED)✗ Cloud Integration capability activation is required to proceed. Exiting.$($RESET)"
    exit 1
}


#
# CREATE PROCESS INTEGRATION RUNTIME SERVICE INSTANCES 
#

Write-Host ""
# Create Process Integration Runtime service instance (integration-flow plan)
Write-Host "  $($CYAN)Creating Process Integration Runtime instance (integration-flow plan)...$($RESET)"
$result = Start-ProcessingAnimation -Activity "  Creating Process Integration Runtime instance (integration-flow plan)" -ScriptBlock {
  & ./cf create-service it-rt integration-flow pi-runtime 2>$null
  
  return @{
      ExitCode = $LASTEXITCODE
  }
}

if ($result.ExitCode -eq 0) {
    Write-Host "  $($BOLD_GREEN)✓ Process Integration Runtime IF instance created!$($RESET)"
  } else {
    Write-Host "  $($BOLD_RED)✗ Failed to create Process Integration Runtime IF instance.$($RESET)"
  }

# Create Process Integration Runtime API instance
Write-Host ""
Write-Host "  $($CYAN)Creating Process Integration Runtime API instance...$($RESET)"
$result = Start-ProcessingAnimation -Activity "  Creating Process Integration Runtime API instance" -ScriptBlock {
    & ./cf create-service it-rt api pi-runtime-api 2>$null
    
    return @{
        ExitCode = $LASTEXITCODE
    }
}

if ($result.ExitCode -eq 0) {
  Write-Host "  $($BOLD_GREEN)✓ Process Integration Runtime API instance created!$($RESET)"
} else {
  Write-Host "  $($BOLD_RED)✗ Failed to create Process Integration Runtime API instance.$($RESET)"
}

Write-Host ""
Write-Host "  $($CYAN)Listing all new role collections and assigning them to user...$($RESET)"

#
# ASSIGN ROLE COLLECTIONS TO USER 
#

# Get all role collections using JSON format
$role_collections = & ./btp --format json list security/role-collection --subaccount "$subaccount_id" | ConvertFrom-Json
$role_names = $role_collections | ForEach-Object { $_.name }

# Loop through each role collection and assign to user
foreach ($role in $role_names) {
    Write-Host ""
    Write-Host "  $($CYAN)Assigning role: $($RESET)$($BOLD_WHITE)$role$($RESET)"
    $result = Start-ProcessingAnimation -Activity "  Assigning role: $role" -ScriptBlock {
        & ./btp assign security/role-collection "$using:role" --to-user "$using:userid" --subaccount "$using:subaccount_id" 2>$null
        
        return @{
            ExitCode = $LASTEXITCODE
        }
    }
    
    if ($result.ExitCode -eq 0) {
        Write-Host "  $($BOLD_GREEN)✓ Role$($RESET) $($BOLD_BLUE)$($role)$($RESET) $($BOLD_GREEN)assigned successfully!$($RESET)"
    } else {
        Write-Host "  $($YELLOW)⚠ Could not assign role: $role$($RESET)"
    }
}

$roleCollections = ./btp --format json list security/role-collection --subaccount "$subaccount_id" | ConvertFrom-Json
$rolesList = $roleCollections | ForEach-Object { "  $($_.name)" }

#
# CREATE SERVICE KEY FOR PROCESS INTEGRATION RUNTIME 
#

Write-Host ""

Write-Host "  $($CYAN)Creating IF service key...$($RESET)"
$result = Start-ProcessingAnimation -Activity "  Creating IF service key" -ScriptBlock {
  & ./cf create-service-key pi-runtime pi-runtime-key 2>$null
  
  return @{
      ExitCode = $LASTEXITCODE
  }
}
  
if ($result.ExitCode -eq 0) {
  Write-Host "  $($BOLD_GREEN)✓ IF Service key created!$($RESET)"
} else {
    Write-Host "  $($BOLD_RED)✗ Failed to create IF service key.$($RESET)"
  }
  
# Check service key
Write-Host ""
$result = Start-ProcessingAnimation -Activity "  Fetching IF service key details" -ScriptBlock {
    $serviceKeyOutput = ./cf service-key pi-runtime pi-runtime-key
    $tokenurl = $serviceKeyOutput | Select-String -Pattern '"tokenurl"\s*:\s*"([^"]+)"' | ForEach-Object { $_.Matches.Groups[1].Value } 
    $clientid = $serviceKeyOutput | Select-String -Pattern '"clientid"\s*:\s*"([^"]+)"' | ForEach-Object { $_.Matches.Groups[1].Value } 
    $clientsecret = $serviceKeyOutput | Select-String -Pattern '"clientsecret"\s*:\s*"([^"]+)"' | ForEach-Object { $_.Matches.Groups[1].Value } 
    
    # Return an object with the values you want to access later
    return @{
        TokenUrl = $tokenurl
        ClientId = $clientid
        ClientSecret = $clientsecret
    }
}

# Then access the variables from the result
$tokenurl = $result.TokenUrl
$clientid = $result.ClientId
$clientsecret = $result.ClientSecret


#
# END OF SCRIPT & GREETER 
#


# Final summary
Write-Host ""
Write-Host "$($BOLD_GREEN)✅ Setup completed successfully! ✅$($RESET)"
Write-Host ""
Write-Host "$($BOLD_CYAN)Summary:$($RESET)"
Write-Host "$($CYAN)- User Assigned: $($BOLD_WHITE)$userid$($RESET)"
Write-Host "$($CYAN)- Global Account: $($BOLD_WHITE)$global_account_id$($RESET)"
Write-Host "$($CYAN)- Subaccount Name: $($BOLD_WHITE)$subaccountDisplayName$($RESET)"
Write-Host "$($CYAN)- Subaccount ID: $($BOLD_WHITE)$subaccount_id$($RESET)"
Write-Host "$($CYAN)- Region: $($BOLD_WHITE)$selected_region$($RESET)"
Write-Host "$($CYAN)- Subdomain: $($BOLD_WHITE)$unique_subdomain$($RESET)"
Write-Host "$($CYAN)- Cloud Foundry Org: $($BOLD_WHITE)$cf_org_name$($RESET)"
Write-Host "$($CYAN)- Cloud Foundry Space: $($BOLD_WHITE)dev$($RESET)"
Write-Host "$($CYAN)- Cloud Foundry API Environment ID: $($BOLD_WHITE)$cf_env_id$($RESET)"
Write-Host "$($CYAN)- Cloud Foundry API Endpoint: $($BOLD_WHITE)$cf_api_endpoint$($RESET)"
Write-Host "$($CYAN)- Integration Flow Token URL: $($BOLD_WHITE)$tokenurl$($RESET)"
Write-Host "$($CYAN)- Integration Flow Client ID: $($BOLD_WHITE)$clientid$($RESET)"
Write-Host "$($CYAN)- Integration Flow Secret: $($BOLD_WHITE)$clientsecret$($RESET)"
Write-Host "$($CYAN)- Role Collections:$($RESET)"
Write-Host "$($WHITE)$($rolesList -join "`n")$($RESET)"
Write-Host ""
Write-Host "$($BOLD_GREEN)You can now access the Integration Suite at: $($BOLD_WHITE)$integration_suite_url$($RESET)"
Write-Host ""
