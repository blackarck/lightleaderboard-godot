## LightLeaderboard SDK for Godot 4
##
## Usage (autoload):
##   LightLeaderboard.configure("your-api-key", "your-game-id")
##
## Usage (manual instance):
##   var lb = LightLeaderboard.new()
##   lb.configure("your-api-key", "your-game-id")
##
## All methods are async — use await:
##   var result = await lb.submit_score({score = 9500, player_ref_id = "p1", player_name = "Alice"})
##   print("Rank: ", result.rank)

class_name LightLeaderboard
extends Node

const DEFAULT_BASE_URL := "https://leaderboard.goproso.com"

var _api_key: String = ""
var _game_id: String = ""
var _base_url: String = DEFAULT_BASE_URL
var _score_secret: String = ""


## Configure the client. Must be called before any API method.
## api_key    — your game's API key from the dashboard
## game_id    — your game's reference ID from the dashboard
## score_secret — optional; enables HMAC-SHA256 score signing
## base_url   — optional; override the API base URL
func configure(
	api_key: String,
	game_id: String,
	score_secret: String = "",
	base_url: String = DEFAULT_BASE_URL
) -> void:
	assert(api_key != "", "LightLeaderboard: api_key is required")
	assert(game_id != "", "LightLeaderboard: game_id is required")
	_api_key = api_key
	_game_id = game_id
	_score_secret = score_secret
	_base_url = base_url.rstrip("/")


# ── Score submission ──────────────────────────────────────────────────────────

## Submit a score. Returns a Dictionary with keys:
##   id, rank, is_personal_best, total_players, deduped
##
## options keys (all optional except score):
##   score (float, required), player_ref_id, player_name, play_time_ms,
##   season_id, team_id, submission_id, metadata (Dictionary),
##   game_stat_txt1/2/3 (String), game_stat_int1/2/3 (int)
func submit_score(options: Dictionary) -> Dictionary:
	assert(_api_key != "", "LightLeaderboard: call configure() first")
	var body := JSON.stringify(options)
	var extra_headers: PackedStringArray = []
	if _score_secret != "":
		var sig := _hmac_sha256(_score_secret, body)
		extra_headers.append("x-score-signature: sha256=" + sig)
	var data = await _request("POST", "/scores", body, {}, extra_headers)
	return {
		id             = data.get("id", 0),
		rank           = data.get("rank", null),
		is_personal_best = data.get("isPersonalBest", false),
		total_players  = data.get("totalPlayers", null),
		deduped        = data.get("deduped", false),
	}


# ── Leaderboard ───────────────────────────────────────────────────────────────

## Fetch the leaderboard. Returns a Dictionary with keys:
##   entries (Array of Dictionaries), score_order, period, season, team, limit, offset
##
## options keys (all optional):
##   limit (int 1-100), offset (int), period ("all"|"weekly"|"monthly"),
##   season (String), team (String), all_entries (bool)
func get_leaderboard(options: Dictionary = {}) -> Dictionary:
	assert(_api_key != "", "LightLeaderboard: call configure() first")
	var params := {}
	for key in options:
		if key == "all_entries":
			if options[key]:
				params["allEntries"] = "true"
		else:
			params[_to_camel(key)] = options[key]
	var data = await _request("GET", "/leaderboard", "", params)
	return {
		entries     = _map_entries(data.get("entries", [])),
		score_order = data.get("scoreOrder", "desc"),
		period      = data.get("period", "all"),
		season      = data.get("season", null),
		team        = data.get("team", null),
		limit       = data.get("limit", 20),
		offset      = data.get("offset", 0),
	}


# ── Rank ──────────────────────────────────────────────────────────────────────

