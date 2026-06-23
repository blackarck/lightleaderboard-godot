## LightLeaderboard Godot SDK — example usage
## Attach to any Node in your scene. Assumes LightLeaderboard is set up as an AutoLoad.

extends Node

func _ready() -> void:
	LightLeaderboard.configure("YOUR_API_KEY", "YOUR_GAME_ID")
	_run_examples()


func _run_examples() -> void:
	# Submit a score
	var submit = await LightLeaderboard.submit_score({
		score         = 9500.0,
		player_ref_id = "player-123",
		player_name   = "Alice",
		play_time_ms  = 62340,
	})
	if not submit.is_empty():
		print("Submitted! Rank #%d of %d (PB: %s)" % [
			submit.rank, submit.total_players,
			str(submit.is_personal_best)
		])

	# Top 10 leaderboard
	var lb = await LightLeaderboard.get_leaderboard({limit = 10})
	if not lb.is_empty():
		for entry in lb.entries:
			print("#%d  %s  %s" % [entry.rank, entry.player_name, entry.score])

	# Player rank
	var rank_data = await LightLeaderboard.get_player_rank("player-123")
	if not rank_data.is_empty():
		print("Rank: #%d  Percentile: %.1f" % [rank_data.rank, rank_data.percentile])

	# Centric leaderboard (players around Alice)
	var centric = await LightLeaderboard.get_centric_leaderboard("player-123", {limit = 5})
	if not centric.is_empty():
		print("Centric around rank %d:" % centric.player_rank)
		for entry in centric.entries:
			print("  #%d  %s" % [entry.rank, entry.player_name])

	# Update player profile
	await LightLeaderboard.update_player("player-123", {
		player_name = "Alice",
		country     = "US",
		level       = 5,
	})

	# Score history
	var history = await LightLeaderboard.get_player_scores("player-123", {limit = 5})
	if not history.is_empty():
		print("Last %d scores (best: %s):" % [history.entries.size(), history.best_score])
		for entry in history.entries:
			print("  %s  score=%s" % [entry.created_at, entry.score])
