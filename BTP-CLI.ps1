# Define colors
$colors = @{
    Red = [System.ConsoleColor]::Red
    Green = [System.ConsoleColor]::Green
    Yellow = [System.ConsoleColor]::Yellow
    Blue = [System.ConsoleColor]::Blue
    Magenta = [System.ConsoleColor]::Magenta
    Cyan = [System.ConsoleColor]::Cyan
    White = [System.ConsoleColor]::White
}

function Write-ColorOutput {
    param([string]$Message, [System.ConsoleColor]$Color)
    Write-Host $Message -ForegroundColor $Color
}

# Script header
Write-Host ""
Write-Host "  ------------------------------------------------------------" -ForegroundColor $colors.Blue
Write-Host "  === " -ForegroundColor $colors.Blue -NoNewline
Write-Host "SAP BTP CLI SUBACCOUNT AND INTEGRATION SUITE CREATOR" -ForegroundColor $colors.Cyan -NoNewline
Write-Host " ===" -ForegroundColor $colors.Blue
Write-Host "  ------------------------------------------------------------" -ForegroundColor $colors.Blue
Write-Host ""

# Read credentials
Write-ColorOutput "  ℹ Reading credentials file..." $colors.Cyan
if (Test-Path "credentials.txt") {
    $credentials = Get-Content "credentials.txt" -TotalCount 2
    $userid = $credentials[0]
    $passw = $credentials[1]
    Write-Host ""
    Write-ColorOutput "  ✓ Credentials loaded successfully!" $colors.Green
} else {
    Write-ColorOutput "  ✗ Error: credentials.txt file not found!" $colors.Red
    exit 1
}

# BTP Login
Write-Host ""
Write-ColorOutput "  ℹ Logging in to SAP BTP..." $colors.Cyan
$loginOutput = & ./btp login --url https://cli.btp.cloud.sap --user $userid --password $passw

# Extract global account subdomain
$globalSubdomain = $loginOutput | Select-String -Pattern "[0-9a-zA-Z]+trial" | Select-Object -First 1
$globalSubdomain = $globalSubdomain.Matches[0].Value

Write-Host ""
Write-ColorOutput "  Extracted global account subdomain: $globalSubdomain" $colors.Cyan

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "  ✗ Login failed. Exiting." $colors.Red
    exit 1
} else {
    Write-ColorOutput "  ✓ Login successful!" $colors.Green
}

# Get regions
Write-Host ""
Write-ColorOutput "  ℹ Fetching available regions..." $colors.Cyan
$regionsOutput = & ./btp list accounts/available-region
$regions = $regionsOutput | Select-String -Pattern "^\w+\s+cf-" | ForEach-Object { ($_ -split '\s+')[0] }

# Extract global account ID
$globalAccountId = $regionsOutput | Select-String -Pattern "global account ([a-zA-Z0-9-]+)" | ForEach-Object { $_.Matches.Groups[1].Value }

Write-Host ""
Write-ColorOutput "  Available regions:" $colors.Blue
for ($i = 0; $i -lt $regions.Count; $i++) {
    Write-ColorOutput "  $($i + 1)) $($regions[$i])" $colors.Cyan
}

# Region selection
Write-Host ""
do {
    Write-Host "  Select a region (1-$($regions.Count)): " -ForegroundColor $colors.Magenta -NoNewline
    $selection = Read-Host
} while (-not ($selection -match '^\d+$' -and [int]$selection -ge 1 -and [int]$selection -le $regions.Count))

$selectedRegion = $regions[[int]$selection - 1]

# Create unique subdomain
$timestamp = [int](Get-Date -UFormat %s)
$uniqueSubdomain = "trial-$($globalAccountId.Substring(0, 7))-$timestamp"

Write-Host ""
Write-ColorOutput "  You selected region: $selectedRegion" $colors.Cyan
Write-ColorOutput "  Subdomain will be: $uniqueSubdomain" $colors.Cyan