## Get a player's rank, score, and percentile. Returns a Dictionary with keys:
##   player_ref_id, player_name, rank, score, total_players, percentile,
##   period, season, team, score_order
##
## options keys (all optional): period, season, team
func get_player_rank(player_ref_id: String, options: Dictionary = {}) -> Dictionary:
	assert(_api_key != "", "LightLeaderboard: call configure() first")
	var params := _snake_to_camel_dict(options)
	var data = await _request("GET", "/players/" + player_ref_id.uri_encode() + "/rank", "", params)
	return {
		player_ref_id = data.get("playerRefId", ""),
		player_name   = data.get("playerName", null),
		rank          = data.get("rank", null),
		score         = data.get("score", null),
		total_players = data.get("totalPlayers", null),
		percentile    = data.get("percentile", null),
		period        = data.get("period", "all"),
		season        = data.get("season", null),
		team          = data.get("team", null),
		score_order   = data.get("scoreOrder", "desc"),
	}


# ── Centric leaderboard ───────────────────────────────────────────────────────

## Fetch the leaderboard centered on a player. Returns a Dictionary with keys:
##   entries (Array), player_rank, period, season, team, score_order
##
## options keys (all optional): limit, period, season, team
func get_centric_leaderboard(player_ref_id: String, options: Dictionary = {}) -> Dictionary:
	assert(_api_key != "", "LightLeaderboard: call configure() first")
	var params := _snake_to_camel_dict(options)
	var data = await _request("GET", "/players/" + player_ref_id.uri_encode() + "/centric", "", params)
	return {
		entries     = _map_entries(data.get("entries", [])),
		player_rank = data.get("playerRank", null),
		period      = data.get("period", "all"),
		season      = data.get("season", null),
		team        = data.get("team", null),
		score_order = data.get("scoreOrder", "desc"),
	}


# ── Player profile ────────────────────────────────────────────────────────────

## Fetch a player's profile. Returns a Dictionary with keys:
##   player_name, avatar_url, team_id, level, country, device, created_at, updated_at
func get_player(player_ref_id: String) -> Dictionary:
	assert(_api_key != "", "LightLeaderboard: call configure() first")
	var data = await _request("GET", "/players/" + player_ref_id.uri_encode(), "", {})
	var player = data.get("player", data)
	return {
		player_name = player.get("playerName", null),
		avatar_url  = player.get("avatarUrl", null),
		team_id     = player.get("teamId", null),
		level       = player.get("level", null),
		country     = player.get("country", null),
		device      = player.get("device", null),
		created_at  = player.get("createdAt", ""),
		updated_at  = player.get("updatedAt", ""),
	}


## Create or update a player's profile. Fields are merged — omitted fields
## keep their existing values.
##
## options keys (all optional): player_name, avatar_url, team_id, level, country, device
func update_player(player_ref_id: String, options: Dictionary) -> void:
	assert(_api_key != "", "LightLeaderboard: call configure() first")
	var body_dict := _snake_to_camel_dict(options)
	await _request("PUT", "/players/" + player_ref_id.uri_encode(), JSON.stringify(body_dict), {})


# ── Score history ─────────────────────────────────────────────────────────────

## Fetch all of a player's submissions, newest first. Returns a Dictionary with:
##   player_ref_id, entries (Array), best_score, total, limit, offset, score_order
##
## options keys (all optional): limit (1-200), offset, season, team
func get_player_scores(player_ref_id: String, options: Dictionary = {}) -> Dictionary:
	assert(_api_key != "", "LightLeaderboard: call configure() first")
	var params := _snake_to_camel_dict(options)
	var data = await _request("GET", "/players/" + player_ref_id.uri_encode() + "/scores", "", params)
	return {
		player_ref_id = data.get("playerRefId", ""),
		entries       = _map_score_entries(data.get("entries", [])),
		best_score    = data.get("bestScore", null),
		total         = data.get("total", 0),
		limit         = data.get("limit", 50),
		offset        = data.get("offset", 0),
		score_order   = data.get("scoreOrder", "desc"),
	}


# ── Internal HTTP ─────────────────────────────────────────────────────────────

