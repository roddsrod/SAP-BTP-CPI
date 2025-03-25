# 🚀 SAP Integration Suite Deployment Script

A powerful PowerShell script that automates 95% of the steps required to create a working SAP Integration Suite environment on SAP Business Technology Platform (BTP).

![SAP Integration Suite](https://i.imgur.com/lMufYRa.png)

- **One-Click Setup**: Automates the entire process from BTP login to service creation
- **Cross-Platform**: Works on Windows, MacOS (x64/ARM64), and Linux
- **Smart CLI Detection**: Automatically installs required CLIs if missing
- **Visual Progress**: Beautiful progress indicators and color-coded output
- **Credential Management**: Handles and optionally saves your credentials
- **Role Assignment**: Automatically assigns all necessary roles to your user

## 🧰 What It Does

This script performs the following operations:
- Logs in to SAP BTP
- Creates a new subaccount with a unique subdomain
- Enables Cloud Foundry environment
- Creates and targets a CF space
- Adds required service entitlements
- Creates Integration Suite subscription
- Assigns all role collections to your user
- Creates Process Integration Runtime service instances
- Generates service keys for API access

## 📋 Prerequisites

- SAP BTP account with trial or enterprise global account
- No existing Integration Suite subscription in your global account (limit: 1 per global account)
- PowerShell 5.1+ (Windows) or PowerShell Core 6.0+ (all platforms)

## 🚀 Quick Start

1. Download the script to your local machine
2. Create a `credentials.txt` file in the same directory with:
   ```
   your_email@example.com
   your_password
   ```
   (Or enter it during the running of the script)
3. Run the script from the folder where it resides:
   ```powershell
   ./BTP-CLI.ps1
   ```
   Or:
   ```powershell
   pwsh BTP-CLI.ps1
   ```

## 🔧 Functions

### Core Functions

- **Read-CredentialsFromFile**: Reads or prompts for BTP credentials
- **Invoke-BTPTargetSelection**: Fetches and changes global accounts
- **Start-ProcessingAnimation**: Displays animated progress indicators
- **Test-CommandExists**: Checks if required commands are available
- **Get-OSType**: Detects the operating system for platform-specific operations

### Installation Functions

- **Install-CF**: Downloads and installs Cloud Foundry CLI
- **Install-BTP**: Downloads and installs SAP BTP CLI

### Workflow Functions

The script follows a logical workflow:
1. Checks and installs required CLIs
2. Logs in to BTP and extracts global account info
3. Validates and configures global account
4. Creates and configures a subaccount
5. Enables Cloud Foundry environment
6. Adds service entitlements
7. Creates service instances and subscriptions
8. Assigns role collections
9. Creates service keys for API access

Questions that have an answer marked between brackets [] means it is default answer when pressing enter without providing a value.

## 📝 Manual Steps Required

After the script completes the automated setup (SAP does not have a CLI function for this):

1. Access your Integration Suite at the provided URL
2. Open the 'Capabilities' window
3. Activate the 'Cloud Integration' capability
4. Wait for activation to complete (status will change to 'Active')
5. Return to the script and confirm to continue

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## ❌ Error Handling

Output of running commands has been sent to null to declutter and beautify the print.
If you stumble into a "generic" error, identify the step that generates error and remove the " 2>$null" or similar part.
Run the script again and you will get full output with error message at the step that failed.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

Created by Rodolfo Rodrigues.

## 🙏 Acknowledgements

- SAP for providing the BTP platform and Integration Suite
- The PowerShell community for cross-platform scripting capabilities

---

*Made with ❤️ for SAP developers*


🖼️ Screenshots

![Script Execution_1](https://i.imgur.com/bBDxrKX.png)
![Script Execution_2](https://i.imgur.com/6DZMCh8.png)
![Script Execution_3](https://i.imgur.com/LetWv8h.png)