Write-Host ""
$confirm = Read-Host "  Proceed with creating subaccount? (y/n) [y]"
if ($confirm -ne "" -and $confirm -ne "y") {
    Write-ColorOutput "  ⚠ Subaccount creation cancelled." $colors.Yellow
    exit 1
}

# Create subaccount
Write-Host ""
Write-ColorOutput "  Creating subaccount..." $colors.Cyan
$subaccountOutput = & ./btp create accounts/subaccount --display-name "Trial" --region $selectedRegion --subdomain $uniqueSubdomain

# Extract subaccount ID
$subaccountId = $subaccountOutput | Select-String -Pattern "subaccount id:\s*(.*)" | ForEach-Object { $_.Matches.Groups[1].Value }

Write-Host ""
Write-ColorOutput "  Extracted subaccount ID: $subaccountId" $colors.Cyan

# Wait for subaccount to be ready
$maxAttempts = 24
$attempt = 1

while ($attempt -le $maxAttempts) {
    Write-ColorOutput "  Checking subaccount state (attempt $attempt of $maxAttempts)..." $colors.Cyan
    
    $subaccountState = & ./btp get accounts/subaccount $subaccountId |
        Select-String -Pattern "state:\s*(.*)" |
        ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
    
    if ($subaccountState -eq "OK") {
        Write-ColorOutput "  ✓ Subaccount is ready!" $colors.Green
        break
    }
    else {
        Write-ColorOutput "  Subaccount state is: $subaccountState" $colors.Yellow
    }
    
    if ($attempt -eq $maxAttempts) {
        Write-ColorOutput "  ✗ Subaccount did not become ready within the timeout period." $colors.Red
        exit 1
    }
    
    Write-ColorOutput "  Waiting 5 seconds before next check..." $colors.Cyan
    Start-Sleep -Seconds 5
    $attempt++
}

# Create Cloud Foundry Environment
Write-ColorOutput "  Enabling Cloud Foundry environment..." $colors.Cyan

$cfParams = @{
    instance_name = "${uniqueSubdomain}_Trial"
    org_name = "${globalSubdomain}_${uniqueSubdomain}"
}

$cfCreationOutput = & ./btp create accounts/environment-instance `
    --subaccount $subaccountId `
    --environment cloudfoundry `
    --service cloudfoundry `
    --plan trial `
    --display-name "${uniqueSubdomain}_Trial" `
    --parameters ($cfParams | ConvertTo-Json)

# Extract CF environment ID
$cfEnvId = $cfCreationOutput | 
    Select-String -Pattern "environment id:\s*(.*)" | 
    ForEach-Object { $_.Matches.Groups[1].Value }

Write-Host ""
Write-ColorOutput "  Extracted Environment ID: $cfEnvId" $colors.Cyan

# Wait for CF environment
$maxAttempts = 24
$attempt = 1

while ($attempt -le $maxAttempts) {
    Write-ColorOutput "  Checking Cloud Foundry Environment state (attempt $attempt of $maxAttempts)..." $colors.Cyan
    
    $cfEnvState = & ./btp get accounts/environment-instance $cfEnvId --subaccount $subaccountId |
        Select-String -Pattern "state:\s*(.*)" |
        ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
    
    if ($cfEnvState -eq "OK") {
        Write-ColorOutput "  ✓ Cloud Foundry Environment is ready!" $colors.Green
        break
    }
    else {
        Write-ColorOutput "  Cloud Foundry Environment state is: $cfEnvState" $colors.Yellow
    }
    
    if ($attempt -eq $maxAttempts) {
        Write-ColorOutput "  ✗ Cloud Foundry Environment did not become ready." $colors.Red
        exit 1
    }
    
    Write-ColorOutput "  Waiting 5 seconds before next check..." $colors.Cyan
    Start-Sleep -Seconds 5
    $attempt++
}