func _request(
	method: String,
	path: String,
	body: String,
	params: Dictionary,
	extra_headers: PackedStringArray = []
) -> Dictionary:
	var url := _build_url(path, params)
	var headers: PackedStringArray = [
		"Authorization: Bearer " + _api_key,
		"Content-Type: application/json",
	]
	headers.append_array(extra_headers)

	var http := HTTPRequest.new()
	add_child(http)

	var method_const: int
	match method:
		"GET":    method_const = HTTPClient.METHOD_GET
		"POST":   method_const = HTTPClient.METHOD_POST
		"PUT":    method_const = HTTPClient.METHOD_PUT
		"DELETE": method_const = HTTPClient.METHOD_DELETE
		_:        method_const = HTTPClient.METHOD_GET

	var err := http.request(url, headers, method_const, body)
	if err != OK:
		http.queue_free()
		push_error("LightLeaderboard: HTTP request failed with error " + str(err))
		return {}

	var response = await http.request_completed
	http.queue_free()

	var _result: int  = response[0]
	var status: int   = response[1]
	var _hdrs: Array  = response[2]
	var raw: PackedByteArray = response[3]

	var text := raw.get_string_from_utf8()
	var json := JSON.new()
	var parse_err := json.parse(text)
	if parse_err != OK:
		push_error("LightLeaderboard: failed to parse response (HTTP %d)" % status)
		return {}

	var data = json.get_data()
	if data == null or not (data is Dictionary):
		push_error("LightLeaderboard: unexpected response format")
		return {}

	if status < 200 or status >= 300 or data.get("ok") == false:
		var msg: String = data.get("error", "HTTP %d" % status)
		push_error("LightLeaderboard: API error — " + msg)
		return {}

	return data


func _build_url(path: String, params: Dictionary) -> String:
	var url := _base_url + "/api/v1/games/" + _game_id.uri_encode() + path
	if params.is_empty():
		return url
	var parts: PackedStringArray = []
	for key in params:
		var val = params[key]
		if val != null:
			parts.append(key.uri_encode() + "=" + str(val).uri_encode())
	if parts.size() > 0:
		url += "?" + "&".join(parts)
	return url


# ── HMAC-SHA256 ───────────────────────────────────────────────────────────────

func _hmac_sha256(key: String, data: String) -> String:
	var ctx := HMACContext.new()
	var err := ctx.start(HashingContext.HASH_SHA256, key.to_utf8_buffer())
	if err != OK:
		push_error("LightLeaderboard: HMACContext.start failed")
		return ""
	ctx.update(data.to_utf8_buffer())
	var sig := ctx.finish()
	return sig.hex_encode()


# ── Helpers ───────────────────────────────────────────────────────────────────

# Convert snake_case key to camelCase for the API
func _to_camel(snake: String) -> String:
	var parts := snake.split("_")
	if parts.size() == 0:
		return snake
	var result := parts[0]
	for i in range(1, parts.size()):
		result += parts[i].capitalize()
	return result


# Convert a full snake_case dict to camelCase keys
func _snake_to_camel_dict(d: Dictionary) -> Dictionary:
	var out := {}
	for key in d:
		out[_to_camel(key)] = d[key]
	return out


func _map_entries(raw: Array) -> Array:
	var out := []
	for e in raw:
		out.append({
			id           = e.get("id", 0),
			rank         = e.get("rank", 0),
			player_ref_id = e.get("playerRefId", null),
			player_name  = e.get("playerName", null),
			score        = e.get("score", 0.0),
			play_time_ms = e.get("playTimeMs", null),
			season_id    = e.get("seasonId", null),
			team_id      = e.get("teamId", null),
			metadata     = e.get("metadata", null),
			created_at   = e.get("createdAt", ""),
		})
	return out


func _map_score_entries(raw: Array) -> Array:
	var out := []
	for e in raw:
		out.append({
			id              = e.get("id", 0),
			score           = e.get("score", 0.0),
			play_time_ms    = e.get("playTimeMs", null),
			season_id       = e.get("seasonId", null),
			team_id         = e.get("teamId", null),
			metadata        = e.get("metadata", null),
			created_at      = e.get("createdAt", ""),
			game_stat_txt1  = e.get("gameStatTxt1", null),
			game_stat_txt2  = e.get("gameStatTxt2", null),
			game_stat_txt3  = e.get("gameStatTxt3", null),
			game_stat_int1  = e.get("gameStatInt1", null),
			game_stat_int2  = e.get("gameStatInt2", null),
			game_stat_int3  = e.get("gameStatInt3", null),
		})
	return out
