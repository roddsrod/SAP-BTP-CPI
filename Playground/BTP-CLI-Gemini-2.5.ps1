# PowerShell equivalent of the Bash script - CORRECTED MINIMAL FIX FOR EXECUTION PATH
# Script to automate 95% of the steps in creating a working Integration Suite.
# Script is to be run with no subaccounts or at least none that has an entitlement to
# the integration suite as there is only one allowed per global account.
# Created by Rodolfo Rodrigues. Minimal execution path fix by AI.

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
$GREEN_BG = "$ESC[42m"
$BOLD_RED = "$ESC[1;31m"
$BOLD_GREEN = "$ESC[1;32m"
$BOLD_YELLOW = "$ESC[1;33m"
$BOLD_BLUE = "$ESC[1;34m"
$BOLD_MAGENTA = "$ESC[1;35m"
$BOLD_CYAN = "$ESC[1;36m"
$BOLD_WHITE = "$ESC[1;37m"

# Function to read credentials from file
function Read-CredentialsFromFile {
    $CredentialsFile = "credentials.txt"

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
        Write-Host ""
        # Use original Read-Host prompt
        $manual_cred = Read-Host "  $($BOLD_YELLOW)Do you want to enter credentials manually? $($RESET)$($YELLOW)($($RESET)$($BOLD_WHITE)y$($RESET)$($YELLOW)/$($RESET)$($BOLD_WHITE)n$($RESET)$($YELLOW))$($RESET)"

        if ($manual_cred -eq "y" -or $manual_cred -eq "Y") {
                    # Ask for manual credentials input
        Write-Host ""
        Write-Host "  $($CYAN)ℹ Enter credentials manually:$($RESET)"
        Write-Host ""
        $userid = Read-Host "$($BOLD_WHITE)  Username $($RESET)$($WHITE)(email)$($RESET)"
        Write-Host ""
        # Use original -MaskInput which works in PS Core 7+
        $passwSecure = Read-Host "$($BOLD_WHITE)  Password$($RESET)" -AsSecureString
        # Convert for external commands
        $passwPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($passwSecure)
            )


        # Ask if user wants to save credentials
        Write-Host ""
        $saveCredentials = Read-Host "  $($BOLD_YELLOW)Do you want to save these credentials ($($RESET)$($YELLOW)cleartext$($RESET)$($BOLD_YELLOW)) to $($BOLD_WHITE)$($CredentialsFile)$($RESET)$($BOLD_YELLOW)? $($RESET)$( $YELLOW)($($RESET)$($BOLD_WHITE)y$($RESET)$($YELLOW)/$($RESET)$($BOLD_WHITE)n$($RESET)$($YELLOW))$($RESET)"

        if ($saveCredentials -eq 'y' -or $saveCredentials -eq 'Y') {
            try {
                # Save credentials to file
                $userid | Out-File -FilePath $CredentialsFile -Force
                # Use plain text password for saving
                $passwPlainText | Out-File -FilePath $CredentialsFile -Append -Force

                Write-Host ""
                Write-Host "  $($BOLD_GREEN)✓ Credentials saved to $CredentialsFile successfully!$($RESET)"
            }
            catch {
                Write-Host ""
                Write-Host "  $($BOLD_RED)✗ Error saving credentials to file: $_$($RESET)"
            }
        }

        Write-Host ""
        Write-Host "  $($CYAN)Using manually entered credentials.$($RESET)"

        return @{
            UserId = $userid
            Password = $passwPlainText # Return plain text
        }
        } else {
            Write-Host ""
            Write-Host "  $($RED)Create the $($BOLD_RED)$CredentialsFile$($RESET) $($RED)file in the same folder as this script and run it again.$($RESET)"
            Write-Host "  $($RED)Put your username (email) in the first line.$($RESET)"
            Write-Host "  $($RED)Put your password in the second line.$($RESET)"
            Write-Host ""
            exit 1
        }
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
        Write-Host "`r  $Activity $spinner" -NoNewline # Use `r for overwrite
        Start-Sleep -Milliseconds 100
        $i++
    }

    # Get the console width to clear the entire line
    $consoleWidth = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 } # Default width

    # Clear the entire line before showing result/error
    Write-Host "`r$(' ' * ($consoleWidth - 1))" -NoNewline
    Write-Host "`r" -NoNewline # Move cursor to beginning

    # Get the job output
    $result = Receive-Job -Job $job

    # Check for errors (original logic was missing explicit error check here)
    if ($job.Error) {
        Write-Host "" # Ensure error appears on a new line
        Write-Host "  $($BOLD_RED)✗ Error during '$Activity':$($RESET)"
        $job.Error | ForEach-Object { Write-Host "    $($RED)$_$($RESET)" }
    }

    Remove-Job -Job $job

    return $result
}


# Function to ask for confirmation (original using ReadKey)
function Get-Confirmation {
    param (
        [string]$Message
    )

    Write-Host "$($BOLD_YELLOW)$Message$($RESET) $($YELLOW)($($RESET)$($BOLD_WHITE)y$($RESET)$($YELLOW)/$($RESET)$($BOLD_WHITE)n$($RESET)$($YELLOW))$($RESET): " -NoNewline
    $keyInfo = [Console]::ReadKey($true) # Read key without echo
    $keyChar = $keyInfo.KeyChar
    Write-Host $keyChar # Echo the key pressed
    Write-Host "" # Newline

    return ($keyChar -eq 'y') # Case-sensitive 'y' check
}


# Function to check command existence (original logic)
function Test-CommandExists {
    param (
        [string]$Command
    )

    # Check if command exists in PATH
    $existsInPath = $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)

    # Check if command exists as a file in current directory (OS specific checks)
    $currentDirExeWin = ".\${Command}.exe"
    $currentDirExeNix = "./${Command}"
    # Special check for cf8.exe on Windows
    $cf8ExePath = if ($IsWindows -and $Command -eq "cf") { ".\cf8.exe"} else { $null }

    $existsInCurrentDir = if ($IsWindows) {
                                Test-Path -Path $currentDirExeWin -PathType Leaf
                           } else {
                                Test-Path -Path $currentDirExeNix -PathType Leaf
                           }
    $existsCf8 = if ($cf8ExePath) { Test-Path -Path $cf8ExePath -PathType Leaf } else { $false }


    return ($existsInPath -or $existsInCurrentDir -or $existsCf8)
}

# Function to detect OS (original logic)
function Get-OSType {
    if ($IsWindows) { return "Windows" } # $IsWindows is reliable in PS Core
    if ($IsMacOS) { return "MacOS" }
    if ($IsLinux) { return "Linux" }

    # Fallback detection using uname (original logic)
        # Use try/catch for safety if uname isn't present
    $uname = ""
    try {
        $uname = (& uname).Trim()
    } catch {
        Write-Verbose "uname command not found or failed: $($_.Exception.Message)"
    }

    if ($uname -eq "Darwin") { return "MacOS" }
    if ($uname -eq "Linux") { return "Linux" }

    # Default assumption if nothing else matches
    return "Windows"
}


# ---- START OF MINIMAL FIX ----
# Determine OS Type early
$global:osType = Get-OSType

# Define executable paths based on OS
$btpCmd = if ($global:osType -eq "Windows") { ".\btp.exe" } else { "./btp" }
# CF executable name depends on the downloaded file (cf8.exe for Windows in this case)
$cfCmd = if ($global:osType -eq "Windows") { ".\cf8.exe" } else { "./cf" }
# ---- END OF MINIMAL FIX ----


