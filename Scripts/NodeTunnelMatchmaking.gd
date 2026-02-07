extends Node

# NodeTunnelMatchmaking.gd
# Multiplayer matchmaking using NodeTunnel for Godot

# Usage:
# 1. Call connect_to_relay() to connect to the relay server.
# 2. Call host_game() to host, or join_game(host_oid) to join a match.
# 3. Listen to signals for matchmaking events.

signal relay_connected(online_id)
signal hosting
signal joined
signal room_left
signal match_found(players)

var node_tunnel_peer: MultiplayerPeerExtension = null
var online_id: String = ""
var is_host: bool = false
var players: Array = []

# Set your relay server address and port here
var relay_host: String = "127.0.0.1"
var relay_port: int = 9998

func _ready():
	# Load NodeTunnelPeer and add as child
	node_tunnel_peer = NodeTunnelPeer.new()
	# Connect signals
	node_tunnel_peer.connect("relay_connected", Callable(self, "_on_relay_connected"))
	node_tunnel_peer.connect("hosting", Callable(self, "_on_hosting"))
	node_tunnel_peer.connect("joined", Callable(self, "_on_joined"))
	node_tunnel_peer.connect("room_left", Callable(self, "_on_room_left"))

func connect_to_relay():
	node_tunnel_peer.connect_to_relay(relay_host, relay_port)

func host_game():
	is_host = true
	node_tunnel_peer.host()

func join_game(host_oid: String):
	is_host = false
	node_tunnel_peer.join(host_oid)

func leave_room():
	node_tunnel_peer.leave_room()

# Signal handlers
func _on_relay_connected(oid):
	online_id = oid
	emit_signal("relay_connected", oid)

func _on_hosting():
	emit_signal("hosting")
	# In a real game, you would now wait for players to join and then emit match_found

func _on_joined():
	emit_signal("joined")
	# In a real game, you would now notify the host and start the match

func _on_room_left():
	emit_signal("room_left")

# Optionally, add logic to track players and emit match_found(players) when ready