# Get CF API endpoint and login
$cfApiEndpoint = & ./btp get accounts/environment-instance $cfEnvId --subaccount $subaccountId |
    Select-String -Pattern "api endpoint:\s*(.*)" |
    ForEach-Object { $_.Matches.Groups[1].Value }

Write-ColorOutput "  === Cloud Foundry Login ===" $colors.Blue
& ./cf login -a $cfApiEndpoint -u $userid -p $passw

# Create CF space
Write-ColorOutput "  Creating Cloud Foundry space..." $colors.Cyan
& ./cf create-space dev

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "  ✓ Cloud Foundry space created!" $colors.Green
}
else {
    Write-ColorOutput "  ✗ Failed to create Cloud Foundry space." $colors.Red
    exit 1
}

Write-ColorOutput "  Targeting the new space..." $colors.Cyan
& ./cf target -s dev

# Add service plans
Write-ColorOutput "  === Adding All Required Service Plans ===" $colors.Cyan

$servicePlansEnable = @(
    @{service="it-rt"; plan="integration-flow"},
    @{service="it-rt"; plan="api"},
    @{service="sapappstudiotrial"; plan="trial"}
)

$servicePlansAmount = @(
    @{service="integrationsuite-trial"; plan="trial"},
    @{service="sap-build-apps"; plan="free"}
)

foreach ($plan in $servicePlansAmount) {
    Write-ColorOutput "  Adding entitlement for $($plan.service) ($($plan.plan) plan)..." $colors.Cyan
    
    & ./btp assign accounts/entitlement `
        --to-subaccount $subaccountId `
        --for-service $plan.service `
        --plan $plan.plan `
        --amount 1
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "  ✓ Added entitlement for $($plan.service) ($($plan.plan) plan)!" $colors.Green
    }
    else {
        Write-ColorOutput "  ⚠ Failed to add entitlement for $($plan.service) ($($plan.plan) plan)." $colors.Yellow
    }
}

foreach ($plan in $servicePlansEnable) {
    Write-ColorOutput "  Adding entitlement for $($plan.service) ($($plan.plan) plan)..." $colors.Cyan
    
    & ./btp assign accounts/entitlement `
        --to-subaccount $subaccountId `
        --for-service $plan.service `
        --plan $plan.plan `
        --enable
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "  ✓ Added entitlement for $($plan.service) ($($plan.plan) plan)!" $colors.Green
    }
    else {
        Write-ColorOutput "  ⚠ Failed to add entitlement for $($plan.service) ($($plan.plan) plan)." $colors.Yellow
    }
}

Write-ColorOutput "  ✓ All service plans have been added to the subaccount!" $colors.Green

# Create Integration Suite subscription
Write-ColorOutput "  Creating Integration Suite subscription..." $colors.Cyan
& ./btp subscribe accounts/subaccount --subaccount $subaccountId --to-app it-cpitrial06-prov --plan trial

# Wait for subscription
$maxAttempts = 72
$attempt = 1

while ($attempt -le $maxAttempts) {
    Write-ColorOutput "  Checking subscription state (attempt $attempt of $maxAttempts)..." $colors.Cyan
    
    $subscriptionState = & ./btp list accounts/subscription --subaccount $subaccountId |
        Select-String -Pattern "it-cpitrial06-prov.*?(SUBSCRIBED|IN_PROCESS|NOT_SUBSCRIBED|FAILED)" |
        ForEach-Object { $_.Matches.Groups[1].Value }
    
    if ($subscriptionState -eq "SUBSCRIBED") {
        Write-ColorOutput "  ✓ Integration Suite subscription is ready!" $colors.Green
        break
    }
    elseif ($subscriptionState -eq "FAILED" -or $subscriptionState -eq "NOT_SUBSCRIBED") {
        Write-ColorOutput "  ✗ Integration Suite subscription failed." $colors.Red
        exit 1
    }
    else {
        Write-ColorOutput "  Integration Suite subscription is still in process..." $colors.Yellow
    }
    
    if ($attempt -eq $maxAttempts) {
        Write-ColorOutput "  ✗ Integration Suite subscription did not become ready." $colors.Red
        exit 1
    }
    
    Start-Sleep -Seconds 5
    $attempt++
}