# Function to install CF CLI
function Install-CF {
    # Note: Relies on $global:osType being set
    $installPath = "."

    switch ($global:osType) {
# Inside the Install-CF function

        "Windows" {
            Write-Host ""
            Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing CF CLI for$($RESET) $($BOLD_WHITE)Windows$($BOLD_CYAN)...$($RESET)"
            # Define tarFile instead of zipFile
            $tarFile = "cf-cli.tar.gz" # Changed filename
            # Correct URL pointing to .tar.gz
            $url = "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/cf8-cli_8.11.0_winx64.tar.gz" # Changed URL
            # Define activity message
            $activity = "Downloading CF CLI for Windows ($tarFile)"

            $result = Start-ProcessingAnimation -Activity "  $activity" -ScriptBlock {
                $output = ""
                $exitCode = 1
                try {
                # Download the .tar.gz file
                Invoke-WebRequest -Uri $using:url -OutFile $using:tarFile -ErrorAction Stop

                # Ensure tar command exists
                Get-Command tar -ErrorAction Stop | Out-Null

                # Extract using tar command
                $tarOutput = & tar -zx -f $using:tarFile -C $using:installPath 2>&1
                $exitCode = $LASTEXITCODE # Check tar's exit code
                $output = $tarOutput # Store tar's output/error

                if ($exitCode -ne 0) {
                    throw "tar extraction failed with exit code $exitCode. Output: $tarOutput"
                }

                # Remove the downloaded archive if extraction succeeded
                Remove-Item $using:tarFile -Force

                # Success
                $output = "Success"
                $exitCode = 0

                } catch {
                    $output = $_.Exception.Message
                    $exitCode = 1
                }
            return @{ Output = $output; ExitCode = $exitCode }
        }
            # Check result and print status
            Write-Host "" # Newline after animation
            if ($result.ExitCode -eq 0) {
                # Reference the command variable $cfCmd (should be .\cf8.exe)
                Write-Host "$($BOLD_GREEN)  ✓ CF CLI ($($cfCmd)) installed to current directory.$($RESET)"
            } else {
                Write-Host "$($BOLD_RED)  ✗ Failed to install CF CLI. Error: $($result.Output)$($RESET)"
                # Add a note about tar dependency on Windows
                Write-Host "$($BOLD_YELLOW)  NOTE: This requires the 'tar' command to be available in your Windows environment.$($RESET)"
                exit 1
            }
        }
        "MacOS" {
            $cpuArch = try { (& uname -m).Trim() } catch { "x86_64" } # Original check
            $tarFile = "cf-cli.tgz"
            if ($cpuArch -eq "arm64" -or $cpuArch -eq "aarch64") {
                Write-Host ""
                Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing CF CLI for$($RESET) $($BOLD_WHITE)MacOS (ARM64)$($BOLD_CYAN)...$($RESET)"
                $url = "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/cf8-cli_8.11.0_macosarm.tgz"
                $activity = "Downloading CF CLI for MacOS (ARM64)"
            } else {
                Write-Host ""
                Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing CF CLI for$($RESET) $($BOLD_WHITE)MacOS (x64)$($BOLD_CYAN)...$($RESET)"
                $url = "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/cf8-cli_8.11.0_osx.tgz"
                $activity = "Downloading CF CLI for MacOS (x64)"
            }
            $result = Start-ProcessingAnimation -Activity "  $activity" -ScriptBlock {
                # Original used curl | tar. Try with Invoke-WebRequest + tar first for consistency
                $output = ""
                $exitCode = 1
                 try {
                    Invoke-WebRequest -Uri $using:url -OutFile $using:tarFile -ErrorAction Stop
                    # Ensure tar exists before trying to use it
                    Get-Command tar -ErrorAction Stop | Out-Null
                    & tar -zx -f $using:tarFile -C $using:installPath 2>&1 # Capture tar output/errors
                    $exitCode = $LASTEXITCODE
                    Remove-Item $using:tarFile -Force
                    # Add execute permission if extraction succeeded
                    if ($exitCode -eq 0) {
                        try {
                            & chmod +x $using:cfCmd
                        } catch { Write-Warning "chmod failed: $_" } # Non-fatal?
                    }
                 } catch {
                     $output = $_.Exception.Message
                     $exitCode = 1 # Ensure failure code
                 }
                return @{ Output = $output; ExitCode = $exitCode }
            }
            Write-Host "" # Newline after animation
            if ($result.ExitCode -eq 0) {
                Write-Host "$($BOLD_GREEN)  ✓ CF CLI ($($cfCmd)) installed to current directory.$($RESET)"
            } else {
                Write-Host "$($BOLD_RED)  ✗ Failed to install CF CLI. Error: $($result.Output)$($RESET)"
                exit 1
            }
        }
        "Linux" {
            Write-Host ""
            Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing CF CLI for$($RESET) $($BOLD_WHITE)Linux$($BOLD_CYAN)...$($RESET)"
            $tarFile = "cf-cli.tgz"
            $url = "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/cf8-cli_8.11.0_linux_x86-64.tgz"
            $result = Start-ProcessingAnimation -Activity "  Downloading CF CLI for Linux" -ScriptBlock {
                 $output = ""
                 $exitCode = 1
                 try {
                    Invoke-WebRequest -Uri $using:url -OutFile $using:tarFile -ErrorAction Stop
                    Get-Command tar -ErrorAction Stop | Out-Null
                    & tar -zx -f $using:tarFile -C $using:installPath 2>&1
                    $exitCode = $LASTEXITCODE
                    Remove-Item $using:tarFile -Force
                     if ($exitCode -eq 0) {
                         try {
                            & chmod +x $using:cfCmd
                         } catch { Write-Warning "chmod failed: $_" }
                     }
                 } catch {
                     $output = $_.Exception.Message
                     $exitCode = 1
                 }
                return @{ Output = $output; ExitCode = $exitCode }
            }
            Write-Host "" # Newline after animation
            if ($result.ExitCode -eq 0) {
                Write-Host "$($BOLD_GREEN)  ✓ CF CLI ($($cfCmd)) installed to current directory.$($RESET)"
            } else {
                Write-Host "$($BOLD_RED)  ✗ Failed to install CF CLI. Error: $($result.Output)$($RESET)"
                exit 1
            }
        }
    }
}

# Function to install BTP CLI
function Install-BTP {
    # Note: Relies on $global:osType being set
    $installPath = "."

    switch ($global:osType) {
        "Windows" {
            Write-Host ""
            Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing BTP CLI for$($RESET) $($BOLD_WHITE)Windows$($BOLD_CYAN)...$($RESET)"
            # Define tarFile
            $tarFile = "btp-cli.tar.gz"
            # Correct URL pointing to .tar.gz
            $url = "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/btp-cli-windows-amd64-2.83.0.tar.gz"
            # Define activity message
            $activity = "Downloading BTP CLI for Windows ($tarFile)"

            $result = Start-ProcessingAnimation -Activity "  $activity" -ScriptBlock {
                # $output and $exitCode initialization are good
                $output = ""
                $exitCode = 1
                try {
                   # Download the .tar.gz file
                   Invoke-WebRequest -Uri $using:url -OutFile $using:tarFile -ErrorAction Stop

                   # Ensure tar command exists (crucial for Windows!)
                   # Windows 10/11 usually have it, older versions might not.
                   Get-Command tar -ErrorAction Stop | Out-Null

                   # Extract using tar command
                   # Capture output/error from tar for better diagnostics
                   $tarOutput = & tar -zx -f $using:tarFile -C $using:installPath 2>&1
                   $exitCode = $LASTEXITCODE # Check tar's exit code
                   $output = $tarOutput # Store tar's output/error

                   # Check tar exit code specifically
                   if ($exitCode -ne 0) {
                       # Throw an error to be caught below if tar failed
                       throw "tar extraction failed with exit code $exitCode. Output: $tarOutput"
                   }

                   # Remove the downloaded archive if extraction succeeded
                   Remove-Item $using:tarFile -Force

                   # If we got here, all steps succeeded
                   $output = "Success" # Overwrite tar output with success message if desired
                   $exitCode = 0

                } catch {
                    # Capture the error message (from IWR, Get-Command, or thrown tar error)
                    # Ensure $output contains the error, $exitCode remains 1 (or set explicitly)
                    $output = $_.Exception.Message
                    $exitCode = 1
                }
                # Return the result hash table
               return @{ Output = $output; ExitCode = $exitCode }
           }
            # Rest of the function (checking $result.ExitCode, printing status) remains the same...
             Write-Host "" # Newline after animation
            if ($result.ExitCode -eq 0) {
                Write-Host "$($BOLD_GREEN)  ✓ BTP CLI ($($btpCmd)) installed to current directory.$($RESET)"
            } else {
                Write-Host "$($BOLD_RED)  ✗ Failed to install BTP CLI. Error: $($result.Output)$($RESET)"
                # Add a note about tar dependency on Windows
                Write-Host "$($BOLD_YELLOW)  NOTE: This requires the 'tar' command to be available in your Windows environment.$($RESET)"
                exit 1
            }
        }
        "MacOS" {
             $cpuArch = try { (& uname -m).Trim() } catch { "x86_64" }
            $tarFile = "btp-cli.tar.gz"
            if ($cpuArch -eq "arm64" -or $cpuArch -eq "aarch64") {
                Write-Host ""
                Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing BTP CLI for$($RESET) $($BOLD_WHITE)MacOS (ARM64)$($BOLD_CYAN)...$($RESET)"
                $url = "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/btp-cli-darwin-arm64-2.83.0.tar.gz"
                 $activity = "Downloading BTP CLI for MacOS (ARM64)"
            } else {
                Write-Host ""
                Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing BTP CLI for$($RESET) $($BOLD_WHITE)MacOS (x64)$($BOLD_CYAN)...$($RESET)"
                $url = "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/btp-cli-darwin-amd64-2.83.0.tar.gz"
                 $activity = "Downloading BTP CLI for MacOS (x64)"
            }
            $result = Start-ProcessingAnimation -Activity "  $activity" -ScriptBlock {
                 $output = ""
                 $exitCode = 1
                 try {
                    Invoke-WebRequest -Uri $using:url -OutFile $using:tarFile -ErrorAction Stop
                    Get-Command tar -ErrorAction Stop | Out-Null
                    & tar -zx -f $using:tarFile -C $using:installPath 2>&1
                    $exitCode = $LASTEXITCODE
                    Remove-Item $using:tarFile -Force
                     if ($exitCode -eq 0) {
                         try {
                            & chmod +x $using:btpCmd
                         } catch { Write-Warning "chmod failed: $_" }
                     }
                 } catch {
                     $output = $_.Exception.Message
                     $exitCode = 1
                 }
                return @{ Output = $output; ExitCode = $exitCode }
            }
            Write-Host "" # Newline after animation
            if ($result.ExitCode -eq 0) {
                Write-Host "$($BOLD_GREEN)  ✓ BTP CLI ($($btpCmd)) installed to current directory.$($RESET)"
            } else {
                Write-Host "$($BOLD_RED)  ✗ Failed to install BTP CLI. Error: $($result.Output)$($RESET)"
                exit 1
            }
        }
        "Linux" {
             $cpuArch = try { (& uname -m).Trim() } catch { "x86_64" }
            $tarFile = "btp-cli.tar.gz"
             if ($cpuArch -eq "arm64" -or $cpuArch -eq "aarch64") {
                Write-Host ""
                Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing BTP CLI for$($RESET) $($BOLD_WHITE)Linux (ARM64)$($BOLD_CYAN)...$($RESET)"
                $url = "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/btp-cli-linux-arm64-2.83.0.tar.gz"
                 $activity = "Downloading BTP CLI for Linux (ARM64)"
            } else {
                 Write-Host ""
                Write-Host "$($BOLD_CYAN)  ⬇ Downloading and Installing BTP CLI for$($RESET) $($BOLD_WHITE)Linux (x64)$($BOLD_CYAN)...$($RESET)"
                $url = "https://raw.githubusercontent.com/roddsrod/SAP-BTP-CPI/refs/heads/main/Dependencies/btp-cli-linux-amd64-2.83.0.tar.gz"
                 $activity = "Downloading BTP CLI for Linux (x64)"
            }
            $result = Start-ProcessingAnimation -Activity "  $activity" -ScriptBlock {
                 $output = ""
                 $exitCode = 1
                 try {
                    Invoke-WebRequest -Uri $using:url -OutFile $using:tarFile -ErrorAction Stop
                    Get-Command tar -ErrorAction Stop | Out-Null
                    & tar -zx -f $using:tarFile -C $using:installPath 2>&1
                    $exitCode = $LASTEXITCODE
                    Remove-Item $using:tarFile -Force
                     if ($exitCode -eq 0) {
                         try {
                            & chmod +x $using:btpCmd
                         } catch { Write-Warning "chmod failed: $_" }
                     }
                 } catch {
                     $output = $_.Exception.Message
                     $exitCode = 1
                 }
                 return @{ Output = $output; ExitCode = $exitCode }
            }
            Write-Host "" # Newline after animation
            if ($result.ExitCode -eq 0) {
                Write-Host "$($BOLD_GREEN)  ✓ BTP CLI ($($btpCmd)) installed to current directory.$($RESET)"
            } else {
                Write-Host "$($BOLD_RED)  ✗ Failed to install BTP CLI. Error: $($result.Output)$($RESET)"
                exit 1
            }
        }
    }
}

