class_name ListenLink
extends RefCounted

## Listen-server. One host keeps Helion Dock and First Soil. A second captain joins by IP or code.

const PORT := 24565
const SOLO_LINE := "No listen port on this board. Flying solo."
const JOIN_LINE := "No listen port on this page. New keel still flies solo."

## Headless tests close the port without touching ENet. The web build is already closed.
static var block_port := false

var role := "offline"
var code := ""
var conn: ENetConnection
var local_peer: ENetPacketPeer
var peers: Array = []
var inbox: Array = []
var connected := false
var greeted := false
var class_id := "vesper"
var player_id := ""
var last_error := ""


func no_port() -> bool:
	return OS.has_feature("web") or block_port


func open_host() -> String:
	if no_port():
		last_error = SOLO_LINE
		conn = null
		role = "offline"
		return last_error
	conn = ENetConnection.new()
	var err: int = conn.create_host_bound("0.0.0.0", PORT, 8)
	if err != OK:
		err = conn.create_host_bound("127.0.0.1", PORT, 8)
	if err != OK:
		last_error = "The dock would not open a port."
		conn = null
		return last_error
	role = "host"
	code = str(PORT)
	last_error = ""
	return ""


func join(address: String, ship_class: String, who: String) -> String:
	if no_port():
		last_error = JOIN_LINE
		conn = null
		local_peer = null
		role = "offline"
		return last_error
	var parsed := parse_address(address)
	conn = ENetConnection.new()
	var err: int = conn.create_host(2)
	if err != OK:
		last_error = "The keel could not open a socket."
		conn = null
		return last_error
	local_peer = conn.connect_to_host(str(parsed.host), int(parsed.port))
	if local_peer == null:
		last_error = "No route to that dock."
		conn = null
		return last_error
	role = "client"
	class_id = ship_class
	player_id = who
	code = str(parsed.port)
	greeted = false
	connected = false
	last_error = ""
	return ""


func close() -> void:
	if conn != null:
		conn.destroy()
	conn = null
	local_peer = null
	peers = []
	inbox = []
	role = "offline"
	connected = false
	greeted = false


func pump() -> void:
	if conn == null:
		return
	for _i in 12:
		var ev: Array = conn.service(0)
		if ev.is_empty():
			return
		var kind := int(ev[0])
		if kind == ENetConnection.EVENT_NONE or kind == ENetConnection.EVENT_ERROR:
			return
		var peer: ENetPacketPeer = ev[1]
		if kind == ENetConnection.EVENT_CONNECT:
			connected = true
			if role == "host":
				if peer != null and not peers.has(peer):
					peers.append(peer)
			else:
				local_peer = peer
		elif kind == ENetConnection.EVENT_DISCONNECT:
			peers.erase(peer)
			if local_peer == peer:
				connected = false
				local_peer = null
				greeted = false
		elif kind == ENetConnection.EVENT_RECEIVE and peer != null:
			var packet: PackedByteArray = peer.get_packet()
			var data = JSON.parse_string(packet.get_string_from_utf8())
			if typeof(data) == TYPE_DICTIONARY:
				inbox.append(data)


func take_host(sim) -> void:
	if role != "host":
		return
	pump()
	var pending: Array = inbox.duplicate()
	inbox.clear()
	for msg in pending:
		var row: Dictionary = msg
		var op := str(row.get("op", ""))
		if op == "hello":
			var pid := str(row.get("player_id", ""))
			if pid != "" and sim.human_by_player(pid) == null:
				sim.admit(str(row.get("class_id", "vesper")), pid)
		elif op == "cmd":
			var pid := str(row.get("player_id", ""))
			var cmd: Dictionary = row.get("cmd", {})
			sim.commands[pid] = cmd
		elif op == "chat":
			sim.post_chat(str(row.get("player_id", "")), str(row.get("text", "")))


func take_client(sim) -> void:
	if role != "client":
		return
	pump()
	if connected and not greeted and local_peer != null:
		_send(local_peer, {"op": "hello", "class_id": class_id, "player_id": player_id})
		greeted = true
	var pending: Array = inbox.duplicate()
	inbox.clear()
	for msg in pending:
		var row: Dictionary = msg
		if str(row.get("op", "")) == "snap":
			sim.apply_snapshot(row)


func send_cmd(who: String, cmd: Dictionary) -> void:
	if role != "client" or local_peer == null or not connected:
		return
	_send(local_peer, {"op": "cmd", "player_id": who, "cmd": cmd})


func send_chat(who: String, text: String) -> void:
	if role != "client" or local_peer == null or not connected:
		return
	_send(local_peer, {"op": "chat", "player_id": who, "text": text})


func broadcast(sim) -> void:
	if role != "host" or peers.is_empty():
		return
	var snap: Dictionary = sim.net_snapshot()
	snap["op"] = "snap"
	for peer in peers:
		if peer == null:
			continue
		_send(peer, snap)


static func parse_address(raw: String) -> Dictionary:
	var text := raw.strip_edges()
	if text == "":
		return {"host": "127.0.0.1", "port": PORT}
	if text.is_valid_int():
		return {"host": "127.0.0.1", "port": int(text)}
	if text.contains(":"):
		var bits := text.split(":")
		return {"host": str(bits[0]), "port": int(bits[bits.size() - 1])}
	return {"host": text, "port": PORT}


func _send(peer: ENetPacketPeer, msg: Dictionary) -> void:
	if peer == null:
		return
	var raw := JSON.stringify(msg).to_utf8_buffer()
	peer.send(0, raw, ENetPacketPeer.FLAG_RELIABLE)
