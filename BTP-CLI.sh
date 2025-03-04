#!/bin/bash

# Define colors
RED="\e[0;31m"
GREEN="\e[0;32m"
YELLOW="\e[0;33m"
BLUE="\e[0;34m"
PURPLE="\e[1;35m"
CYAN="\e[0;36m"
WHITE="\e[0;97m"
BOLD="\e[1m"
RESET="\e[0m"

# Script to log in to SAP BTP CLI and set up Integration Suite

# Prompt for user credentials
echo ""
echo -e "  ${BLUE}${BOLD}------------------------------------------------------------${RESET}"
echo -e "  ${BLUE}${BOLD}===${RESET} ${CYAN}${BOLD}SAP BTP CLI SUBACCOUNT AND INTEGRATION SUITE CREATOR${RESET} ${BLUE}${BOLD}===${RESET}"
echo -e "  ${BLUE}${BOLD}------------------------------------------------------------${RESET}"
echo ""

#
# READ CREDENTIALS FROM FILE
#

echo ""
# Read credentials from file
echo -e "  ${CYAN}ℹ Reading credentials file...${RESET}"
if [ -f "credentials.txt" ]; then
  # Read first line as userid
  read -r userid < credentials.txt
  
  # Read second line as password
  passw=$(head -n 2 credentials.txt | tail -n 1)
  
  echo ""
  echo -e "  ${GREEN}${BOLD}✓ Credentials loaded successfully!${RESET}"
else
  echo -e "  ${RED}${BOLD}✗ Error: credentials.txt file not found!${RESET}"
  exit 1
fi

#
# LOGIN TO BTP CLI & EXTRACT GLOBAL ACCOUNT INFO
#