# Function to interactively select BTP Global Account (original logic restored)
function Invoke-BTPTargetSelection {
        # Original logic using Start-Process and file redirection for 'btp target -h'
        # This aims to list accounts non-interactively first.
        Write-Host ""
        Write-Host "  $($CYAN)Attempting to list global accounts using '$btpCmd target -h'...$($RESET)"

        $proc = $null
        $targetOutput = ""
        $listExitCode = 1
        try {
             # Run non-interactively first to get list
             # Use Start-Process for better redirection control vs `& ... > file`
             $psi = New-Object System.Diagnostics.ProcessStartInfo
             $psi.FileName = $btpCmd
             $psi.Arguments = "target -h"
             $psi.UseShellExecute = $false
             $psi.RedirectStandardOutput = $true
             $psi.RedirectStandardError = $true
             $psi.CreateNoWindow = $true
             $proc = [System.Diagnostics.Process]::Start($psi)
             $targetOutput = $proc.StandardOutput.ReadToEnd()
             $errorOutput = $proc.StandardError.ReadToEnd() # Capture errors too
             $proc.WaitForExit()
             $listExitCode = $proc.ExitCode

             if ($listExitCode -ne 0) {
                Write-Warning "Listing global accounts failed (Exit Code: $listExitCode)."
                Write-Warning "Error output: $errorOutput"
             }
        } catch {
            Write-Host ""
            Write-Host "  $($BOLD_RED)✗ Failed to execute '$btpCmd target -h': $_ $($RESET)"
            # Cannot proceed without listing accounts
            exit 1
        }

        # Extract global accounts from the captured output (original regex)
        $globalAccounts = $targetOutput |
            Select-String -Pattern "\s*(\w+)\s+\(global account\)" -AllMatches | # Original regex
            ForEach-Object { $_.Matches.Groups[1].Value } |
            Select-Object -Unique

        if ($globalAccounts.Count -eq 0) {
            Write-Host ""
            Write-Host "  $($BOLD_RED)✗ Could not find any global accounts in the output of '$btpCmd target -h'.$($RESET)"
            Write-Host "  $($YELLOW)Output was:$($RESET)"
            Write-Host $targetOutput
            # Offer manual entry? Or just exit? Exiting for now based on original flow.
            exit 1
        }

        # Display available global accounts
        Write-Host ""
        Write-Host "  $($BOLD_BLUE)Available global accounts:$($RESET)"
        Write-Host ""
        for ($i = 0; $i -lt $globalAccounts.Count; $i++) {
            Write-Host "  $($BOLD_CYAN)$($i+1)) $($globalAccounts[$i])$($RESET)"
        }

        # Get user selection
        Write-Host ""
        $selection = ""
         while (-not ($selection -match "^\d+$") -or [int]$selection -lt 1 -or [int]$selection -gt $globalAccounts.Count) {
             $selection = Read-Host "  $($BOLD_MAGENTA)Select a global account $($RESET)$($MAGENTA)($($RESET)$($BOLD_WHITE)1$($RESET)$($MAGENTA)-$($RESET)$($BOLD_WHITE)$($globalAccounts.Count)$($RESET)$($MAGENTA))$($RESET)"
             if (-not ($selection -match "^\d+$") -or [int]$selection -lt 1 -or [int]$selection -gt $globalAccounts.Count) {
                 Write-Host "  $($BOLD_RED)✗ Invalid selection. Please enter a number between 1 and $($globalAccounts.Count).$($RESET)"
             }
         }

        # Get the selected global account subdomain
        $selectedGlobalAccountSubdomain = $globalAccounts[[int]$selection-1]

        # BTP CLI uses the subdomain directly for targeting (no "-ga" suffix needed)
        # $selectedGlobalAccountWithSuffix = "$selectedGlobalAccount-ga" # This was incorrect

        Write-Host ""
        Write-Host "  $($CYAN)Targeting the specified global account ($($BOLD_WHITE)$selectedGlobalAccountSubdomain$($RESET)$($CYAN))...$($RESET)"

        # Target the selected global account (non-interactive command)
        $result = Start-ProcessingAnimation -Activity "  Targeting global account $selectedGlobalAccountSubdomain" -ScriptBlock {
            # Use $btpCmd, redirect errors
             $outputTargetCmd = try {
                 & $using:btpCmd target --global-account "$using:selectedGlobalAccountSubdomain" 2>&1
             } catch { $_ }
             return @{ Output = $outputTargetCmd; ExitCode = $LASTEXITCODE }
        }

        if ($result.ExitCode -ne 0) {
             Write-Host ""
             Write-Host "  $($BOLD_RED)✗ Failed to target global account '$selectedGlobalAccountSubdomain'. Exit Code: $($result.ExitCode)$($RESET)"
             Write-Host "  $($RED)Output/Error: $($result.Output -join "`n")$($RESET)"
             exit 1
         }
        # Success message is handled by the caller after this function
}


        ### Main script starts here ###


Write-Host ""
Write-Host "  $($BOLD_CYAN)=======================================$($RESET)"
Write-Host "  $($BOLD_CYAN)SAP Integration Suite Deployment Script$($RESET)"
Write-Host "  $($BOLD_CYAN)=======================================$($RESET)"
Write-Host ""

# Check for required commands (original logic)
$requiredCommands = @("btp", "cf")
$missingCommands = @()

Write-Host "  $($CYAN)ℹ Checking for required commands (btp, cf)...$($RESET)"
foreach ($cmd in $requiredCommands) {
    if (-not (Test-CommandExists $cmd)) {
        $missingCommands += $cmd
         Write-Host "  $($YELLOW)⚠ Command '$cmd' not found.$($RESET)" # Indicate which one
    } else {
         Write-Host "  $($GREEN)✓ Command '$cmd' found.$($RESET)"
    }
}

if ($missingCommands.Count -gt 0) {
    Write-Host ""
    Write-Host "$($BOLD_YELLOW)  ⚠ Warning: The following required commands are missing: $($missingCommands -join ', ')$($RESET)"
    Write-Host ""
    # Original prompt logic
    $installMissing = Read-Host "$($BOLD_MAGENTA)  Do you want to install the missing commands? $($RESET)$($MAGENTA)($($RESET)$($WHITE)[$($RESET)$($BOLD_WHITE)y$($RESET)$($WHITE)]$($RESET)$($MAGENTA)/$($RESET)$($BOLD_WHITE)n$($RESET)$($MAGENTA))$($RESET)"

    # If user just pressed Enter without typing anything, use the default value 'y'
    if ([string]::IsNullOrWhiteSpace($installMissing)) { $installMissing = "y" }

    if ($installMissing.ToLower() -eq "y") {
        foreach ($cmd in $missingCommands) {
            switch ($cmd) {
                "btp" { Install-BTP }
                "cf" { Install-CF }
            }
        }

        # Verify installation (original logic)
        $stillMissing = @()
        Write-Host ""
        Write-Host "  $($CYAN)ℹ Verifying installation...$($RESET)"
        foreach ($cmd in $missingCommands) {
            if (-not (Test-CommandExists $cmd)) {
                $stillMissing += $cmd
            } else {
                Write-Host "  $($GREEN)✓ Verified '$cmd' is now available.$($RESET)"
            }
        }

        if ($stillMissing.Count -gt 0) {
            Write-Host ""
            Write-Host "$($BOLD_RED)  ✗ Error: The following commands could not be installed or found: $($stillMissing -join ', ')$($RESET)"
            Write-Host "$($RED)  Please install them manually or check PATH/permissions.$($RESET)"
            exit 1
        } else {
            Write-Host ""
            Write-Host "$($BOLD_GREEN)  ✓ All required commands are now available.$($RESET)"
        }
    } else {
        Write-Host ""
        Write-Host "$($BOLD_RED)  Error: Missing required commands: $($missingCommands -join ', ')$($RESET)"
        Write-Host "$($RED)  Please install them before running this script.$($RESET)"
        exit 1
    }
}


#
# LOGIN TO BTP CLI & EXTRACT GLOBAL ACCOUNT INFO
#


Write-Host ""
Write-Host "  $($BOLD_YELLOW)⚠ Logging in to BTP$($RESET)" # Original message
Write-Host ""

# Reading credentials
$credential = Read-CredentialsFromFile
$userid = $credential.UserId
$passw = $credential.Password # Plain text

$result = Start-ProcessingAnimation -Activity "  Logging in to BTP" -ScriptBlock {
    # Use $btpCmd, pipe "1" for IDP, redirect errors
    $outputLogin = try {
        "1" | & $using:btpCmd login --url https://cli.btp.cloud.sap --user "$using:userid" --password "$using:passw" 2>&1
    } catch { $_ }

    return @{
        Output = $outputLogin
        ExitCode = $LASTEXITCODE
    }
}

Write-Host "" # Newline after animation
# Check if login was successful
if ($result.ExitCode -ne 0) {
    Write-Host "  $($BOLD_RED)✗ BTP Login failed. Exit Code: $($result.ExitCode).$($RESET)"
    Write-Host "  $($RED)Output/Error: $($result.Output -join "`n")$($RESET)"
    exit 1
} else {
    Write-Host "  $($BOLD_GREEN)✓ BTP Login successful!$($RESET)"
}

# Extract the global account subdomain from login output (original logic - fetch again)
# Use $btpCmd
$globalAccountInfoRaw = try { & $btpCmd get accounts/global-account 2>&1 } catch { $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "$($BOLD_RED)✗ Failed to get global account info after login. Exit Code: $LASTEXITCODE.$($RESET)"
    Write-Host "  $($RED)Output/Error: $($globalAccountInfoRaw -join "`n")$($RESET)"
    exit 1 # Critical failure
}

$global_subdomain = $globalAccountInfoRaw |
        Select-String -Pattern "display name:\s*(.+)" | # Use original regex
        ForEach-Object { $_.Matches.Groups[1].Value.Trim() }

$global_account_id_from_get = $globalAccountInfoRaw | # Also get ID if possible
    Select-String -Pattern "ID:\s*([a-fA-F0-9-]+)" |
    ForEach-Object { $_.Matches.Groups[1].Value.Trim() }


# Verify the Global Account (original logic)
Write-Host ""
Write-Host "  $($CYAN)Active global account name: $($BOLD_WHITE)$global_subdomain$($RESET)"
Write-Host ""

# Ask for confirmation (original logic with Read-Host + default)
$confirmGlobalAccount = Read-Host "  $($YELLOW)Is it the correct global account name? ($($RESET)$($WHITE)[$($RESET)$($BOLD_WHITE)y$($RESET)$($WHITE)]$($RESET)$($YELLOW)/$($RESET)$($BOLD_WHITE)n$($RESET)$($YELLOW))$($RESET)"
if ([string]::IsNullOrWhiteSpace($confirmGlobalAccount)) { $confirmGlobalAccount = "y" } # Default to 'y'

if ($confirmGlobalAccount.ToLower() -eq "n") {
    # Call the function to handle btp target interaction
    Invoke-BTPTargetSelection

    # Get the global account info after targeting
    $globalAccountInfoRaw = try { & $btpCmd get accounts/global-account 2>&1 } catch { $_ }
    if ($LASTEXITCODE -ne 0) {
         Write-Host "  $($BOLD_RED)✗ Failed to get global account info after selection. Exiting.$($RESET)"
         exit 1
     }
    $global_subdomain = $globalAccountInfoRaw | Select-String -Pattern "display name:\s*(.+)" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
    $global_account_id_from_get = $globalAccountInfoRaw | Select-String -Pattern "ID:\s*([a-fA-F0-9-]+)" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }

    Write-Host ""
    Write-Host "  $($GREEN)Successfully targeted global account: $($BOLD_WHITE)$global_subdomain$($RESET)"
}
# else: Confirmed 'y' or default, continue


Write-Host ""
# Get available regions (original logic)
Write-Host "  $($CYAN)ℹ Fetching available regions...$($RESET)"
# Use $btpCmd
$regions_output_raw = try { & $btpCmd list accounts/available-region 2>&1 } catch { $_ }

if ($LASTEXITCODE -ne 0) {
     Write-Host ""
     Write-Host "  $($BOLD_RED)✗ Failed to list available regions. Exit Code: $LASTEXITCODE.$($RESET)"
     Write-Host "  $($RED)Output/Error: $($regions_output_raw -join "`n")$($RESET)"
     exit 1
}

# Extract global account ID from regions output (original logic)
$global_account_id = $regions_output_raw | Select-String -Pattern "global account\s+([a-zA-Z0-9-]+)" |
                     ForEach-Object { $_.Matches.Groups[1].Value } |
                     Select-Object -First 1

# Ensure we have an ID (using fallback if needed, as added before)
if (-not $global_account_id) {
    $global_account_id = $global_account_id_from_get
    if (-not $global_account_id) {
        Write-Host "$($BOLD_RED)  ERROR: Could not determine Global Account ID.$($RESET)"
        exit 1
    }
     Write-Host "$($BOLD_YELLOW)  WARN: Using Global Account ID ($global_account_id) from 'get accounts/global-account'.$($RESET)"
}


Write-Host ""
# Parse regions (original logic)
Write-Host "  $($BOLD_BLUE)Available regions:$($RESET)"
$regions = $regions_output_raw | Select-String -Pattern "^\w+\s+cf-" | ForEach-Object { $_.ToString().Trim().Split()[0] } | Sort-Object

if ($regions.Count -eq 0) {
     Write-Host ""
     Write-Host "  $($BOLD_RED)✗ No Cloud Foundry regions found or parsing failed.$($RESET)"
     exit 1
}

Write-Host ""
# Display regions with numbers
for ($i = 0; $i -lt $regions.Count; $i++) {
    Write-Host "  $($BOLD_CYAN)$($i+1)) $($regions[$i])$($RESET)"
}

# Get user selection (original logic)
Write-Host ""
$selection = Read-Host "  $($BOLD_MAGENTA)Select a region $($RESET)$($MAGENTA)($($RESET)$($BOLD_WHITE)1$($RESET)$($MAGENTA)-$($RESET)$($BOLD_WHITE)$($regions.Count)$($RESET)$($MAGENTA))$($RESET)"

# Validate selection (original logic)
if (-not ($selection -match "^\d+$") -or [int]$selection -lt 1 -or [int]$selection -gt $regions.Count) {
    Write-Host "  $($BOLD_RED)✗ Invalid selection. Exiting.$($RESET)"
    exit 1
}

# Get the selected region (original logic)
$selected_region = $regions[[int]$selection-1]

# Create a unique subdomain (original logic)
$timestamp = [int](Get-Date -UFormat %s)
$idPrefixLength = [System.Math]::Min(7, $global_account_id.Length) # Added safety check
$unique_subdomain = "trial-$($global_account_id.Substring(0,$idPrefixLength))-$timestamp"

Write-Host ""
$defaultSubName = "Trial"
# Original prompt logic
$subaccountDisplayName = Read-Host -Prompt "  $($BOLD_MAGENTA)Enter subaccount display name $($RESET)$($WHITE)[$($RESET)$($BOLD_WHITE)$defaultSubName$($RESET)$($WHITE)]$($RESET)"
if ([string]::IsNullOrWhiteSpace($subaccountDisplayName)) { $subaccountDisplayName = $defaultSubName }


#
# CREATE SUBACCOUNT (original logic)
#

Write-Host ""
Write-Host "  $($CYAN)Creating subaccount '$subaccountDisplayName'...$($RESET)" # Added name

$result = Start-ProcessingAnimation -Activity "  Creating subaccount" -ScriptBlock {
    # Use $btpCmd
    $subaccount_output_create = try {
        & $using:btpCmd create accounts/subaccount --display-name "$using:subaccountDisplayName" --region "$using:selected_region" --subdomain "$using:unique_subdomain" 2>&1
    } catch { $_ }

    return @{
        Output = $subaccount_output_create
        ExitCode = $LASTEXITCODE
    }
}

$subaccount_output = $result.Output # Keep original var name
$createSubaccountSuccess = ($result.ExitCode -eq 0)

Write-Host "" # Newline after animation
if (-not $createSubaccountSuccess) {
    Write-Host "  $($BOLD_RED)✗ Failed to create subaccount. Exit Code: $($result.ExitCode).$($RESET)"
    Write-Host "  $($RED)Error: $($subaccount_output -join "`n")$($RESET)"
    exit 1
}

# Extract the subaccount ID (original logic)
$subaccount_id = $subaccount_output |
                Select-String -Pattern "subaccount id:\s*(.+)" |
                ForEach-Object { $_.Line -replace "subaccount id:\s*", "" } # Original regex

# Verify ID (added fallback check)
if (-not $subaccount_id) {
     $subaccount_id = $subaccount_output | Select-String -Pattern "ID:\s*([a-fA-F0-9-]+)" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
     if (-not $subaccount_id) {
        Write-Host "  $($BOLD_RED)ERROR: Could not determine subaccount ID. Cannot proceed.$($RESET)"
        exit 1
     }
}
Write-Host "  $($BOLD_GREEN)✓ Subaccount created successfully. ID: $($BOLD_WHITE)$subaccount_id$($RESET)"


# Wait for subaccount state (original logic, using $btpCmd)
$attempt = 1
$max_attempts = 15
$subaccountReady = $false

Write-Host ""
Write-Host "  $($BOLD_CYAN)Waiting for subaccount '$subaccountDisplayName' to be ready...$($RESET)"
$initialPosition = $null
if ($Host.Name -eq 'ConsoleHost') { try { $initialPosition = $Host.UI.RawUI.CursorPosition } catch {} }

while ($attempt -le $max_attempts -and -not $subaccountReady) {
    # Use $btpCmd
    $get_subaccount_output = try { & $btpCmd get accounts/subaccount "$subaccount_id" 2>&1 } catch { $_ }
    $getExitCode = $LASTEXITCODE

    # Extract the state value (original logic, refined)
    $subaccount_state = $get_subaccount_output |
                        Select-String -Pattern "^\s*state:\s+(\w+)" -ErrorAction SilentlyContinue |
                        Where-Object { $_.Line -notmatch "state message:" } |
                        ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1

    if ([string]::IsNullOrEmpty($subaccount_state) -or $getExitCode -ne 0) { $subaccount_state = "PENDING" }

    if ($initialPosition) { try { $host.UI.RawUI.CursorPosition = $initialPosition } catch {} }

    $progressWidth = 15
    $filledWidth = [Math]::Min([Math]::Floor(($attempt / $max_attempts) * $progressWidth), $progressWidth)
    $emptyWidth = $progressWidth - $filledWidth
    $progressBar = "  $($BLUE)Checking state $($RESET)($($BOLD_BLUE)$attempt$($RESET)/$($BOLD_BLUE)$max_attempts$($RESET)): $($YELLOW)$subaccount_state$($RESET) [$($CYAN)$('#' * $filledWidth)$(' ' * $emptyWidth)$($RESET)]"

    $consoleWidth = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }
    Write-Host "`r$(' ' * ($consoleWidth - 1))" -NoNewline
    Write-Host "`r$progressBar" -NoNewline

    if ($subaccount_state -eq "OK") {
        $finalProgressBar = $progressBar
        if ($initialPosition) { try { $host.UI.RawUI.CursorPosition = $initialPosition } catch {} }
        Write-Host "`r$(' ' * ($consoleWidth - 1))" -NoNewline
        Write-Host "`r$finalProgressBar"
        Write-Host ""
        Write-Host "  $($BOLD_GREEN)✓ Subaccount is ready!$($RESET)"
        $subaccountReady = $true
        break
    } elseif ($subaccount_state -match "FAILED|UNKNOWN") {
         if ($initialPosition) { try { $host.UI.RawUI.CursorPosition = $initialPosition } catch {} }
        Write-Host "`r$(' ' * ($consoleWidth - 1))" -NoNewline
        Write-Host "`r$progressBar"
        Write-Host ""
        Write-Host "  $($BOLD_RED)✗ Subaccount entered state: $subaccount_state. Cannot proceed.$($RESET)"
        exit 1
    }

    if ($attempt -ge $max_attempts) {
        $finalProgressBar = $progressBar
         if ($initialPosition) { try { $host.UI.RawUI.CursorPosition = $initialPosition } catch {} }
        Write-Host "`r$(' ' * ($consoleWidth - 1))" -NoNewline
        Write-Host "`r$finalProgressBar"
        Write-Host ""
        Write-Host "  $($BOLD_RED)✗ Subaccount did not become ready within the timeout. Last state: $subaccount_state.$($RESET)"
        exit 1
    }

    Start-Sleep -Seconds 3
    $attempt++
}

# Target the subaccount (original logic, using $btpCmd)
Write-Host ""
Write-Host "  $($CYAN)Targeting subaccount '$subaccountDisplayName'...$($RESET)"

$result = Start-ProcessingAnimation -Activity "  Targeting subaccount $subaccount_id" -ScriptBlock {
    # Use $btpCmd
    $outputTarget = try { & $using:btpCmd target --subaccount "$using:subaccount_id" 2>&1 } catch { $_ }
    return @{ Output = $outputTarget; ExitCode = $LASTEXITCODE }
}

Write-Host "" # Newline after animation
if ($result.ExitCode -ne 0) {
    Write-Host "  $($BOLD_RED)✗ Failed to target subaccount. Exit Code: $($result.ExitCode).$($RESET)"
    Write-Host "  $($RED)Error: $($result.Output -join "`n")$($RESET)"
    exit 1
}
Write-Host "  $($BOLD_GREEN)✓ Successfully targeted subaccount.$($RESET)"


#
# CREATE & ENABLE CLOUD FOUNDRY ENVIRONMENT (original logic, using $btpCmd)
#

Write-Host ""
Write-Host "  $($CYAN)Enabling Cloud Foundry environment...$($RESET)"

$result = Start-ProcessingAnimation -Activity "  Enabling Cloud Foundry" -ScriptBlock {
    # Use $btpCmd, ConvertTo-Json for params
    $cfParamsObject = @{
        instance_name = "${using:unique_subdomain}_Trial"
        org_name      = "${using:global_subdomain}_${using:unique_subdomain}"
    }
    $cfParamsJson = $cfParamsObject | ConvertTo-Json -Compress

    $cf_creation_output = try {
        & $using:btpCmd create accounts/environment-instance --subaccount "$using:subaccount_id" --environment "cloudfoundry" --service "cloudfoundry" --plan "trial" --display-name "${using:unique_subdomain}_Trial" --parameters $cfParamsJson 2>&1
     } catch { $_ }
    return @{ Output = $cf_creation_output; ExitCode = $LASTEXITCODE }
}

$cf_creation_output = $result.Output
$cfEnableSuccess = ($result.ExitCode -eq 0)

Write-Host "" # Newline after animation
if (-not $cfEnableSuccess) {
    Write-Host "  $($BOLD_RED)✗ Failed to enable Cloud Foundry environment. Exit Code: $($result.ExitCode).$($RESET)"
    Write-Host "  $($RED)Error: $($cf_creation_output -join "`n")$($RESET)"
    exit 1
}

# Extract the environment ID (original logic)
$cf_env_id = $cf_creation_output |
             Select-String -Pattern "environment id:\s*(.+)" |
             ForEach-Object { $_.Line -replace "environment id:\s*", "" } # Original regex

# Verify ID (added fallback)
if (-not $cf_env_id) {
     $cf_env_id = $cf_creation_output | Select-String -Pattern "ID:\s*([a-fA-F0-9-]+)" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
     if (-not $cf_env_id) {
         Write-Host "  $($BOLD_RED)ERROR: Could not determine CF environment ID. Cannot proceed.$($RESET)"
         exit 1
     }
}
Write-Host "  $($BOLD_GREEN)✓ Cloud Foundry environment creation initiated. ID: $($BOLD_WHITE)$cf_env_id$($RESET)"


# Wait for CF environment (original logic, using $btpCmd)
Write-Host ""
Write-Host "  $($BOLD_CYAN)Waiting for Cloud Foundry environment ($cf_env_id) to be ready...$($RESET)"
if ($Host.Name -eq 'ConsoleHost') { try { $initialPosition = $Host.UI.RawUI.CursorPosition } catch {} } else { $initialPosition = $null }

$cfReady = $false
$attempt = 1
$max_attempts = 25 # Keep longer timeout

while ($attempt -le $max_attempts -and -not $cfReady) {
    # Use $btpCmd
    $get_cf_env_output = try { & $btpCmd get accounts/environment-instance $cf_env_id --subaccount "$subaccount_id" 2>&1 } catch { $_ }
    $getCFExitCode = $LASTEXITCODE

    # Extract state (original logic, refined)
    $cf_env_state = $get_cf_env_output |
                    Select-String -Pattern "^\s*state:\s+(\w+)" -ErrorAction SilentlyContinue |
                    Where-Object { $_.Line -notmatch "state message:" } |
                    ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1

    if ([string]::IsNullOrEmpty($cf_env_state) -or $getCFExitCode -ne 0) { $cf_env_state = "PENDING" }

    if ($initialPosition) { try { $host.UI.RawUI.CursorPosition = $initialPosition } catch {} }

    $progressWidth = 15
    $filledWidth = [Math]::Min([Math]::Floor(($attempt / $max_attempts) * $progressWidth), $progressWidth)
    $emptyWidth = $progressWidth - $filledWidth
    $progressBar = "  $($BLUE)Checking CF state $($RESET)($($BOLD_BLUE)$attempt$($RESET)/$($BOLD_BLUE)$max_attempts$($RESET)): $($YELLOW)$cf_env_state$($RESET) [$($CYAN)$('#' * $filledWidth)$(' ' * $emptyWidth)$($RESET)]"

    $consoleWidth = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }
    Write-Host "`r$(' ' * ($consoleWidth - 1))" -NoNewline
    Write-Host "`r$progressBar" -NoNewline

    if ($cf_env_state -eq "OK") {
        $finalProgressBar = $progressBar
        if ($initialPosition) { try { $host.UI.RawUI.CursorPosition = $initialPosition } catch {} }
        Write-Host "`r$(' ' * ($consoleWidth - 1))" -NoNewline
        Write-Host "`r$finalProgressBar"
        Write-Host ""
        Write-Host "  $($BOLD_GREEN)✓ Cloud Foundry environment is ready!$($RESET)"
        $cfReady = $true
        break
    } elseif ($cf_env_state -match "FAILED|UNKNOWN") {
         if ($initialPosition) { try { $host.UI.RawUI.CursorPosition = $initialPosition } catch {} }
        Write-Host "`r$(' ' * ($consoleWidth - 1))" -NoNewline
        Write-Host "`r$progressBar"
        Write-Host ""
        Write-Host "  $($BOLD_RED)✗ Cloud Foundry environment state: $cf_env_state. Cannot proceed.$($RESET)"
        exit 1
    }

    if ($attempt -ge $max_attempts) {
        $finalProgressBar = $progressBar
        if ($initialPosition) { try { $host.UI.RawUI.CursorPosition = $initialPosition } catch {} }
        Write-Host "`r$(' ' * ($consoleWidth - 1))" -NoNewline
        Write-Host "`r$finalProgressBar"
        Write-Host ""
        Write-Host "  $($BOLD_RED)✗ Cloud Foundry environment did not become ready within timeout. Last state: $cf_env_state.$($RESET)"
        exit 1
    }

    Start-Sleep -Seconds 3
    $attempt++
}

