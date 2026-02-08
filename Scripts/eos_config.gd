extends Node
class_name EOSConfig

# ============================================================================
# EPIC ONLINE SERVICES CONFIGURATION
# ============================================================================
# 
# HOW TO SET UP EOS CREDENTIALS:
# 1. Go to https://dev.epicgames.com/
# 2. Create an account and organization
# 3. Create a product
# 4. Go to your product's deployment page
# 5. Create an application (Client)
# 6. Copy the Client ID and Client Secret
# 7. Find your Product ID and Sandbox ID
# 8. Fill in the values below
#
# ============================================================================

class_name EOSCredentials

# Your EOS Product ID - Found in your product settings
# Example: "a1b2c3d4e5f6g7h8"
var PRODUCT_ID: String = ""

# Your EOS Sandbox ID - Same as Product ID in most cases
# Example: "a1b2c3d4e5f6g7h8"
var SANDBOX_ID: String = ""

# Your EOS Deployment ID - Create in your deployment settings
# Example: "deployment123456789"
var DEPLOYMENT_ID: String = ""

# Your EOS Client ID - Generated when you create an application
# Example: "xyza5c4b3d2e1f0"
var CLIENT_ID: String = ""

# Your EOS Client Secret - SECRET! Never share or commit this!
# Example: "your_client_secret_here"
var CLIENT_SECRET: String = ""

# The EOS environment - "Production" or "Staging"
var ENVIRONMENT: String = "Production"

# The EOS Platform ID
var PLATFORM_ID: String = "WIN"  # WIN, MAC, LINUX, IOS, ANDROID, SWITCH, PS4, XB1

func _ready() -> void:
	if not _validate_credentials():
		push_warning("EOS credentials not configured. Please update EOSConfig.gd with your credentials.")

func _validate_credentials() -> bool:
	return (not PRODUCT_ID.is_empty() and 
			not SANDBOX_ID.is_empty() and 
			not DEPLOYMENT_ID.is_empty() and
			not CLIENT_ID.is_empty() and
			not CLIENT_SECRET.is_empty())

func is_configured() -> bool:
	return _validate_credentials()

func get_credentials() -> Dictionary:
	return {
		"product_id": PRODUCT_ID,
		"sandbox_id": SANDBOX_ID,
		"deployment_id": DEPLOYMENT_ID,
		"client_id": CLIENT_ID,
		"client_secret": CLIENT_SECRET,
		"environment": ENVIRONMENT,
		"platform_id": PLATFORM_ID
	}