# Capture the login output
login_output=$(./btp login --url https://cli.btp.cloud.sap --user $userid --password $passw 2>/dev/null)

# Extract the global account subdomain
global_subdomain=$(echo "$login_output" | grep "Current target:" -A 1 | grep -o "[0-9a-zA-Z]\+trial" | head -1)

# Display Login info
#!#!echo "$login_output"

echo ""
# Check if login was successful
if [ $? -ne 0 ]; then
    echo -e "  ${RED}${BOLD}✗ Login failed. Exiting.${RESET}"
    exit 1
else
    echo -e "  ${GREEN}${BOLD}✓ Login successful!${RESET}"
fi

echo ""
# Verify the extraction
echo -e "  ${CYAN}Extracted global account subdomain: ${WHITE}${BOLD}$global_subdomain${RESET}"

echo ""
# Get available regions
echo -e "  ${CYAN}ℹ Fetching available regions...${RESET}"
regions_output=$(./btp list accounts/available-region 2>/dev/null)

# Extract global account ID
global_account_id=$(echo "$regions_output" | grep -o "global account [a-zA-Z0-9-]\+" | head -1 | cut -d' ' -f3)

echo ""
# Parse regions
echo -e "  ${BLUE}${BOLD}Available regions:${RESET}"
readarray -t regions < <(echo "$regions_output" | grep -E '^\w+\s+cf-' | awk '{print $1}')

echo ""
# Display regions with numbers
for i in "${!regions[@]}"; do
    echo -e "  ${CYAN}$((i+1))) ${regions[$i]}${RESET}"
done

# Get user selection
echo ""
read -p "$(echo -e ${PURPLE}  Select a region \(1-${#regions[@]}\): ${RESET})" selection

# Validate selection
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#regions[@]}" ]; then
    echo -e "  ${RED}${BOLD}✗ Invalid selection. Exiting.${RESET}"
    exit 1
fi

# Get the selected region
selected_region=${regions[$((selection-1))]}

# Create a unique subdomain based on global account ID and timestamp
timestamp=$(date +%s)
unique_subdomain="trial-${global_account_id:0:7}-$timestamp"

# Display information and confirm
echo ""
echo -e "  ${CYAN}You selected region: ${WHITE}${BOLD}$selected_region${RESET}"
echo -e "  ${CYAN}Subdomain will be: ${WHITE}${BOLD}$unique_subdomain${RESET}"
echo ""
read -p "$(echo -e ${YELLOW}  Proceed with creating subaccount? \(y/n\): ${RESET})" -e -i "y" confirm

#
# CREATE SUBACCOUNT 
#

echo ""
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    # Create the subaccount
    echo -e "  ${CYAN}Creating subaccount...${RESET}"
    
	subaccount_output=$(./btp create accounts/subaccount --display-name "Trial" --region "$selected_region" --subdomain "$unique_subdomain" 2>/dev/null)

	# Display the output
	#!#!echo "$subaccount_output"

	# Extract the subaccount ID from the output
	subaccount_id=$(echo "$subaccount_output" | grep "subaccount id:" | sed 's/subaccount id: *//g')

	# Verify the ID was captured correctly
	echo ""
	echo -e "  ${CYAN}Subaccount Name: ${WHITE}${BOLD}Trial${RESET}"
	echo -e "  ${CYAN}Subaccount ID: ${WHITE}${BOLD}$subaccount_id${RESET}"
	echo ""
    
# After creating the subaccount
if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✓ Subaccount created successfully!${RESET}"
    
    echo ""
# Poll the subaccount state until it's ready
echo -e "  ${CYAN}Waiting for subaccount to be ready...${RESET}"
max_attempts=20  # Maximum number of attempts
attempt=1
loading_progress=""

while [ $attempt -le $max_attempts ]; do
    # Get the current state of the subaccount without showing output
    subaccount_output=$(./btp get accounts/subaccount "$subaccount_id" 2>/dev/null)
    
    # Extract the state value
    subaccount_state=$(echo "$subaccount_output" | grep "state:" | grep -v "state message:" | awk '{print $2}')
    
    # Clear the previous line
    echo -ne "\033[2K\r"
    
    # Show current attempt and state
    echo -ne "  ${CYAN}Checking state (${attempt}/${max_attempts}): ${YELLOW}${subaccount_state:-"PENDING"}${RESET} "
    
    if [ "$subaccount_state" = "OK" ]; then
        echo ""
        echo -e "\n  ${GREEN}${BOLD}✓ Subaccount is ready!${RESET}"
        break
    fi
    
    # If we've reached the maximum attempts, exit with an error
    if [ $attempt -eq $max_attempts ]; then
        echo -e "\n  ${RED}${BOLD}✗ Subaccount did not become ready within the timeout period.${RESET}"
        exit 1
    fi
    
    # Update the loading bar (adding one # per attempt)
    loading_progress="${loading_progress}#"
    echo -ne "[${loading_progress}${CYAN}"
    
    # Fill the rest with spaces to create a fixed-width bar
    remaining=$((max_attempts - attempt))
    for ((i=0; i<remaining; i++)); do
        echo -ne " "
    done
    echo -ne "${RESET}]"
    
    # Wait 3 seconds before the next check
    sleep 3
    
    ((attempt++))
done
echo -ne "\n"

    
else
    echo -e "  ${RED}${BOLD}✗ Failed to create subaccount.${RESET}"
    exit 1
fi
else
    echo -e "  ${YELLOW}⚠ Subaccount creation cancelled.${RESET}"
    exit 1
fi
echo ""

#
# CREATE & ENABLE CLOUD FOUNDRY ENVIRONMENT 
#

# Enable Cloud Foundry environment
echo -e "  ${CYAN}Enabling Cloud Foundry environment...${RESET}"

cf_creation_output=$(./btp create accounts/environment-instance --subaccount "$subaccount_id" --environment "cloudfoundry" --service "cloudfoundry" --plan "trial" --display-name "${unique_subdomain}_Trial" --parameters "{\"instance_name\": \"${unique_subdomain}_Trial\", \"org_name\": \"${global_subdomain}_${unique_subdomain}\"}" 2>/dev/null)

# Check if Cloud Foundry environment creation was successful
if [ $? -eq 0 ]; then
    # Display the output
    #!#!echo "$cf_creation_output"

    # Extract the environment ID from the output
    cf_env_id=$(echo "$cf_creation_output" | grep "environment id:" | sed 's/environment id: *//g')

    # Verify the ID was captured correctly
    echo ""
    echo -e "  ${CYAN}Extracted Environment ID: ${WHITE}${BOLD}$cf_env_id${RESET}"
    echo ""

# Poll the Cloud Foundry environment state until it's ready
echo -e "  ${CYAN}Waiting for Cloud Foundry Environment to be ready...${RESET}"
max_attempts=20  # Maximum number of attempts
attempt=1
loading_progress=""

while [ $attempt -le $max_attempts ]; do
    # Get the current state of the environment instance without showing output
    cf_env_output=$(./btp get accounts/environment-instance $cf_env_id --subaccount $subaccount_id 2>/dev/null)
    
    # Extract the state value
    cf_env_state=$(echo "$cf_env_output" | grep "state:" | grep -v "state message:" | awk '{print $2}')
    
    # Clear the previous line
    echo -ne "\033[2K\r"
    
    # Show current attempt and state
    echo -ne "  ${CYAN}Checking CF state (${attempt}/${max_attempts}): ${YELLOW}${cf_env_state:-"PENDING"}${RESET} "
    
    if [ "$cf_env_state" = "OK" ]; then
        echo ""
        echo -e "\n  ${GREEN}${BOLD}✓ Cloud Foundry Environment is ready!${RESET}"
        break
    fi
    
    # If we've reached the maximum attempts, exit with an error
    if [ $attempt -eq $max_attempts ]; then
        echo -e "\n  ${RED}${BOLD}✗ Cloud Foundry Environment did not become ready within the timeout period.${RESET}"
        exit 1
    fi
    
    # Update the loading bar (adding one # per attempt)
    loading_progress="${loading_progress}#"
    echo -ne "[${loading_progress}${CYAN}"
    
    # Fill the rest with spaces to create a fixed-width bar
    remaining=$((max_attempts - attempt))
    for ((i=0; i<remaining; i++)); do
        echo -ne " "
    done
    echo -ne "${RESET}]"
    
    # Wait 3 seconds before the next check
    sleep 3
    
    ((attempt++))
done
echo -ne "\n"

else
    echo -e "  ${RED}${BOLD}✗ Failed to enable Cloud Foundry environment.${RESET}"
    exit 1
fi

#
# LOG IN TO CLOUD FOUNDRY & ADD SERVICE PLANS
#

# Get CF API endpoint
cf_api_endpoint=$(./btp get accounts/environment-instance $cf_env_id --subaccount $subaccount_id 2>/dev/null | grep -o "api endpoint: [a-zA-Z0-9.:/\-]\+" | cut -d' ' -f3)

# Log in to Cloud Foundry
echo -e "  ${BLUE}${BOLD}=== Cloud Foundry ===${RESET}"
echo ""
./cf login -a "$cf_api_endpoint" -u $userid -p $passw > /dev/null 2>&1

# Create a CF space
echo -e "  ${CYAN}Creating Cloud Foundry space...${RESET}"
echo ""
./cf create-space dev > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✓ Cloud Foundry space created!${RESET}"
else
    echo -e "  ${RED}${BOLD}✗ Failed to create Cloud Foundry space.${RESET}"
    exit 1
fi

echo ""
# Target the newly created space
echo -e "  ${CYAN}Targeting the new space...${RESET}"
echo ""
./cf target -s dev

echo ""
# SECTION 1: Add all required service plans
echo -e "  ${BLUE}${BOLD}=== Adding All Required Service Plans ===${RESET}"

# Array of services and their plans to add with value enable
declare -a service_plans_enable=(
  "it-rt integration-flow"
  "it-rt api"
  "sapappstudiotrial trial"
)

# Array of services and their plans to add with value amount
declare -a service_plans_amount=(
  "integrationsuite-trial trial"
  "sap-build-apps free"
)

echo ""
# Loop through and add all service plans with value amount first
for service_plans_amount in "${service_plans_amount[@]}"; do
  read -r service plan <<< "$service_plans_amount"
  echo -e "  ${CYAN}Adding entitlement for $service ($plan plan)...${RESET}"
  
  ./btp assign accounts/entitlement --to-subaccount $subaccount_id --for-service $service --plan $plan --amount 1 > /dev/null 2>&1
  
  echo ""
  if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✓ Added entitlement for $service ($plan plan)!${RESET}"
  echo ""
  else
    echo -e "  ${YELLOW}⚠ Failed to add entitlement for $service ($plan plan).${RESET}"
  fi
done

echo ""
# Loop through and add all service plans with value enable
for service_plans_enable in "${service_plans_enable[@]}"; do
  read -r service plan <<< "$service_plans_enable"
  echo -e "  ${CYAN}Adding entitlement for $service ($plan plan)...${RESET}"
  
  ./btp assign accounts/entitlement --to-subaccount $subaccount_id --for-service $service --plan $plan --enable > /dev/null 2>&1
  
  echo ""
  if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✓ Added entitlement for $service ($plan plan)!${RESET}"
  echo ""    
    
  else
    echo -e "  ${YELLOW}⚠ Failed to add entitlement for $service ($plan plan).${RESET}"
  fi
done

echo ""
echo -e "  ${GREEN}${BOLD}✓ All service plans have been added to the subaccount!${RESET}"

#
# CREATE SERVICE INSTANCES & SUBSCRIPTIONS 
#

echo ""
# SECTION 2: Create service instances for each entitled service
echo -e "  ${BLUE}${BOLD}=== Creating Services ===${RESET}"

echo ""
# Create Process Integration Runtime service instance (integration-flow plan)
echo -e "  ${CYAN}Creating Integration Suite subscription...${RESET}"
./btp subscribe accounts/subaccount --subaccount $subaccount_id --to-app it-cpitrial06-prov --plan trial > /dev/null 2>&1

echo ""
# Poll the subscription status until it's ready
echo -e "  ${CYAN}Waiting for Integration Suite subscription to be ready...${RESET}"
max_attempts=25  # Maximum number of attempts
attempt=1
loading_progress=""

while [ $attempt -le $max_attempts ]; do
    # Get the current state of the subscription without showing output
    subscription_output=$(./btp list accounts/subscription --subaccount $subaccount_id 2>/dev/null)
    
    # Extract the status value for the Integration Suite subscription
    subscription_state=$(echo "$subscription_output" | grep "it-cpitrial06-prov" | grep -o "SUBSCRIBED\|IN_PROCESS\|NOT_SUBSCRIBED\|FAILED")
    
    # Clear the previous line
    echo -ne "\033[2K\r"
    
    # Show current attempt and state
    echo -ne "  ${CYAN}Checking subscription (${attempt}/${max_attempts}): ${YELLOW}${subscription_state:-"PENDING"}${RESET} "
    
    if [ "$subscription_state" = "SUBSCRIBED" ]; then
        echo ""
        echo -e "\n  ${GREEN}${BOLD}✓ Integration Suite subscription is ready!${RESET}"
        break
    elif [ "$subscription_state" = "FAILED" ] || [ "$subscription_state" = "NOT_SUBSCRIBED" ]; then
        echo -e "\n  ${RED}${BOLD}✗ Integration Suite subscription failed.${RESET}"
        exit 1
    fi
    
    # If we've reached the maximum attempts, exit with an error
    if [ $attempt -eq $max_attempts ]; then
        echo -e "\n  ${RED}${BOLD}✗ Integration Suite subscription did not become ready within the timeout period.${RESET}"
        exit 1
    fi
    
    # Update the loading bar (adding one # per attempt)
    loading_progress="${loading_progress}#"
    echo -ne "[${loading_progress}${CYAN}"
    
    # Fill the rest with spaces to create a fixed-width bar
    remaining=$((max_attempts - attempt))
    for ((i=0; i<remaining; i++)); do
        echo -ne " "
    done
    echo -ne "${RESET}]"
    
    # Wait 3 seconds before the next check
    sleep 3
    
    ((attempt++))
done
echo -ne "\n"

#
# ASSIGN ROLE COLLECTIONS TO USER 
#

echo ""
echo -e "  ${CYAN}Listing all role collections and assigning them to user...${RESET}"

# Get all role collections using JSON format
role_collections=$(./btp --format json list security/role-collection --subaccount "$subaccount_id" | jq -r '.[].name')

# Loop through each role collection and assign to user
echo "$role_collections" | while read -r role; do
  echo ""
  echo -e "  ${CYAN}Assigning role collection: ${WHITE}${BOLD}$role${RESET}"
  ./btp assign security/role-collection "$role" --to-user "$userid" --subaccount "$subaccount_id" > /dev/null 2>&1
  
  if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✓ Role collection assigned successfully!${RESET}"
  else
    echo -e "  ${YELLOW}⚠ Could not assign role collection: $role${RESET}"
  fi
done

  echo ""
  echo -e "  ${CYAN}Current user role collections:${RESET}"
  echo ""
  ./btp --format json list security/role-collection --subaccount "$subaccount_id" | jq -r '.[].name'

  echo ""

#
# WAIT FOR INTEGRATION SUITE TO BE READY 
#

# Get the Integration Suite URL
integration_suite_url=$(./btp list accounts/subscription --subaccount "$subaccount_id" 2>/dev/null | grep "it-cpitrial06-prov" | grep -o "https://[^ ]*")

echo -e "  ${GREEN}${BOLD}✓ Integration Suite setup complete!${RESET}"

echo ""
echo -e "  ${YELLOW}${BOLD}⚠ Next steps ⚠${RESET}"
echo -e "  ${YELLOW}1. Access your Integration Suite at: ${WHITE}${BOLD}$integration_suite_url${RESET}"
echo -e "  ${YELLOW}2. Activate the required capabilities (Cloud Integration, API Management, etc.)${RESET}"
echo -e "  ${YELLOW}3. Once Cloud Integration capability is enabled come back to the script and press 'y' key to continue.${RESET}"

echo "Press 'y' to continue..."
while true; do
  read -n 1 key
  if [[ $key == "y" ]]; then
    echo ""
    echo -e "\nContinuing..."
    break
  fi
done

#
# CREATE PROCESS INTEGRATION RUNTIME SERVICE INSTANCES 
#

echo ""
# Create Process Integration Runtime service instance (integration-flow plan)
echo -e "  ${CYAN}Creating Process Integration Runtime instance (integration-flow plan)...${RESET}"
./cf create-service it-rt integration-flow pi-runtime

if [ $? -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}✓ Process Integration Runtime instance created!${RESET}"

else
  echo -e "  ${RED}${BOLD}✗ Failed to create Process Integration Runtime instance.${RESET}"
fi

# Create Process Integration Runtime API instance
echo ""
echo -e "  ${CYAN}Creating Process Integration Runtime API instance...${RESET}"
./cf create-service it-rt api pi-api

if [ $? -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}✓ Process Integration Runtime API instance created!${RESET}"
else
  echo -e "  ${RED}${BOLD}✗ Failed to create Process Integration Runtime API instance.${RESET}"
fi

echo ""
echo -e "  ${CYAN}Listing all new role collections and assigning them to user...${RESET}"

#
# ASSIGN ROLE COLLECTIONS TO USER 
#

# Get all role collections using JSON format
role_collections=$(./btp --format json list security/role-collection --subaccount "$subaccount_id" | jq -r '.[].name')

# Loop through each role collection and assign to user
echo "$role_collections" | while read -r role; do
  echo ""
  echo -e "  ${CYAN}Assigning new role collection: ${WHITE}${BOLD}$role${RESET}"
  ./btp assign security/role-collection "$role" --to-user "$userid" --subaccount "$subaccount_id" > /dev/null 2>&1
  
  if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✓ New role collection assigned successfully!${RESET}"
  else
    echo -e "  ${YELLOW}⚠ Could not assign role collection: $role${RESET}"
  fi
done

  echo ""
  echo -e "  ${CYAN}Current user role collections:${RESET}"
  echo ""
  ./btp --format json list security/role-collection --subaccount "$subaccount_id" | jq -r '.[].name'

#
# CREATE SERVICE KEY FOR PROCESS INTEGRATION RUNTIME 
#

  echo ""
  # Create service key
echo -e "  ${CYAN}Creating service key...${RESET}"
./cf create-service-key pi-runtime pi-runtime-key
  
if [ $? -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}✓ Service key created!${RESET}"
  echo ""
  echo -e "  ${BLUE}${BOLD}Service key details:${RESET}"
  echo ""
  ./cf service-key pi-runtime pi-runtime-key
else
  echo -e "  ${RED}${BOLD}✗ Failed to create service key.${RESET}"
fi

#
# END OF SCRIPT & GREETER 
#

echo ""
echo -e "  ${GREEN}${BOLD}✅ CONGRATULATIONS! ✅${RESET}"
echo -e "  ${BLUE}-----------------------------------------------${RESET}"
echo -e "  ${BLUE}${BOLD}===${RESET} ${CYAN}${BOLD}INTEGRATION SUITE SUCCESSFULLY CREATED!${RESET} ${BLUE}${BOLD}===${RESET}"
echo -e "  ${BLUE}-----------------------------------------------${RESET}"
echo -e "  ${YELLOW}Your journey with Integration Flows is ready.${RESET}"
echo -e "  ${CYAN}${BOLD}Access your Integration Suite at:${RESET} ${WHITE}${BOLD}$integration_suite_url${RESET}"
echo ""