# Get CF details (original logic, using $btpCmd)
$cf_details_output = try { & $btpCmd get accounts/environment-instance $cf_env_id --subaccount $subaccount_id 2>&1 } catch { $_ }
if ($LASTEXITCODE -ne 0) {
     Write-Host "$($BOLD_YELLOW)  WARN: Could not get final CF environment details.$($RESET)"
     $cf_api_endpoint = $null
     $cf_org_name = $null
} else {
    # Original regex parsing
    $cf_api_endpoint = $cf_details_output | Select-String -Pattern '"API Endpoint"\s*:\s*"([^"]+)"' | ForEach-Object { $_.Matches.Groups[1].Value }
    $cf_org_name = $cf_details_output | Select-String -Pattern '"Org Name"\s*:\s*"([^"]+)"' | ForEach-Object { $_.Matches.Groups[1].Value }
}

if (-not $cf_api_endpoint -or -not $cf_org_name) {
     Write-Host "$($BOLD_RED)  ERROR: Failed to parse CF API Endpoint or Org Name. Cannot proceed.$($RESET)"
     exit 1
}
Write-Host "  $($CYAN)CF API Endpoint: $($BOLD_WHITE)$cf_api_endpoint$($RESET)"
Write-Host "  $($CYAN)CF Org Name:     $($BOLD_WHITE)$cf_org_name$($RESET)"


