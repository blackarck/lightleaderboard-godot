# LightLeaderboard — Godot SDK

Official Godot 4 addon for [LightLeaderboard](https://leaderboard.goproso.com).

## Installation

1. Copy the `addons/lightleaderboard/` folder into your project's `addons/` directory.
2. In Godot, go to **Project → Project Settings → Plugins** and enable **LightLeaderboard**.
3. Add `LightLeaderboard` as an **AutoLoad** singleton (**Project → Project Settings → AutoLoad**, point it to `res://addons/lightleaderboard/LightLeaderboard.gd`).

## Quick start

```gdscript
func _ready() -> void:
    LightLeaderboard.configure("your-api-key", "your-game-id")

func _on_game_over(score: float) -> void:
    var result = await LightLeaderboard.submit_score({
        score       = score,
        player_ref_id = "player-123",
        player_name = "Alice",
    })
    print("Rank #%d of %d" % [result.rank, result.total_players])
```

## API reference

### `configure(api_key, game_id, score_secret?, base_url?)`

Must be called once before any other method (e.g. in `_ready`).

| Parameter | Type | Description |
|---|---|---|
| `api_key` | `String` | Your game's API key from the dashboard |
| `game_id` | `String` | Your game's ID from the dashboard |
| `score_secret` | `String` | Optional — enables HMAC-SHA256 score signing |
| `base_url` | `String` | Optional — override the API base URL |

---

### `await submit_score(options) → Dictionary`

Submit a score. Returns the player's new rank immediately.

**Options:**

| Key | Type | Description |
|---|---|---|
| `score` | `float` | **(required)** The score to record |
| `player_ref_id` | `String` | Your internal player ID |
| `player_name` | `String` | Display name on the leaderboard |
| `play_time_ms` | `int` | Run duration in milliseconds |
| `season_id` | `String` | Season bucket |
| `team_id` | `String` | Team bucket |
| `submission_id` | `String` | Idempotency key |
| `metadata` | `Dictionary` | Arbitrary JSON metadata |
| `game_stat_txt1/2/3` | `String` | Custom text stat slots |
| `game_stat_int1/2/3` | `int` | Custom numeric stat slots |

**Returns:**

```gdscript
{
    id:               int,
    rank:             int or null,
    is_personal_best: bool,
    total_players:    int or null,
    deduped:          bool,
}
```

---

### `await get_leaderboard(options?) → Dictionary`

Fetch the leaderboard (one entry per player, their personal best, by default).

**Options:**

| Key | Type | Description |
|---|---|---|
| `limit` | `int` | Entries to return (1–100, default 20) |
| `offset` | `int` | Pagination offset (default 0) |
| `period` | `String` | `"all"`, `"weekly"`, or `"monthly"` |
| `season` | `String` | Filter by season ID |
| `team` | `String` | Filter by team ID |
| `all_entries` | `bool` | `true` = every raw submission instead of best-per-player |

**Returns:**

```gdscript
{
    entries:     Array,   # [{id, rank, player_ref_id, player_name, score, ...}]
    score_order: String,  # "asc" or "desc"
    period:      String,
    season:      String or null,
    team:        String or null,
    limit:       int,
    offset:      int,
}
```

---

### `await get_player_rank(player_ref_id, options?) → Dictionary`

Get a player's current rank, score, and percentile.

**Options:** `period`, `season`, `team`

**Returns:**

```gdscript
{
    player_ref_id: String,
    player_name:   String or null,
    rank:          int or null,
    score:         float or null,
    total_players: int or null,
    percentile:    float or null,  # 0–100, higher is better
    period:        String,
    season:        String or null,
    team:          String or null,
    score_order:   String,
}
```

---

### `await get_centric_leaderboard(player_ref_id, options?) → Dictionary`

Fetch the leaderboard centered on a player — useful for showing the players just above and below them.

**Options:** `limit`, `period`, `season`, `team`

**Returns:**

```gdscript
{
    entries:     Array,
    player_rank: int or null,
    period:      String,
    season:      String or null,
    team:        String or null,
    score_order: String,
}
```

---

### `await get_player(player_ref_id) → Dictionary`

Fetch a player's profile.

**Returns:**

```gdscript
{
    player_name: String or null,
    avatar_url:  String or null,
    team_id:     String or null,
    level:       int or null,
    country:     String or null,
    device:      String or null,
    created_at:  String,
    updated_at:  String,
}
```

---

### `await update_player(player_ref_id, options) → void`

Create or update a player's profile. Fields are merged — omitted fields keep their existing values.

**Options:** `player_name`, `avatar_url`, `team_id`, `level`, `country`, `device`

---

### `await get_player_scores(player_ref_id, options?) → Dictionary`

Fetch all of a player's submissions, newest first.

**Options:** `limit` (1–200), `offset`, `season`, `team`

**Returns:**

```gdscript
{
    player_ref_id: String,
    entries:       Array,  # [{id, score, play_time_ms, season_id, team_id, metadata, ...}]
    best_score:    float or null,
    total:         int,
    limit:         int,
    offset:        int,
    score_order:   String,
}
```

---

## Error handling

When an API call fails (network error or API error), the method returns an empty `Dictionary` (`{}`) and logs an error via `push_error`. Check for an empty result before using:

```gdscript
var result = await LightLeaderboard.submit_score({score = 9500})
if result.is_empty():
    print("Submission failed — check the Godot error log")
    return
print("Rank: ", result.rank)
```

## Score signing

If you enabled **Require signed scores** on your game in the dashboard, pass your score secret to `configure`:

```gdscript
LightLeaderboard.configure("api-key", "game-id", "your-score-secret")
```

The SDK automatically signs every `submit_score` call with HMAC-SHA256 using Godot's built-in `HMACContext`.

## Requirements

- Godot 4.0+
- Internet access enabled in your export settings