# Assign role collections
Write-ColorOutput "  Listing all role collections and assigning them to user..." $colors.Cyan

$roleCollections = & ./btp --format json list security/role-collection --subaccount $subaccountId |
    ConvertFrom-Json |
    Select-Object -ExpandProperty name

foreach ($role in $roleCollections) {
    Write-ColorOutput "  Assigning role collection: $role" $colors.Cyan
    & ./btp assign security/role-collection $role --to-user $userid --subaccount $subaccountId > $null 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "  ✓ Role collection assigned successfully!" $colors.Green
    }
    else {
        Write-ColorOutput "  ⚠ Could not assign role collection: $role" $colors.Yellow
    }
}

# Get Integration Suite URL
$integrationSuiteUrl = & ./btp list accounts/subscription --subaccount $subaccountId |
    Select-String -Pattern "https://[^\s]*" |
    ForEach-Object { $_.Matches[0].Value }

Write-ColorOutput "  ✓ Integration Suite setup complete!" $colors.Green

Write-Host ""
Write-ColorOutput "  ⚠ Next steps ⚠" $colors.Yellow
Write-ColorOutput "  1. Access your Integration Suite at: $integrationSuiteUrl" $colors.Yellow
Write-ColorOutput "  2. Activate the required capabilities (Cloud Integration, API Management, etc.)" $colors.Yellow
Write-ColorOutput "  3. Once Cloud Integration capability is enabled come back to the script and press 'y' key to continue." $colors.Yellow

Write-Host "Press 'y' to continue..."
while ($true) {
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    if ($key.Character -eq 'y') {
        Write-Host "`nContinuing..."
        break
    }
}

# Create Process Integration Runtime instances
Write-ColorOutput "  Creating Process Integration Runtime instance (integration-flow plan)..." $colors.Cyan
& ./cf create-service it-rt integration-flow pi-runtime

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "  ✓ Process Integration Runtime instance created!" $colors.Green
}
else {
    Write-ColorOutput "  ✗ Failed to create Process Integration Runtime instance." $colors.Red
}

Write-ColorOutput "  Creating Process Integration Runtime API instance..." $colors.Cyan
& ./cf create-service it-rt api pi-api

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "  ✓ Process Integration Runtime API instance created!" $colors.Green
}
else {
    Write-ColorOutput "  ✗ Failed to create Process Integration Runtime API instance." $colors.Red
}

# Create service key
Write-ColorOutput "  Creating service key..." $colors.Cyan
& ./cf create-service-key pi-runtime pi-runtime-key

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "  ✓ Service key created!" $colors.Green
    Write-ColorOutput "  Service key details:" $colors.Blue
    & ./cf service-key pi-runtime pi-runtime-key
}
else {
    Write-ColorOutput "  ✗ Failed to create service key." $colors.Red
}

# Final message
Write-Host ""
Write-Host "  ✅ CONGRATULATIONS! ✅" -ForegroundColor $colors.Green
Write-Host "  ------------------------------------------------------------" -ForegroundColor $colors.Blue
Write-Host "  === " -ForegroundColor $colors.Blue -NoNewline
Write-Host "INTEGRATION SUITE SUCCESSFULLY CREATED!" -ForegroundColor $colors.Cyan -NoNewline
Write-Host " ===" -ForegroundColor $colors.Blue
Write-Host "  ------------------------------------------------------------" -ForegroundColor $colors.Blue
Write-ColorOutput "  Your journey with Integration Flows is ready." $colors.Yellow
Write-ColorOutput "  Access your Integration Suite at: $integrationSuiteUrl" $colors.Cyan
Write-Host ""
