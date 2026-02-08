# Epic Online Services (EOS) Multiplayer Setup Guide

## Overview

Your game now uses **Epic Online Services (EOS)** for multiplayer functionality instead of the NodeTunnelPeer relay system. This provides:

- ✅ **Lobbies** - Create and join game lobbies
- ✅ **Matchmaking** - Find opponents via matchmaking system
- ✅ **P2P Networking** - Direct peer-to-peer connections with NAT traversal
- ✅ **Room Codes** - Simple room code sharing for quick matches
- ✅ **Cross-Platform** - Works across PC, Mac, Linux, console platforms

## Step 1: Create Epic Games Account and Developer Portal Access

1. Go to https://dev.epicgames.com/
2. Click "Sign Up" and create an account
3. Verify your email
4. Accept the Developer Agreement
5. Complete your profile (name, country, etc.)

## Step 2: Create a Product

1. Log in to your Epic Games developer account
2. Go to **Your Products** in the left sidebar
3. Click **Create Product**
4. Fill in:
   - **Product Name**: Your game name (e.g., "Code Arena")
   - **Category**: Action, RPG, Strategy, etc.
   - **Platform**: Check PC (and any other platforms you target)
5. Click **Create Product**

## Step 3: Get Your Product ID and Sandbox ID

1. Go to your product page
2. In the left sidebar, click **Product Settings**
3. Copy your **Product ID** (looks like: `a1b2c3d4e5f6g7h8`)
4. Your **Sandbox ID** is typically the same as Product ID
5. Save these values

## Step 4: Create a Deployment

1. In your product page, go to **Deployments**
2. Click **Create Deployment**
3. Enter:
   - **Deployment Name**: "Development" (or your environment name)
   - Keep other settings as default
4. Click **Create**
5. Your **Deployment ID** will be displayed (copy it)

## Step 5: Create an Application (Client Credentials)

1. In your product page, go to **Applications**
2. Click **Create Application**
3. Fill in:
   - **Application Name**: Your game or client name
   - **Deployment**: Select the deployment you just created
   - **Client Type**: **Confidential** (for server-to-server) or **Public** (for client)
4. Click **Create**
5. You'll see your **Client ID**
6. Click **Generate Client Secret** and copy it (⚠️ **KEEP THIS SECRET!**)

## Step 6: Configure Your Game

1. Open `Scripts/eos_config.gd` in your project
2. Fill in the values you collected:

```gdscript
var PRODUCT_ID: String = "YOUR_PRODUCT_ID"        # From Step 3
var SANDBOX_ID: String = "YOUR_SANDBOX_ID"        # From Step 3
var DEPLOYMENT_ID: String = "YOUR_DEPLOYMENT_ID"  # From Step 4
var CLIENT_ID: String = "YOUR_CLIENT_ID"          # From Step 5
var CLIENT_SECRET: String = "YOUR_CLIENT_SECRET"  # From Step 5
```

3. Save the file
4. ⚠️ **Important**: Add `eos_config.gd` to your `.gitignore` to avoid committing credentials!

## Architecture Overview

### Key Components

**EOSManager** (`Scripts/eos_manager.gd`)
- Handles all EOS API calls
- Manages lobbies, matchmaking, P2P connections
- Emits signals for game state changes

**GameMenu** (`Scripts/game_menu.gd`)
- Attached to `game_menu.tscn`
- UI logic for host/join/matchmaking
- Connects to EOSManager signals

**GameBattle** (`Scripts/game_pvp.gd`)
- Handles the actual PvP combat
- Works with both old (NodeTunnelPeer) and new (EOS) multiplayer systems
- Turn-based combat with cooldowns and RPC synchronization

```
game_menu.tscn
    ├── UI/Multiplayer (Host/Join/Matchmaking buttons)
    ├── EOSManager (created at runtime)
    └── MultiplayerSpawner (for player instances)

game.tscn
    ├── BattleLayout
    │   └── game_pvp.gd (handles turn-based combat)
    ├── Players (spawned at runtime)
    └── UI (battle HUD)
```

## Gameplay Flow

### Hosting a Game

1. Player clicks **HOST GAME**
2. EOSManager creates a lobby via EOS
3. Room code is displayed and can be copied
4. Game waits for opponent to join
5. When opponent joins, battle starts automatically

### Joining a Game via Room Code