# Log in to CF (original logic, using $cfCmd)
Write-Host ""
Write-Host "  $($CYAN)Logging in to Cloud Foundry...$($RESET)"

$result = Start-ProcessingAnimation -Activity "  Logging in to Cloud Foundry" -ScriptBlock {
    # Use $cfCmd
    $outputCFLogin = try { & $using:cfCmd login -a "$using:cf_api_endpoint" -u "$using:userid" -p "$using:passw" -o "$using:cf_org_name" 2>&1 } catch { $_ }
    return @{ Output = $outputCFLogin; ExitCode = $LASTEXITCODE }
}

Write-Host "" # Newline after animation
if ($result.ExitCode -ne 0) {
    Write-Host "  $($BOLD_RED)✗ CF Login failed. Exit Code: $($result.ExitCode).$($RESET)"
    Write-Host "  $($RED)Error/Output: $($result.Output -join "`n")$($RESET)"
    Write-Host "  $($YELLOW)If using SSO, log in manually first (`$($cfCmd) login ... --sso`).$($RESET)"
    exit 1
} else {
    Write-Host "  $($BOLD_GREEN)✓ CF Login successful!$($RESET)"
}

# Create CF space (original logic, using $cfCmd)
$cfSpaceName = "dev"
Write-Host ""
Write-Host "  $($BOLD_CYAN)Creating Cloud Foundry space ('$cfSpaceName')...$($RESET)"

$result = Start-ProcessingAnimation -Activity "  Creating Cloud Foundry space '$cfSpaceName'" -ScriptBlock {
    # Use $cfCmd
    $outputCFSpace = try { & $using:cfCmd create-space $using:cfSpaceName 2>&1 } catch { $_ }
    return @{ Output = $outputCFSpace; ExitCode = $LASTEXITCODE }
}

Write-Host "" # Newline after animation
if ($result.ExitCode -eq 0) {
    Write-Host "  $($BOLD_GREEN)✓ Cloud Foundry space '$cfSpaceName' created!$($RESET)"
} elseif ($result.ExitCode -ne 0 -and $result.Output -join ' ' -match 'already exists') {
     Write-Host "  $($BOLD_YELLOW)⚠ Cloud Foundry space '$cfSpaceName' already exists.$($RESET)"
     $result.ExitCode = 0 # Allow workflow to continue
} else {
    Write-Host "  $($BOLD_RED)✗ Failed to create Cloud Foundry space '$cfSpaceName'. Exit Code: $($result.ExitCode).$($RESET)"
    Write-Host "  $($RED)Error: $($result.Output -join "`n")$($RESET)"
    exit 1
}

