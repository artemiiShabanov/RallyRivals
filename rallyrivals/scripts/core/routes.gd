class_name Routes
## Canonical scene paths for the game-flow spine — every Flow.goto target in one place, so renaming
## a screen is a single edit. Unbuilt entries are safe: Flow.goto push_errors and no-ops on a missing
## scene until the task that creates it lands.

const TITLE := "res://scenes/ui/title.tscn"
const SAVE_SLOTS := "res://scenes/ui/save_slots.tscn"
const SETTINGS := "res://scenes/ui/settings.tscn"
const CAREER_HUB := "res://scenes/ui/career_hub.tscn"
const CAREER_MAP := "res://scenes/ui/career_map.tscn"    ## chapter's races + boss gate (code-ui-career-map)
const GARAGE := "res://scenes/ui/garage.tscn"
const SHOP := "res://scenes/ui/shop.tscn"
const PRE_RACE := "res://scenes/ui/pre_race.tscn"
const GP_HUB := "res://scenes/ui/gp_hub.tscn"        ## grand-prix intermediate menu (qualify ⇄ race)
const RESULTS := "res://scenes/ui/results.tscn"
const RACE := "res://scenes/race/race.tscn"          ## the one real race (built by code-race-director)