1. Player clicks **JOIN GAME**
2. Enters the 6-character room code
3. EOSManager searches for matching lobby
4. Player joins the lobby
5. Both players' P2P connections established
6. Battle starts automatically

### Matchmaking

1. Player clicks **FIND MATCH**
2. EOSManager searches for available opponents
3. When opponent found, automatic P2P session established
4. Battle starts with both players

## Networking Details

### Lobbies API

The EOS Lobbies API provides:
- Ability to create and join lobbies
- Lobby persistence (lobbies stay until owner leaves)
- Attribute searching (filter by game mode, skill level, etc.)
- Room code generation for easy sharing

### P2P Networking

The EOS P2P API provides:
- Direct peer-to-peer connections
- NAT traversal (works behind firewalls)
- Automatic relay fallback if direct connection fails
- Lower latency than relay-only connections
- Encrypted connections

### Matchmaking (Optional Enhancement)

For more complex matchmaking:
- Configure skill-based matchmaking rules
- Set player search criteria
- Automatic match creation when players found

## Events and Signals

```gdscript
# Authentication
eos_manager.authenticated
eos_manager.authentication_failed(error)

# Lobbies
eos_manager.lobby_created(lobby_id)
eos_manager.lobby_joined(lobby_id)

# Matchmaking
eos_manager.matchmaking_started
eos_manager.matchmaking_complete(session_id)

# Networking
eos_manager.peer_connected(peer_id)
eos_manager.peer_disconnected(peer_id)

# Errors
eos_manager.error_occurred(error_code, error_message)
```

## Common Issues and Solutions

### "Missing EOS credentials" Error
- **Solution**: Fill in all fields in `eos_config.gd`
- Ensure no quotes around credentials
- Restart the game

### "Failed to authenticate" Error
- **Solution**: Check your credentials are correct
- Verify deployment is active in EOS portal
- Check internet connection

### "Lobby not found" when joining with code
- **Solution**: Ensure code is correct (case-insensitive)
- Host's lobby must be created first
- Both players must be in same deployment

### High latency or connection drops
- **Solution**: EOS P2P automatically falls back to relay
- Check your Deployment's relay server configuration
- Ensure firewall isn't blocking connection

## Testing Without EOS Backend

For local testing, the current implementation uses mock lobbies (stored in memory). The system is structured to easily swap in the real EOS API calls when the SDK is integrated:

```gdscript
# In eos_manager.gd, replace mock lobbies with real EOS calls:
func create_lobby(lobby_name: String, ...) -> String:
    # Replace this:
    active_lobbies[lobby_id] = lobby_data
    
    # With EOS API call:
    var response = await eos.api.lobbies.create({...})
    return response.lobby_id
```

## Next Steps

1. ✅ Fill in `eos_config.gd` with your credentials
2. ✅ Test hosting and joining locally
3. ✅ Test with actual EOS SDK (implement API calls)
4. ✅ Deploy to production Epic Games developer environment
5. ✅ Enable live games for production release

## Production Deployment

For production:

1. **Move to Production Environment**
   - Go to EOS Developer Portal
   - Create Production deployment
   - Obtain production credentials

2. **Update Config**
   - Create separate production config
   - Use environment variables for credentials
   - Never hardcode secrets in code

3. **Authentication**
   - Implement proper account system (email, social login)
   - Replace device authentication with user authentication
   - Implement account linking

4. **Backend Integration**
   - Set up your backend server for game distribution
   - Integrate EOS SDK C++ module if needed
   - Implement server-authoritative game logic

## EOS Documentation

For more detailed information:
- **EOS Documentation**: https://dev.epicgames.com/docs
- **Lobbies API**: https://dev.epicgames.com/docs/game-services/lobbies/lobbies-interface
- **P2P Networking**: https://dev.epicgames.com/docs/game-services/p2p/p2p-interface
- **Matchmaking**: https://dev.epicgames.com/docs/game-services/matchmaking/overview
- **Godot Integration**: https://github.com/3ddelano/epic-online-services-godot (community plugin)

## Support

If you encounter issues:

1. Check the console output for error messages
2. Verify credentials in `eos_config.gd`
3. Confirm your deployment is active
4. Check EOS status page: https://status.epicgames.com/
5. Review EOS API documentation
6. Contact Epic Games support for SDK issues