# Target CF space (original logic, using $cfCmd)
if ($result.ExitCode -eq 0) { # Only target if create/exists succeeded
    Write-Host ""
    Write-Host "  $($BOLD_CYAN)Targeting Cloud Foundry space ('$cfSpaceName')...$($RESET)"

    $result = Start-ProcessingAnimation -Activity "  Targeting Cloud Foundry space '$cfSpaceName'" -ScriptBlock {
        # Use $cfCmd
        $outputCFTarget = try { & $using:cfCmd target -s $using:cfSpaceName 2>&1 } catch { $_ }
        return @{ Output = $outputCFTarget; ExitCode = $LASTEXITCODE }
    }

    Write-Host "" # Newline after animation
    if ($result.ExitCode -ne 0) {
        Write-Host "  $($BOLD_RED)✗ Failed to target Cloud Foundry space '$cfSpaceName'. Exit Code: $($result.ExitCode).$($RESET)"
        Write-Host "  $($RED)Error: $($result.Output -join "`n")$($RESET)"
        exit 1
    } else {
        Write-Host "  $($BOLD_GREEN)✓ Cloud Foundry space '$cfSpaceName' targeted!$($RESET)"
    }
}


#
# ENABLE SERVICE PLANS (original logic, using $btpCmd)
#

Write-Host ""
Write-Host "  $($BOLD_BLUE)=== Adding All Required Service Plans ===$($RESET)"
Write-Host ""

$service_plans_enable = @("it-rt integration-flow", "it-rt api", "sapappstudiotrial trial")
$service_plans_amount = @("integrationsuite-trial trial", "sap-build-apps free")

foreach ($service_plan in $service_plans_amount) {
  $service, $plan = $service_plan.Split(" ")
  Write-Host "  $($CYAN)Adding entitlement for $service ($plan plan)...$($RESET)"
  $result = Start-ProcessingAnimation -Activity "  Adding entitlement for $service ($plan plan)" -ScriptBlock {
    # Use $btpCmd
    $outputAssignAmount = try { & $using:btpCmd assign accounts/entitlement --to-subaccount $using:subaccount_id --for-service $using:service --plan $using:plan --amount 1 2>&1 } catch { $_ }
    return @{ Output = $outputAssignAmount; ExitCode = $LASTEXITCODE }
  }
  Write-Host "" # Newline
  if ($result.ExitCode -eq 0) { Write-Host "  $($BOLD_GREEN)✓ Added entitlement for $service ($plan plan)!$($RESET)" }
  elseif ($result.ExitCode -ne 0 -and ($result.Output -join ' ' -match 'Quota is already sufficient' -or $result.Output -join ' ' -match 'Entitlement is already assigned')) { Write-Host "  $($BOLD_YELLOW)⚠ Entitlement for $service ($plan plan) already sufficient/assigned.$($RESET)" }
  else { Write-Host "  $($BOLD_RED)✗ Failed to add entitlement for $service ($plan plan). Error: $($result.Output -join "`n")$($RESET)" }
  Write-Host ""
}

Write-Host ""
foreach ($service_plan in $service_plans_enable) {
  $service, $plan = $service_plan.Split(" ")
  Write-Host "  $($CYAN)Adding entitlement for $service ($plan plan)...$($RESET)"
  $result = Start-ProcessingAnimation -Activity "  Adding entitlement for $service ($plan plan)" -ScriptBlock {
    # Use $btpCmd
    $outputAssignEnable = try { & $using:btpCmd assign accounts/entitlement --to-subaccount $using:subaccount_id --for-service $using:service --plan $using:plan --enable 2>&1 } catch { $_ }
    return @{ Output = $outputAssignEnable; ExitCode = $LASTEXITCODE }
  }
  Write-Host "" # Newline
  if ($result.ExitCode -eq 0) { Write-Host "  $($BOLD_GREEN)✓ Added entitlement for $service ($plan plan)!$($RESET)" }
  elseif ($result.ExitCode -ne 0 -and $result.Output -join ' ' -match 'Entitlement is already assigned') { Write-Host "  $($BOLD_YELLOW)⚠ Entitlement for $service ($plan plan) already assigned.$($RESET)" }
  else { Write-Host "  $($BOLD_RED)✗ Failed to add entitlement for $service ($plan plan). Error: $($result.Output -join "`n")$($RESET)" }
  Write-Host ""
}

Write-Host ""
Write-Host "  $($BOLD_GREEN)✓ All service plans have been added to the subaccount!$($RESET)"


#
# CREATE SERVICE INSTANCES & SUBSCRIPTIONS (original logic, using $btpCmd)
#

Write-Host ""
Write-Host "  $($BOLD_BLUE)=== Creating Services ===$($RESET)"

# Get subscription list (original logic)
# Use $btpCmd
$subscriptions_json_raw = try { & $btpCmd --format json list accounts/subscription --subaccount "$subaccount_id" 2>&1 } catch { $_ }
if ($LASTEXITCODE -ne 0) {
     Write-Host "  $($BOLD_RED)✗ Failed to list available subscriptions.$($RESET)"
     exit 1
}
$subscriptions_json = $subscriptions_json_raw -join "`n"
$subscriptions = $null
try { $subscriptions = $subscriptions_json | ConvertFrom-Json -ErrorAction Stop } catch {}
if (-not $subscriptions -or -not $subscriptions.PSObject.Properties.Name -contains 'applications') {
     Write-Host "  $($BOLD_RED)✗ Failed to parse subscriptions list JSON.$($RESET)"
     exit 1
}
$integration_subscription = $subscriptions.applications | Where-Object { $_.commercialAppName -eq "integrationsuite-trial" } | Select-Object -First 1
if (-not $integration_subscription) {
     Write-Host "  $($BOLD_RED)✗ Could not find 'integrationsuite-trial' application.$($RESET)"
     exit 1
}
$integration_appname = $integration_subscription.appName
$integration_plan_subscribe = "trial" # Keep consistent

Write-Host ""
Write-Host "  $($CYAN)Creating Integration Suite subscription ('$integration_appname')...$($RESET)" # Simplified msg
$result = Start-ProcessingAnimation -Activity "  Creating Integration Suite subscription" -ScriptBlock {
    # Use $btpCmd
    $outputSubscribe = try { & $using:btpCmd subscribe accounts/subaccount --subaccount $using:subaccount_id --to-app $using:integration_appname --plan $using:integration_plan_subscribe 2>&1 } catch { $_ }
    return @{ Output = $outputSubscribe; ExitCode = $LASTEXITCODE }
}

Write-Host "" # Newline
if ($result.ExitCode -eq 0) { Write-Host "  $($BOLD_GREEN)✓ Integration Suite subscription initiated!$($RESET)" }
elseif ($result.ExitCode -ne 0 -and ($result.Output -join ' ' -match 'is already subscribed')) {
     Write-Host "  $($BOLD_YELLOW)⚠ Already subscribed. Checking status...$($RESET)"
     $result.ExitCode = 0 # Allow poll
} else {
    Write-Host "  $($BOLD_RED)✗ Failed to subscribe. Error: $($result.Output -join "`n")$($RESET)"
    exit 1
}

# Poll subscription status (original logic, using $btpCmd)
Write-Host ""
Write-Host "  $($BOLD_CYAN)Waiting for Integration Suite subscription ('$integration_appname') to be ready...$($RESET)"
if ($Host.Name -eq 'ConsoleHost') { try { $initialPosition = $Host.UI.RawUI.CursorPosition } catch {} } else { $initialPosition = $null }

$attempt = 1
$max_attempts = 20
$subscriptionReady = $false
$integration_suite_url = $null

while ($attempt -le $max_attempts -and -not $subscriptionReady) {
    # Use $btpCmd
    $current_subscriptions_json_raw = try { & $btpCmd --format json list accounts/subscription --subaccount "$subaccount_id" 2>&1 } catch { $_ }
    $getListExitCode = $LASTEXITCODE
    $subscription_state = "PENDING"
    $stateMsg = ""

    if ($getListExitCode -eq 0) {
        $current_subscriptions_json = $current_subscriptions_json_raw -join "`n"
        try {
            $currentSubscriptions = $current_subscriptions_json | ConvertFrom-Json -ErrorAction Stop
            if ($currentSubscriptions -and $currentSubscriptions.PSObject.Properties.Name -contains 'applications') {
                $current_integration_subscription = $currentSubscriptions.applications | Where-Object { $_.appName -eq $integration_appname } | Select-Object -First 1
                if ($current_integration_subscription) {
                    $subscription_state = $current_integration_subscription.state
                    $stateMsg = $current_integration_subscription.stateMessage
                    $integration_suite_url = $current_integration_subscription.subscriptionUrl
                } else { $stateMsg = "Not found yet." }
            } else { $stateMsg = "Parse error." }
        } catch { $stateMsg = "JSON Error: $($_.Exception.Message)" }
    } else { $stateMsg = "Fetch Error (Code: $getListExitCode)" }

    if ($initialPosition) { try { $host.UI.RawUI.CursorPosition = $initialPosition } catch {} }
    $progressWidth = 15
    $filledWidth = [Math]::Min([Math]::Floor(($attempt / $max_attempts) * $progressWidth), $progressWidth)
    $emptyWidth = $progressWidth - $filledWidth
    $progressBar = "  $($BLUE)Checking subscription $($RESET)($($BOLD_BLUE)$attempt$($RESET)/$($BOLD_BLUE)$max_attempts$($RESET)): $($YELLOW)$subscription_state$($RESET) [$($CYAN)$('#' * $filledWidth)$(' ' * $emptyWidth)$($RESET)]"
    if (-not [string]::IsNullOrWhiteSpace($stateMsg)) { $progressBar += " ($($YELLOW)$stateMsg$($RESET))" }

    $consoleWidth = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }
    Write-Host "`r$(' ' * ($consoleWidth - 1))" -NoNewline
    Write-Host "`r$progressBar" -NoNewline

    if ($subscription_state -eq "SUBSCRIBED") {
        $finalProgressBar = $progressBar
        if ($initialPosition) { try { $host.UI.RawUI.CursorPosition = $initialPosition } catch {} }
        Write-Host "`r$(' ' * ($consoleWidth - 1))" -NoNewline
        Write-Host "`r$finalProgressBar"
        Write-Host ""
        Write-Host "  $($BOLD_GREEN)✓ Integration Suite subscription ($($BOLD_BLUE)$integration_appname$($RESET)$($BOLD_GREEN)) is ready!$($RESET)"
        $subscriptionReady = $true
        if (-not $integration_suite_url) { Write-Host "  $($BOLD_YELLOW)⚠ Could not retrieve the Integration Suite URL.$($RESET)" }
        break
    } elseif ($subscription_state -match "FAILED|UNSUBSCRIBING|UNKNOWN") {
        if ($initialPosition) { try { $host.UI.RawUI.CursorPosition = $initialPosition } catch {} }
        Write-Host "`r$(' ' * ($consoleWidth - 1))" -NoNewline
        Write-Host "`r$progressBar"
        Write-Host ""
        Write-Host "  $($BOLD_RED)✗ Subscription failed/unexpected state: $subscription_state. Msg: $stateMsg$($RESET)"
        exit 1
    }

    if ($attempt -ge $max_attempts) {
        $finalProgressBar = $progressBar
        if ($initialPosition) { try { $host.UI.RawUI.CursorPosition = $initialPosition } catch {} }
        Write-Host "`r$(' ' * ($consoleWidth - 1))" -NoNewline
        Write-Host "`r$finalProgressBar"
        Write-Host ""
        Write-Host "  $($BOLD_RED)✗ Subscription did not become ready within timeout. Last state: $subscription_state.$($RESET)"
        exit 1
    }
    Start-Sleep -Seconds 3
    $attempt++
}


#
# ASSIGN INTEGRATION PROVISIONER ROLE (original logic, using $btpCmd)
#

$provisionerRoleName = "Integration_Provisioner"
Write-Host ""
Write-Host "  $($CYAN)Assigning $($BOLD_WHITE)$provisionerRoleName$($RESET) $($CYAN)Role...$($RESET)"
     $result = Start-ProcessingAnimation -Activity "  Assigning Integration Provisioner role" -ScriptBlock {
         # Use $btpCmd
         $outputAssignProv = try { & $using:btpCmd assign security/role-collection $using:provisionerRoleName --to-user "$using:userid" --subaccount "$using:subaccount_id" 2>&1 } catch { $_ }
        return @{ Output = $outputAssignProv; ExitCode = $LASTEXITCODE }
    }
    Write-Host "" # Newline
    if ($result.ExitCode -eq 0) { Write-Host "  $($BOLD_GREEN)✓ Role$($RESET) $($BOLD_BLUE)$provisionerRoleName$($RESET) $($BOLD_GREEN)assigned successfully!$($RESET)" }
    elseif ($result.ExitCode -ne 0 -and $result.Output -join ' ' -match 'is already assigned') { Write-Host "  $($BOLD_YELLOW)⚠ Role '$provisionerRoleName' already assigned.$($RESET)" }
    else { Write-Host "  $($BOLD_RED)✗ Could not assign Integration Provisioner role. Error: $($result.Output -join "`n")$($RESET)" }


#
# WAIT FOR MANUAL ACTIVATION (original logic)
#

# URL should be in $integration_suite_url from poll loop

Write-Host ""
Write-Host "  $($BOLD_GREEN)✓ Integration Suite subscription is active!$($RESET)" # Adjusted msg
Write-Host ""
Write-Host "  $($BOLD_YELLOW)⚠ Manual Activation Required ⚠$($RESET)"
Write-Host ""
if ($integration_suite_url) { Write-Host "  $($YELLOW)1. Access your Integration Suite at: $($BOLD_WHITE)$integration_suite_url$($RESET)" }
else { Write-Host "  $($YELLOW)1. Access Integration Suite via BTP Cockpit (URL not retrieved).$($RESET)" }
Write-Host "  $($YELLOW)2. Log in with user: $($BOLD_WHITE)$userid$($RESET)"
Write-Host "  $($YELLOW)3. Open '$($BOLD_WHITE)Capabilities$($RESET)$($YELLOW)' window ('$($RESET)$($WHITE)Add Capabilities$($RESET)$($YELLOW)').$($RESET)"
Write-Host "  $($YELLOW)4. Activate '$($BOLD_WHITE)Cloud Integration$($RESET)$($YELLOW)' ('$($RESET)$($WHITE)Build Integration Scenarios$($RESET)$($YELLOW)'). $($BOLD_RED)REQUIRED$($RESET)$($YELLOW).$($RESET)"
Write-Host "  $($YELLOW)5. Optionally activate others.$($RESET)"
Write-Host "  $($YELLOW)6. Wait for status '$($GREEN_BG)$($BOLD_WHITE) Active $($RESET)$($YELLOW)'. $($RESET)" # Keep space around Active
Write-Host "  $($YELLOW)7. Return here and press '$($BOLD_WHITE)y$($RESET)' to continue.$($RESET)"

Write-Host ""
$confirmation = Get-Confirmation -Message "  Have you completed the Cloud Integration capability activation?"
if (-not $confirmation) {
    Write-Host "" # Newline
    Write-Host "  $($BOLD_RED)✗ Cloud Integration activation is required. Exiting.$($RESET)"
    exit 1
}
Write-Host "  $($CYAN)Continuing script...$($RESET)"


#
# CREATE PI RUNTIME SERVICE INSTANCES (original logic, using $cfCmd)
#

$piRuntimeInstanceNameIF = "pi-runtime"
$piRuntimeServiceType = "it-rt"
$piRuntimePlanIF = "integration-flow"
$piRuntimeInstanceNameApi = "pi-runtime-api"
$piRuntimePlanApi = "api"
$apiParamsJsonString = '{"roles": ["AuthGroup_Administrator", "AuthGroup_IntegrationDeveloper", "AuthGroup_BusinessExpert", "AuthGroup_ContentPublisher", "AuthGroup_TenantPartnerDirectoryConfigurator"], "grant-types": ["client_credentials"], "redirect-uris": [], "token-validity": 43200}'


Write-Host ""
Write-Host "  $($CYAN)Creating Process Integration Runtime instance (integration-flow plan)...$($RESET)"
$result = Start-ProcessingAnimation -Activity "  Creating Process Integration Runtime instance (integration-flow plan)" -ScriptBlock {
  # Use $cfCmd
  $outputCreateIF = try { & $using:cfCmd create-service $using:piRuntimeServiceType $using:piRuntimePlanIF $using:piRuntimeInstanceNameIF 2>&1 } catch { $_ }
  return @{ Output = $outputCreateIF; ExitCode = $LASTEXITCODE }
}
Write-Host "" # Newline
if ($result.ExitCode -eq 0) { Write-Host "  $($BOLD_GREEN)✓ Process Integration Runtime IF instance created!$($RESET)" }
elseif ($result.ExitCode -ne 0 -and $result.Output -join ' ' -match 'already exists') { Write-Host "  $($BOLD_YELLOW)⚠ Instance '$piRuntimeInstanceNameIF' already exists.$($RESET)" }
else { Write-Host "  $($BOLD_RED)✗ Failed to create Process Integration Runtime IF instance. Error: $($result.Output -join "`n")$($RESET)" }

Write-Host ""
Write-Host "  $($CYAN)Creating Process Integration Runtime API instance...$($RESET)"
$result = Start-ProcessingAnimation -Activity "  Creating Process Integration Runtime API instance" -ScriptBlock {
    # Use $cfCmd
    $outputCreateApi = try { & $using:cfCmd create-service $using:piRuntimeServiceType $using:piRuntimePlanApi $using:piRuntimeInstanceNameApi -c $using:apiParamsJsonString 2>&1 } catch { $_ }
    return @{ Output = $outputCreateApi; ExitCode = $LASTEXITCODE }
}
Write-Host "" # Newline
if ($result.ExitCode -eq 0) { Write-Host "  $($BOLD_GREEN)✓ Process Integration Runtime API instance created!$($RESET)" }
elseif ($result.ExitCode -ne 0 -and $result.Output -join ' ' -match 'already exists') { Write-Host "  $($BOLD_YELLOW)⚠ Instance '$piRuntimeInstanceNameApi' already exists.$($RESET)" }
else { Write-Host "  $($BOLD_RED)✗ Failed to create Process Integration Runtime API instance. Error: $($result.Output -join "`n")$($RESET)" }


#
# ASSIGN REMAINING ROLES (original logic, using $btpCmd)
#

Write-Host ""
Write-Host "  $($CYAN)Listing all new role collections and assigning them to user '$userid'...$($RESET)"

# Get roles (original logic)
$roleCollectionsJsonRaw = try { & $btpCmd --format json list security/role-collection --subaccount "$subaccount_id" 2>&1 } catch { $_ }
$getRolesExitCode = $LASTEXITCODE
$role_names = @()
if ($getRolesExitCode -eq 0) {
    $roleCollectionsJson = $roleCollectionsJsonRaw -join "`n"
    try {
        $roleCollections = $roleCollectionsJson | ConvertFrom-Json -ErrorAction Stop
        $rolesList = if ($roleCollections.PSObject.Properties.Name -contains 'value') { $roleCollections.value } else { $roleCollections }
        if ($rolesList) { $role_names = $rolesList | ForEach-Object { $_.name } }
    } catch {}
} else { Write-Host "  $($BOLD_RED)✗ Error listing role collections.$($RESET)" }

if ($role_names.Count -eq 0) { Write-Host "  $($BOLD_YELLOW)⚠ No role collections found/retrieved.$($RESET)" }
else {
    Write-Host "  $($CYAN)Assigning $($role_names.Count) roles...$($RESET)"
    foreach ($role in $role_names) {
        Write-Host ""
        Write-Host "  $($CYAN)Assigning role: $($RESET)$($BOLD_WHITE)$role$($RESET)"
        $result = Start-ProcessingAnimation -Activity "  Assigning role: $role" -ScriptBlock {
            # Use $btpCmd
            $outputAssignRole = try { & $using:btpCmd assign security/role-collection "$using:role" --to-user "$using:userid" --subaccount "$using:subaccount_id" 2>&1 } catch { $_ }
            return @{ Output = $outputAssignRole; ExitCode = $LASTEXITCODE }
        }
        Write-Host "" # Newline
        if ($result.ExitCode -eq 0) { Write-Host "  $($BOLD_GREEN)✓ Role '$($role)' assigned successfully!$($RESET)" }
        elseif ($result.ExitCode -ne 0 -and $result.Output -join ' ' -match 'is already assigned') { Write-Host "  $($BOLD_YELLOW)⚠ Role '$($role)' already assigned.$($RESET)" }
        else { Write-Host "  $($BOLD_RED)✗ Could not assign role: '$role'. Error: $($result.Output -join "`n")$($RESET)" }
    }
    Write-Host ""
    Write-Host "  $($BOLD_GREEN)✓ Role assignment loop finished.$($RESET)"
}

# Get final roles list for summary (original logic)
# Use $btpCmd
$finalRolesListRaw = try { & $btpCmd --format json list security/role-collection --subaccount "$subaccount_id" 2>&1 } catch { $_ }
$finalRolesList = @("  (Error retrieving final roles)")
if ($LASTEXITCODE -eq 0) {
    try {
        $finalRcJson = $finalRolesListRaw -join "`n"
        $finalRc = $finalRcJson | ConvertFrom-Json -ErrorAction Stop
        $finalRcData = if ($finalRc.PSObject.Properties.Name -contains 'value') { $finalRc.value } else { $finalRc }
        if ($finalRcData) { $finalRolesList = $finalRcData | ForEach-Object { "  $($_.name)" } }
        else { $finalRolesList = @("  (Could not parse final roles list)") }
    } catch { $finalRolesList = @("  (Error parsing final roles list: $($_.Exception.Message))") }
}


#
# CREATE SERVICE KEY (original logic, using $cfCmd)
#

$serviceKeyInstanceName = $piRuntimeInstanceNameIF # Key for pi-runtime
$serviceKeyName = "pi-runtime-key"

Write-Host ""
Write-Host "  $($CYAN)Creating IF service key '$serviceKeyName'...$($RESET)" # Add name
$result = Start-ProcessingAnimation -Activity "  Creating IF service key '$serviceKeyName'" -ScriptBlock {
  # Use $cfCmd
  $outputCreateKey = try { & $using:cfCmd create-service-key $using:serviceKeyInstanceName $using:serviceKeyName 2>&1 } catch { $_ }
  return @{ Output = $outputCreateKey; ExitCode = $LASTEXITCODE }
}
Write-Host "" # Newline
if ($result.ExitCode -eq 0) { Write-Host "  $($BOLD_GREEN)✓ IF Service key created!$($RESET)" }
elseif ($result.ExitCode -ne 0 -and $result.Output -join ' ' -match 'already exists') { Write-Host "  $($BOLD_YELLOW)⚠ Service key '$serviceKeyName' already exists.$($RESET)" }
else { Write-Host "  $($BOLD_RED)✗ Failed to create IF service key. Error: $($result.Output -join "`n")$($RESET)" }

# Fetch service key details (original logic, using $cfCmd)
Write-Host ""
$tokenurl = $null
$clientid = $null
$clientsecret = $null

$result = Start-ProcessingAnimation -Activity "  Fetching IF service key details" -ScriptBlock {
    # Use $cfCmd
    $serviceKeyOutputRaw = try { & $using:cfCmd service-key $using:serviceKeyInstanceName $using:serviceKeyName 2>&1 } catch { $_ }
    $fetchExitCode = $LASTEXITCODE
    $keyData = @{ ExitCode = $fetchExitCode; Output = $serviceKeyOutputRaw }

    if ($fetchExitCode -eq 0) {
        $serviceKeyOutputString = $serviceKeyOutputRaw -join "`n"
        $jsonStartIndex = $serviceKeyOutputString.IndexOf('{')
        if ($jsonStartIndex -ge 0) {
            $jsonPart = $serviceKeyOutputString.Substring($jsonStartIndex)
            try {
                $keyJson = $jsonPart | ConvertFrom-Json -ErrorAction Stop
                if ($keyJson -and $keyJson.PSObject.Properties.Name -contains 'credentials') {
                    $keyData['TokenUrl'] = $keyJson.credentials.tokenurl
                    $keyData['ClientId'] = $keyJson.credentials.clientid
                    $keyData['ClientSecret'] = $keyJson.credentials.clientsecret
                }
            } catch { # Fallback Regex if JSON parse fails
                 if ($serviceKeyOutputString -match '"tokenurl"\s*:\s*"([^"]+)"') { $keyData['TokenUrl'] = $Matches[1] }
                 if ($serviceKeyOutputString -match '"clientid"\s*:\s*"([^"]+)"') { $keyData['ClientId'] = $Matches[1] }
                 if ($serviceKeyOutputString -match '"clientsecret"\s*:\s*"([^"]+)"') { $keyData['ClientSecret'] = $Matches[1] }
            }
        } else { # Fallback Regex if no JSON start found
             if ($serviceKeyOutputString -match '"tokenurl"\s*:\s*"([^"]+)"') { $keyData['TokenUrl'] = $Matches[1] }
             if ($serviceKeyOutputString -match '"clientid"\s*:\s*"([^"]+)"') { $keyData['ClientId'] = $Matches[1] }
             if ($serviceKeyOutputString -match '"clientsecret"\s*:\s*"([^"]+)"') { $keyData['ClientSecret'] = $Matches[1] }
        }
    }
    return $keyData
}
Write-Host "" # Newline
if ($result.ExitCode -eq 0) {
    $tokenurl = $result.TokenUrl
    $clientid = $result.ClientId
    $clientsecret = $result.ClientSecret
    # Original didn't explicitly print these, summary did
} else {
     Write-Host "  $($BOLD_RED)✗ Failed to fetch service key '$serviceKeyName'. Error: $($result.Output -join "`n")$($RESET)"
}


#
# END OF SCRIPT & GREETER (original summary)
#

# Final summary (Original structure - corrected the $null check syntax from previous attempt)
Write-Host ""
Write-Host "  $($BOLD_GREEN)✅ Setup completed successfully! ✅$($RESET)"
Write-Host ""
Write-Host "  $($BOLD_CYAN)Summary:$($RESET)"
Write-Host "  $($CYAN)- User Assigned:           $($BOLD_WHITE)$userid$($RESET)"
Write-Host "  $($CYAN)- Global Account Name:     $($BOLD_WHITE)$global_subdomain$($RESET)" # Added Name
Write-Host "  $($CYAN)- Global Account ID:       $($BOLD_WHITE)$global_account_id$($RESET)"
Write-Host "  $($CYAN)- Subaccount Name:         $($BOLD_WHITE)$subaccountDisplayName$($RESET)"
Write-Host "  $($CYAN)- Subaccount ID:           $($BOLD_WHITE)$subaccount_id$($RESET)"
Write-Host "  $($CYAN)- Region:                  $($BOLD_WHITE)$selected_region$($RESET)"
Write-Host "  $($CYAN)- Subaccount Subdomain:    $($BOLD_WHITE)$unique_subdomain$($RESET)"
Write-Host "  $($CYAN)- Cloud Foundry Org:       $($BOLD_WHITE)$cf_org_name$($RESET)"
Write-Host "  $($CYAN)- Cloud Foundry Space:     $($BOLD_WHITE)$cfSpaceName$($RESET)"
# Write-Host "  $($CYAN)- Cloud Foundry API Env ID: $($BOLD_WHITE)$cf_env_id$($RESET)" # Optional
Write-Host "  $($CYAN)- Cloud Foundry API:       $($BOLD_WHITE)$cf_api_endpoint$($RESET)"
# Corrected syntax for default value: Use -or operator within $()
Write-Host "  $($CYAN)- Integration Suite URL:   $($BOLD_WHITE)$($integration_suite_url -or '(Not retrieved, check cockpit)')$($RESET)"
Write-Host "  $($CYAN)- Integration Flow Key ($($serviceKeyName)):$($RESET)"
Write-Host "      $($CYAN)Token URL:    $($BOLD_WHITE)$($tokenurl -or '(Not retrieved)')$($RESET)"
Write-Host "      $($CYAN)Client ID:    $($BOLD_WHITE)$($clientid -or '(Not retrieved)')$($RESET)"
Write-Host "      $($CYAN)Client Secret: $($BOLD_WHITE)$($clientsecret -or '(Not retrieved)')$($RESET) $(if($clientsecret){$BOLD_RED + '(Confidential!)' + $RESET} else {' '})" # Keep conditional confidential warning
Write-Host "  $($CYAN)- Assigned Role Collections:$($RESET)"
Write-Host "$($WHITE)$($finalRolesList -join "`n")$($RESET)"
Write-Host ""
if ($integration_suite_url) { Write-Host "  $($BOLD_GREEN)You can now access the Integration Suite at: $($BOLD_WHITE)$integration_suite_url$($RESET)" }
else { Write-Host "  $($BOLD_GREEN)Access the Integration Suite via the BTP Cockpit.$($RESET)" }
Write-Host ""
