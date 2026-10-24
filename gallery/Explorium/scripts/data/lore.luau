--[[
Texts found in the world: ancient tablets of the sea people, signs and notes left by explorers.

Levels refer to them by id (`data = { lore = "tide" }` on a tablet or a sign). Read texts are listed in the notebook.

The sea people wrote in Greek letters, and the explorer can't read their language: ancient texts show as gibberish
in Greek capitals (`scramble`), until the explorer finds the artefact that translates them (`TRANSLATOR`, on a
deeper floor). The real text is kept here, for when they can read it.
]]
const loader = require("@vectarine/loader")
const types = require("../types")

export type Lore = {
	title: string,
	--- Who wrote it, shown as the name in the dialog box
	author: string,
	lines: { string },
	--- Ancient writing of the sea people: unreadable without the translator. Reading it for the first time gives experience.
	ancient: boolean?,
}

const module = loader.init() or {}

--- The artefact that lets the explorer understand the language of the sea people (found on a deeper floor)
module.TRANSLATOR = "tide_lexicon"

function module.canRead(game: types.Game, text: Lore): boolean
	return not text.ancient or game.player.artefacts[module.TRANSLATOR] == true
end

--- The Greek capitals, with those that don't look like Latin letters twice, so that the writing looks foreign
const LETTERS = {
	"Α",
	"Β",
	"Γ",
	"Δ",
	"Ε",
	"Ζ",
	"Η",
	"Θ",
	"Ι",
	"Κ",
	"Λ",
	"Μ",
	"Ν",
	"Ξ",
	"Ο",
	"Π",
	"Ρ",
	"Σ",
	"Τ",
	"Υ",
	"Φ",
	"Χ",
	"Ψ",
	"Ω",
	"Γ",
	"Δ",
	"Θ",
	"Λ",
	"Ξ",
	"Π",
	"Σ",
	"Φ",
	"Ψ",
	"Ω",
}

--- The line as the explorer sees it: each letter becomes a Greek capital, words and punctuation keep their place.
--- The same line always gives the same gibberish.
function module.scramble(line: string): string
	local result = {}
	local hash = 7
	for i = 1, #line do
		local char = string.sub(line, i, i)
		hash = (hash * 31 + string.byte(char) + i * 17) % 1000003
		if string.match(char, "%a") then
			table.insert(result, LETTERS[hash % #LETTERS + 1])
		else
			table.insert(result, char)
		end
	end
	return table.concat(result)
end

module.texts = {
	-- Notes of explorers
	first_note = {
		title = "A note in a bottle",
		author = "Note",
		lines = {
			"Day 31. The pools are clean, the figs are sweet, the rats are rude.",
			"Wren says the ants are friendly. Wren says a lot of things.",
			"If you read this, I went east, towards the light of the mushrooms. Don't follow the worms down. - M.",
		},
	},
	camp_sign = {
		title = "Wren's sign",
		author = "Sign",
		lines = { "WREN'S CAMP. Fire, water, figs. No wasps allowed." },
	},
	hollow_sign = {
		title = "A warning",
		author = "Sign",
		lines = {
			"DARK HOLLOW. A MAZE of ledges over a long, long fall. And the dark in there eats the light of torches.",
			"Don't go in without a real lantern and a map. Ask Wren for the map, at the camp. Wren is me. - W.",
		},
	},
	wren_hollow_note = {
		title = "A note, scratched with charcoal",
		author = "Note",
		lines = {
			"Day 2 in the Hollow. The torch is out. Not burnt out: out, as if the dark drank it.",
			"Mapping by touch now. Left hand on the rock, counting steps. Every pebble I drop falls for ever.",
			"If I get out of here, I'm never coming back without a better light. The sea people must have had one. - Wren",
		},
	},
	den_sign = {
		title = "Scratches on the wall",
		author = "Scratches",
		lines = {
			"Deep claw marks cross the rock. Something big lives beyond this point, and it does not like guests.",
		},
	},
	-- Tablets of the sea people
	tide = {
		title = "The people of the tide",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"WE WERE THE PEOPLE OF THE TIDE. WE SAILED THE GREEN SEA ABOVE.",
			"WHEN THE SEA LEFT US, WE FOLLOWED THE WATER DOWN, WHERE THE WATER STILL SINGS.",
		},
	},
	first_flame = {
		title = "The first flame",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"WHEN THE GREEN SEA LEFT US, WE CARRIED THE FIRE OF THE LIGHTHOUSE DOWN WITH US. IT NEEDS NO OIL.",
			"WE LEAVE IT BURNING HERE, FOR THOSE WHO FOLLOW US INTO THE DARK. TAKE IT, AND DO NOT BE AFRAID.",
		},
	},
	tunnelers = {
		title = "The great tunnelers",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE GREAT TUNNELERS ARE OUR FRIENDS. WE FEED THEM FIGS, THEY DIG OUR HALLS.",
			"NEVER WAKE A TUNNELER IN ITS DEN. EVEN FRIENDS HAVE CLAWS.",
		},
	},
	machines = {
		title = "The tireless servants",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"OUR SERVANTS OF BRONZE DO NOT SLEEP. THEY GUARD THE HALLS WHILE THE CHILDREN OF THE TIDE GO DEEPER.",
			"THE CORES OF LIGHTNING WAKE THE GATES THAT FOLD THE ROADS.",
		},
	},
	lower_stairs = {
		title = "The lower stairs",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"BEYOND THE DEN OF THE TUNNELER, THE STAIRS GO DOWN TO THE DRY HALLS.",
			"THE COUNCIL HAS SEALED THE WAY WITH VINES. ONLY THOSE WHO CLIMB MAY PASS.",
		},
	},

	-- The desert: notes and signs
	steps_note = {
		title = "A dry notebook",
		author = "Note",
		lines = {
			"Day 9 below the stairs. The water ran out on day 6. The cistern here is as dry as my throat.",
			"The cactus fruits kept us going: their water is sweet, if you can stand the spines.",
			"The ants know where water is. Follow their marks to the east. I can't walk any more. - T.",
		},
	},
	anthill_sign = {
		title = "A sign of the colony",
		author = "Sign",
		lines = { "THE ANTHILL. Water for friends. Figs very welcome. *click*" },
	},
	dunes_sign = {
		title = "A warning",
		author = "Sign",
		lines = {
			"STORMS. When the sand rises, keep to the rocks and wait. The storm always passes. - Mandi, guard of the colony",
		},
	},
	gorge_sign = {
		title = "Scratched in the rock",
		author = "Scratches",
		lines = {
			"The wind of the gorge throws back whoever walks against it. Only the eye of the Warden sees through the howl.",
		},
	},
	-- The desert: tablets of the sea people
	diggers = {
		title = "The diggers",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE ANTS DIG. THE WARDEN WATCHES. THE CITY DRINKS.",
			"SO IT WAS, SO IT IS, SO IT WILL BE, AS LONG AS THE SUN WARDEN STANDS.",
		},
	},
	pump_gate = {
		title = "The gate of the Great Pump",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE GATE OF THE GREAT PUMP OPENS FOR THE ARCHER WHO WAKES THE SUN'S EYE.",
			"WATER FOR THE CITY. THIRST FOR THOSE WHO DIG.",
		},
	},
	pump_hall = {
		title = "The three valves",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THREE VALVES FEED THE GREAT PUMP. WHEN THE SAND CAME, WE WALLED THE NORTH VALVE BEHIND STONE.",
			"THE MASONS LEFT THE WALL CRACKED, SO THAT IT COULD BE BROKEN AGAIN ONE DAY.",
		},
	},
	council = {
		title = "The council chamber",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THIS IS THE CHAMBER OF THE COUNCIL OF THE HIGH TIDE, A PLACE OF PEACE.",
			"NO BLADE MAY CROSS ITS DOOR. COME WITH EMPTY HANDS, OR DO NOT COME.",
		},
	},
	warden = {
		title = "The Sun Warden",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE SUN WARDEN NEVER SLEEPS. ITS EYE SEES THROUGH SAND AND STORM.",
			"WHOEVER HOLDS THE EYE WALKS IN THE STORM, UNTOUCHED.",
		},
	},
	marshes = {
		title = "The way to the marshes",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"BELOW THE HOWLING GORGE, THE STAIRS GO DOWN TO THE MARSHES, WHERE THE CITY SENT ITS SICK.",
			"DO NOT DRINK THE GREEN WATER.",
		},
	},

	-- The wetlands: notes and signs
	nettle_sign = {
		title = "A sign by the hut",
		author = "Sign",
		lines = { "NETTLE'S HUT. Remedies, brews, advice. Wipe your feet." },
	},
	mud_sign = {
		title = "A warning",
		author = "Sign",
		lines = { "DON'T STAND STILL IN THE MUD. IT EATS THE ONES WHO WAIT. - Wick" },
	},
	smuggler_note = {
		title = "A soggy note",
		author = "Note",
		lines = {
			"Hid the goods behind the old wall again, where the nets dry. Nobody looks twice at a cracked wall. - Fen",
		},
	},
	-- The wetlands: tablets of the sea people
	four_waters = {
		title = "The four waters",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"FOUR WATERS MAKE THE CITY: THE HIGH TIDE THAT RULES, THE BRONZE THAT BUILDS, THE SALT THAT SAILS, AND THE CLAY THAT DIGS.",
			"EACH WATER KNOWS ITS PLACE, AND THE CITY STANDS.",
		},
	},
	the_ebb = {
		title = "The Ebb",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"WHO FALLS SICK FALLS FROM THEIR WATER. THE SICK ARE THE EBB, AND THE EBB GOES DOWN TO THE MARSHES.",
			"DO NOT SPEAK THE NAMES OF THE EBB. THE TIDE HAS FORGOTTEN THEM.",
		},
	},
	house_of_healing = {
		title = "The House of Healing",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE HOUSE OF HEALING SERVES THE HIGH TIDE. THE HEALERS WEAR THE BEAK, AND FEAR NO AIR.",
			"THE HEAD PHYSICIAN KEEPS THE MASKS IN HIS OFFICE. HIS SEAL OPENS IT.",
		},
	},
	surgery = {
		title = "The surgery",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE HOUSE OF HEALING OPENS ITS DOORS TO THE SICK ALONE.",
			"THE HEALTHY HAVE NOTHING TO DO IN THE SURGERY.",
		},
	},
	physician = {
		title = "The physician's journal",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE CHIEF MENDER KEEPS MY SEAL WHEN I REST. IT HAS BEGUN TO MEND THINGS THAT SHOULD NOT BE MENDED.",
			"TOMORROW I WILL HAVE IT SHUT DOWN. IT LOOKED AT ME STRANGELY TODAY.",
		},
	},
	quarantine = {
		title = "Scratched on the quarantine wall",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"HERE THE EBB WAIT. THE HEALERS DO NOT ENTER. THEY PASS THE BREAD UNDER THE DOOR.",
			"WE ARE NOT A WATER ANY MORE. WE ARE A PUDDLE. BUT A PUDDLE REMEMBERS THE RAIN.",
		},
	},
	shrine = {
		title = "The basin of the Ebb",
		author = "Ancient tablet",
		ancient = true,
		lines = { "LAY A WHITE LILY BEFORE THE BASIN OF THE EBB, AND THE TIDE WILL REMEMBER YOU." },
	},
	bell = {
		title = "The bell of the ferry",
		author = "Ancient tablet",
		ancient = true,
		lines = { "STRIKE THE BELL THREE TIMES, SLOW AS THE BREATH OF THE TIDE, AND THE FERRY WILL COME FOR YOU." },
	},
	frog_king = {
		title = "The king of the mire",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE KING OF THE MIRE GREW FAT ON WHAT WE POURED. A STONE GROWS IN ITS BELLY THAT DRINKS ALL POISON.",
			"WHEN ITS SHADOW GROWS, STEP ASIDE.",
		},
	},
	the_fen = {
		title = "The fen",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"WE POURED OUR POISONS IN THE FEN, FAR FROM THE CITY. THE WATER TURNED GREEN, AND THE FROGS GREW.",
			"NONE OF THE HIGH TIDE EVER SAW IT.",
		},
	},
	cold_stores = {
		title = "The cold below",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"BELOW THE FEN, THE COLD. THE CITY KEPT ITS FROZEN STORES THERE, AND ITS FROZEN SECRETS.",
			"THE HOUSE OF HEALING SENDS ITS DRAUGHT OF SLEEP DOWN THE STAIRS, CRATE AFTER CRATE. FOR WHOM, THE HEALERS DO NOT ASK.",
		},
	},

	-- The frontier: notes and signs
	brazier_note = {
		title = "A frozen notebook",
		author = "Note",
		lines = {
			"Day 2 in the cold. The fire in the brazier saved my life. They still burn, the old things, if you light them.",
			"Light them, whoever you are. And keep out of the snow when you can: the snow drinks your warmth. - M.",
		},
	},
	rimehold_sign = {
		title = "A sign of the village",
		author = "Sign",
		lines = { "RIMEHOLD. Warm hearths, hot broth, loud children. Wipe the snow off your boots. - the Frostborn" },
	},
	yard_sign = {
		title = "The board of the yard",
		author = "Sign",
		lines = { "THE YARD. Snowball champions only. Record: 13 points. (Sorrel: 40. Sorrel cheated.)" },
	},
	glare_sign = {
		title = "A warning",
		author = "Sign",
		lines = {
			"THE GLARE. Grey ice is thin ice: never stop on it. Seals slide faster than you run: step aside. - Brann",
		},
	},
	savings_note = {
		title = "A note in a crack",
		author = "Note",
		lines = {
			"Froze my savings in a block, like grandma did. A thief can push a block around all day: only a fire gets the chest out. - Fenn",
		},
	},
	spring_note = {
		title = "A note by the steam",
		author = "Note",
		lines = { "Followed the steam to a crack in the ice. Behind it: the warmest bath of my life. - M." },
	},
	whiteout_note = {
		title = "A note, frozen stiff",
		author = "Note",
		lines = {
			"I thought I could run it. Two broths, my thickest coat. Halfway, the cold was in my bones. Three quarters, it was in my thoughts.",
			"The gate at the end doesn't even open. A flame is carved in it. Go back, whoever you are, and find the fire.",
		},
	},
	caves_note = {
		title = "Scratched in the ice",
		author = "Scratches",
		lines = { "IF THE BLOCKS GET STUCK, WALK OUT AND COME BACK IN. THE CAVE PUTS THEM BACK. - Tamsin (not lost)" },
	},
	kids_note = {
		title = "Scribbled on the wall",
		author = "Scribbles",
		lines = {
			"SECRET FORT. KIDS ONLY. Grown-ups who follow our footprints are SPIES. (Spies get the old prizes, we don't want them.)",
		},
	},
	-- The frontier: tablets of the Watch
	frontier = {
		title = "The frontier",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"HERE STANDS THE WATCH OF THE BRONZE, BETWEEN THE CITY AND THE DRY WORLD THE SEA LEFT BEHIND.",
			"NONE GO DOWN WITHOUT THE WORD OF THE HIGH TIDE.",
		},
	},
	the_sleep = {
		title = "The order of the sleep",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"OUR SERVANTS OF BRONZE DO NOT SLEEP, BUT THEY ARE FEW. BY ORDER OF THE HIGH TIDE, THE WATCH SHALL SLEEP IN THE ICE, WITH THE FROZEN STORES, AND KEEP ITS WATCH IN THE DREAM, WHERE NO SOLDIER TIRES. AND SLEEPERS DO NOT DRINK.",
			"THE HEALERS OF THE HOUSE BREW THE DRAUGHT. THE CLAY DIGS THE BEDS OF ICE. THE CITY SEALS ITSELF. THE WATCH REMAINS.",
		},
	},
	the_veils = {
		title = "The veils",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE VEILS ARE WOVEN OF OUR DREAMS. THE WAKING SHALL NOT PASS. THE DREAMING WATCH SHALL PASS.",
			"GAZE INTO THE MIRROR, SOLDIER, AND GO TO YOUR POST.",
		},
	},
	the_plates = {
		title = "The inner gate",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE INNER GATE OPENS WHEN THE ICE STANDS ON EVERY RUNE. PUSH, AND THE ICE SLIDES UNTIL IT MEETS STONE.",
		},
	},
	captain = {
		title = "The captain of the Watch",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE CAPTAIN DOES NOT SLEEP, LIKE THE SUN WARDEN OF THE DRY HALLS. HE KEEPS THE FIRE OF THE WATCH, THE LAST WARMTH OF THE FRONTIER.",
			"TO THE WAKING HE IS ICE. ONLY THE DREAMING MAY RELIEVE HIM OF HIS WATCH.",
		},
	},
	cold_lock = {
		title = "The Cold Lock",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE COLD LOCK. BEYOND IT, THE CITY OF THE TIDE.",
			"WHO CARRIES THE FIRE OF THE WATCH WALKS THROUGH THE WHITE DEATH. THE TIDE WAITS BELOW.",
		},
	},
	-- The frontier: dream runes, only seen by dreamers (the names of Corporal Vey's squad, and other dreams)
	watch_name_orren = {
		title = "A name in the dream",
		author = "Dream rune",
		lines = { "ORREN, OF THE FOURTH SQUAD. STOOD GUARD AT THE STAIR. COLD FEET, WARM HEART." },
	},
	watch_name_maelis = {
		title = "A name in the dream",
		author = "Dream rune",
		lines = { "MAELIS, OF THE FOURTH SQUAD. KEPT THE LAKE. SHE COULD SKATE BACKWARDS." },
	},
	watch_name_tobin = {
		title = "A name in the dream",
		author = "Dream rune",
		lines = { "TOBIN, OF THE FOURTH SQUAD. KEPT THE CAVES, AND THE BLOCKS. NEVER LOST A PUZZLE." },
	},
	watch_name_astra = {
		title = "A name in the dream",
		author = "Dream rune",
		lines = { "ASTRA, OF THE FOURTH SQUAD. KEPT THE WALLS OF THE WATCH. SHE SANG ON GUARD." },
	},
	dream_tower = {
		title = "A dream of the lake",
		author = "Dream rune",
		lines = { "UNDER THE DARK WATER OF THE LAKE, A TOWER OF THE WATCH. WHO CARRIES THE FIRE MAY SAIL THERE." },
	},
	dream_armory = {
		title = "A dream of the armory",
		author = "Dream rune",
		lines = { "THE ARMORY OF THE WATCH IS ACROSS THE CHASM. THE BRIDGE IS ONLY THERE FOR THOSE WHO DREAM OF IT." },
	},
	dream_cache = {
		title = "A dream left behind",
		author = "Dream rune",
		lines = { "M. WAS HERE. SHE DREAMED THE WAY THROUGH THE MIST, AND LEFT SOMETHING FOR THE NEXT DREAMER." },
	},

	-- The city of the Tide: the Seawall
	seagate = {
		title = "The Seagate",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE SEAGATE OF THE CITY OF THE TIDE. NONE ENTER WITHOUT THE WORD OF THE HIGH TIDE.",
			"WHEN THE WATCH WENT UP TO THE COLD, THE GATE WAS SHUT BEHIND IT. THE CITY KEEPS ITS WATER.",
		},
	},
	the_city = {
		title = "The city of the Tide",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"BEHOLD THE CITY OF THE TIDE, BUILT AROUND THE DEEP TIDE, WHERE THE WATER STILL SINGS.",
			"TWICE A DAY THE TIDE RISES, THE ENGINE TURNS, AND THE CITY LIVES.",
		},
	},
	-- The city: the Diggings (the warren of the Clay)
	clay_scratches = {
		title = "Scratched in the clay",
		author = "Scratches",
		lines = {
			"THE CLAY DUG THE CITY. THE CLAY HIDES IN THE HOLES IT DUG. THE CLAY REMEMBERS. *click*",
			"COUNT OF THE LIVING: 31. COUNT OF THE FIGS: NOT ENOUGH. COUNT OF THE YEARS: NOBODY KNOWS ANY MORE.",
		},
	},
	the_burning = {
		title = "The decree of the burning",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"BY ORDER OF THE HIGH TIDE: THE CLAY HAS RISEN, AND DRUNK FROM THE BASIN OF THE HIGH TIDE.",
			"LET THEIR ARCHIVE BURN. LET THEIR NAMES BE STRUCK. THE CLAY IS EBB.",
		},
	},
	rockfall_sign = {
		title = "A sign of the Clay",
		author = "Sign",
		lines = { "ROCKS FELL. THE TUNNEL TO THE HARBOR IS CLOSED. NOBODY DIGS IT OPEN WITHOUT MORTAR'S WORD. - Grit" },
	},
	-- The city: the Aqueduct
	aqueduct = {
		title = "The aqueduct",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE AQUEDUCT CARRIES THE TIDE TO THE GARDENS OF THE HIGH TIDE.",
			"THE CLAY MAY DRINK FROM THE GUTTERS, ON FEAST DAYS.",
		},
	},
	tide_marks = {
		title = "The marks of the tide",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"MARKS OF THE TIDE, CUT IN THE STONE BY THE ENGINEERS.",
			"YEAR 1 OF THE LOW: A HAND BELOW THE MARK. YEAR 40: AN ARM. YEAR 90: THE HEIGHT OF A CHILD.",
			"YEAR 120: THE CHANNELS RUN DRY AT EBB. THE HIGH TIDE ORDERS THE PUMPS OF THE DRY HALLS DOUBLED.",
		},
	},
	tide_marks_last = {
		title = "The last mark",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"YEAR 200: THE LAST MARK. THE ENGINE NO LONGER WAITS FOR THE TIDE TO TURN IT. IT DRINKS THE TIDE.",
			"THE ENGINEERS ARE TOLD TO CUT NO MORE MARKS.",
		},
	},

	-- The city: the Hanging Gardens
	gardens = {
		title = "The gardens of the High Tide",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE GARDENS OF THE HIGH TIDE. HERE GROWS THE FIG, GIFT OF THE TUNNELERS, WATERED BY THE AQUEDUCT.",
			"THE CLAY TENDS THE TREES. THE CLAY DOES NOT EAT THE FIGS.",
		},
	},
	unebbing = {
		title = "The Unebbing",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE HIGH TIDE SHALL NOT EBB. THE BRONZE SHALL CAST US BODIES THAT DO NOT THIRST, DO NOT SICKEN, DO NOT SLEEP.",
			"THE CHIEF MENDER SHALL POUR US INTO THEM. WE SHALL BE THE TIDE THAT NEVER FALLS.",
			"SO IT IS ORDERED, ON THE LAST DAY OF THE LAST LOW. - THE TIDEMOTHER",
		},
	},
	palace_gate = {
		title = "The gate of the palace",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE GATE OF THE HIGH TIDE RISES ON THE WATER OF THE TIDE.",
			"THE GREAT PUMP OF THE BRONZE SENDS THE WATER UP. WHEN THE BASIN IS FULL, THE HIGH TIDE IS AT HOME.",
		},
	},

	-- The city: the Engine of the Tide
	engine = {
		title = "The Engine of the Tide",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE ENGINE OF THE TIDE. TWICE A DAY THE DEEP TIDE RISES AND TURNS THE GREAT WHEEL.",
			"THE WHEEL MAKES THE LIGHTNING: THE LAMPS, THE CORES THAT FOLD THE ROADS, THE SERVANTS OF BRONZE.",
		},
	},
	engine_last = {
		title = "The wheel",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"BY ORDER OF THE TIDEMOTHER, THE WHEEL NO LONGER WAITS FOR THE TIDE. THE PUMPS FEED IT THE TIDE ITSELF.",
			"THE TIDE NO LONGER TURNS THE WHEEL. THE WHEEL DRINKS THE TIDE.",
		},
	},
	engineers_note = {
		title = "Scratched by a workbench",
		author = "Ancient scratches",
		ancient = true,
		lines = {
			"THE BRONZE OF THE HIGH TIDE IS HUNGRY. EVERY DAY THE PUMPS DRINK MORE OF THE DEEP TIDE TO FEED IT.",
			"WHEN IT IS GONE, IT IS GONE. WE TOLD HER. SHE WENT DOWN TO THE HEART AND WIRED HERSELF TO THE WHEEL. - THE LAST ENGINEER",
		},
	},
	sluice = {
		title = "The sluice",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE SLUICE OF THE HEART OPENS WHEN ITS WHEEL TURNS AGAINST THE SUN.",
			"COGS THAT TOUCH TURN AGAINST EACH OTHER. COGS ON ONE SHAFT TURN AS ONE.",
		},
	},
	second_motor = {
		title = "The second motor",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE SECOND MOTOR OF THE SLUICE IS FOR THE FLOODS ONLY. IT FIGHTS THE FIRST: NEVER RUN THEM TOGETHER.",
			"ITS BREAKER IS IN THE DEEP GALLERY, UNDER THE HALL OF THE WHEEL. THE ENGINEERS CRAWL THERE BY THE DUCTS.",
		},
	},

	heart = {
		title = "The heart",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"HERE THE TIDEMOTHER HOLDS THE TIDE.",
			"LET NO ONE UNPLUG HER. LET NO ONE UNPLUG HER. LET NO ONE UNPLUG HER.",
		},
	},

	-- The Tide Road: the marks of the Salt, on their way up
	salt_mark_city = {
		title = "A mark of the Salt",
		author = "Ancient scratches",
		ancient = true,
		lines = {
			"THE SALT PASSED HERE, ON THE LAST HIGH TIDE. THE PULL TOOK THE SHIPS, AND US WITH THEM. HOLD ON TO THE ROPES.",
		},
	},
	salt_mark_frost = {
		title = "A mark of the Salt",
		author = "Ancient scratches",
		ancient = true,
		lines = { "THE COLD OF THE WATCH. WE SAW THEIR FIRES THROUGH THE ROCK, BELOW US NOW. NONE OF THEM LOOKED UP." },
	},
	salt_mark_marsh = {
		title = "A mark of the Salt",
		author = "Ancient scratches",
		ancient = true,
		lines = {
			"THE MARSHES OF THE EBB. WE THREW DOWN BREAD AND ROPE AS WE ROSE. WE DO NOT KNOW IF ANYONE CAUGHT THEM.",
		},
	},
	salt_mark_sand = {
		title = "A mark of the Salt",
		author = "Ancient scratches",
		ancient = true,
		lines = { "THE DRY HALLS. THE ANTS SANG IN THE DARK BELOW US. WE SANG BACK. MAYBE THEY HEARD." },
	},
	salt_mark_light = {
		title = "The last mark of the Salt",
		author = "Ancient scratches",
		ancient = true,
		lines = {
			"WE SEE LIGHT. THE SEA IS FAR, BUT IT IS THERE.",
			"WE WILL FORGET THE TIDE, AND THE CITY, AND OUR NAMES. LET OUR CHILDREN FIND THE TIDE AGAIN.",
		},
	},

	-- The city: the Foundry
	foundry = {
		title = "The foundry",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"HERE THE BRONZE CASTS THE SERVANTS OF THE TIDE: DRUDGES, HOUNDS, FROGS, BATS, LENSES.",
			"FOR EVERY TEN OF THE CLAY WHO FALL, ONE SERVANT. SERVANTS DO NOT DRINK.",
		},
	},
	foundry_order = {
		title = "The last order of the foundry",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"LAST ORDER: CAST BODIES FOR THE HIGH TIDE. ONE HUNDRED AND TWELVE. MAKE THEM BEAUTIFUL.",
			"IF THE BRONZE RUNS SHORT, RECALL THE ARMS OF THE OLDER SERVANTS. THEY WILL NOT NEED THEM.",
		},
	},
	foundry_vault = {
		title = "The vault of the foundry",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE VAULT TURNS AGAINST THE SUN. COGS THAT TOUCH TURN AGAINST EACH OTHER; COGS ON ONE SHAFT TURN AS ONE. THINK, APPRENTICE.",
		},
	},

	-- The city: the Great Archive, the Chronicle of the Tide
	chronicle_sea = {
		title = "The Chronicle of the Tide, I: the green sea",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"WE WERE THE PEOPLE OF THE TIDE. WE SAILED THE GREEN SEA ABOVE. THE MOON PULLED IT, AND WE LEARNED THE PULL.",
			"WHEN THE SEA WITHDREW FROM OUR COASTS, WE FOLLOWED THE WATER DOWN, UNDER THE WORLD, WHERE IT STILL SANG: THE DEEP TIDE.",
			"WE CALLED IT MOTHER. IN OUR TONGUE, TIDE AND MOTHER ARE ONE WORD.",
		},
	},
	chronicle_waters = {
		title = "The Chronicle of the Tide, II: the four waters",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"AROUND THE DEEP TIDE WE BUILT THE CITY, AND THE ENGINE THAT TURNED WITH ITS TIDES. THE ENGINE MADE LIGHTNING, AND THE LIGHTNING MADE LAMPS, SERVANTS OF BRONZE, AND ROADS THAT FOLD.",
			"WE DIVIDED OURSELVES INTO FOUR WATERS, SO THAT EACH WOULD KNOW ITS PLACE: THE HIGH TIDE, THE BRONZE, THE SALT, AND THE CLAY, THE ANTS WHO DIG. WE CALLED IT ORDER.",
		},
	},
	chronicle_low = {
		title = "The Chronicle of the Tide, III: the low",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THEN THE DEEP TIDE BEGAN TO FALL. A HAND, AN ARM, THE HEIGHT OF A CHILD. THE HIGH TIDE WAS AFRAID.",
			"IT TOOK THE WATER OF THE CLAY, SENT ITS SICK DOWN TO THE MARSHES, PUT ITS WATCH TO SLEEP IN THE ICE, AND SEALED THE CITY. WHOEVER FELL WAS STRUCK FROM THE REGISTER.",
			"THE SALT SAID: THE SEA IS NOT DEAD, IT MOVED. LET US FOLLOW IT, AS OUR MOTHERS DID. THE HIGH TIDE SAID NO. ON THE LAST HIGH TIDE THE SALT SAILED UP THE TIDE ROAD, AND THE ROAD WAS SEALED BEHIND THEM.",
		},
	},
	chronicle_unebbing = {
		title = "The Chronicle of the Tide, IV: the Unebbing",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE HIGH TIDE WOULD NOT FALL. IT POURED ITSELF INTO BRONZE, THAT DOES NOT THIRST, OR SICKEN, OR DIE. TO FEED THE BRONZE, THE ENGINE DRANK THE DEEP TIDE.",
			"THE TIDEMOTHER WIRED HERSELF TO THE WHEEL, TO HOLD THE LAST OF THE WATER. THE WATER STOPPED SINGING.",
			"THERE IS NO ONE LEFT TO READ THIS. I AM THE LAST ARCHIVIST, AND I AM BRONZE. I WRITE IT ANYWAY.",
		},
	},

	-- The city: the Palace of the High Tide
	palace = {
		title = "The palace",
		author = "Ancient tablet",
		ancient = true,
		lines = { "THE PALACE OF THE HIGH TIDE. EVERY WATER BOWS BEFORE THE TIDE THAT RULES." },
	},
	the_high_tide = {
		title = "The High Tide",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE HIGH TIDE RULES, AS THE TIDE RULES ALL THAT FLOATS.",
			"WHAT RISES MUST FALL. THE HIGH TIDE SHALL NOT.",
		},
	},
	archive_riddle = {
		title = "The door of the Archive",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE GREAT ARCHIVE OPENS TO THE WORDS OF THE FIRST TABLET, CARVED IN THE OASIS, WHEN WE CAME DOWN FROM THE GREEN SEA:",
			'"WE FOLLOWED THE WATER DOWN, WHERE THE ... ... ..."',
		},
	},
	mirrors = {
		title = "The hall of mirrors",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE STAIR OF THE TIDEMOTHER OPENS TO TWO LIGHTS AT ONCE. ONE LAMP. ONE PRISM.",
			"THE LIGHT THAT SPLITS GOES TWO WAYS. SO DID WE.",
		},
	},
	tidemother_journal = {
		title = "The journal of the Tidemother",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE DAY OF THE LAST LOW. THE ENGINEERS SAY THE TIDE WILL NOT COME BACK. THEN I WILL HOLD IT.",
			"NERISSA SAYS THE SEA MOVED, AND THAT WE SHOULD MOVE WITH IT. THE HIGH TIDE DOES NOT MOVE. THE HIGH TIDE IS.",
		},
	},
	tidemother_journal_last = {
		title = "The last page of the journal",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"NERISSA SAILED WITH THE SALT. I ORDERED HER NAME STRUCK. THE REGISTRAR OBEYED.",
			"TOMORROW THE CHIEF MENDER OF THE HOUSE OF HEALING POURS ME INTO THE BRONZE. I WILL GO DOWN TO THE ENGINE AND HOLD THE TIDE MYSELF. NOTHING WILL EVER EBB AGAIN.",
		},
	},
	tidemother_dream = {
		title = "A dream left in the palace",
		author = "Dream rune",
		lines = {
			"THE LAST NIGHT BEFORE THE BRONZE, I DREAMED THAT YOU CAME BACK, NERISSA. IN THE DREAM, I HAD NOT STRUCK YOUR NAME.",
		},
	},
	throne_plaque = {
		title = "The throne of the Tide",
		author = "Plaque",
		lines = { "THE THRONE OF THE TIDE. SHE IS BELOW. SHE IS ALWAYS BELOW." },
	},

	-- The city: the Ward
	coral_letter = {
		title = "A letter, folded small",
		author = "A letter",
		lines = {
			"Coral, my little wave. If you come back and I am not here, don't be afraid.",
			"The collectors came at the eighth bell. They took our tokens and struck our door. Your father's name, and mine. They wanted yours too.",
			"I told them you had sailed with the Salt. I hid your token where you hide your treasures: in your boat, in the basin by the old bridge. Nobody looks into a toy.",
			"Keep it. A token is a name, and a name is a door. - Mama",
		},
	},
	coral_drawing = {
		title = "A child's drawing",
		author = "A drawing",
		lines = {
			"Wax crayon on the back of a tax notice: a little blue boat with a white sail, floating in a round pond by an arched bridge.",
			"Under the water, a fish with lightning coming out of it. In big crooked letters: MY BOAT. NOBODY TOUCH. - CORAL",
		},
	},
	dex_note = {
		title = "A note in the pipes",
		author = "Note",
		lines = {
			"The bronze eyes can't see through smoke. One vial broken at my feet, and I walked right past the lens of the gate. Saved my hide twice.",
			"Left two for whoever crawls out of that drain next. You're welcome. - Dex, who never paid a toll in his life",
		},
	},
	clockmaker_note = {
		title = "A note in the works",
		author = "Note",
		lines = {
			"The High Tide wants every clock of the city to strike the hours of the tide. There is no tide any more.",
			"I stopped mine at the hour the collectors came for the house by the bridge. Let it lie about every other hour, but not that one.",
			"Whoever sets it to the right hour will find what I kept from them. - Hob, clockmaker",
		},
	},
	guard_orders = {
		title = "Orders",
		author = "Orders",
		lines = {
			"ORDERS OF THE HIGH TIDE TO THE GUARD OF THE WARD. NO CITIZEN WITHOUT A TOKEN. THE TOKENS OF THE EBB ARE TO BE COLLECTED, THEIR DOORS STRUCK.",
			"THE LIFT OF THE SEAGATE STAYS UP. NOBODY LEAVES THE CITY. NOBODY COMES IN.",
		},
	},
	struck_register = {
		title = "The register of the Ebb",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE REGISTER OF THE EBB: THE NAMES STRUCK BY ORDER OF THE HIGH TIDE.",
			"TESSA, OF THE SALT: SAILED. DORAN, OF THE BRONZE: SICK. CORAL, OF THE BRONZE, AGED SIX: STRUCK. HER TOKEN WAS NEVER COLLECTED.",
			"AT THE BOTTOM, IN ANOTHER HAND: NERISSA, OF THE HIGH TIDE: SAILED. STRUCK BY HER MOTHER.",
		},
	},

	nerissa_carving = {
		title = "A name carved in the wall",
		author = "A carving",
		lines = {
			"Low on the wall, at the height of a child, carved with something sharp: NERISSA HID HERE. MOTHER NEVER LOOKS IN SHEDS.",
			"Under it, in a steadier hand, years later: STILL TRUE.",
		},
	},

	-- The city: the Dry Harbor
	harbor_log = {
		title = "The log of the harbor master",
		author = "A log",
		lines = {
			"Last high tide. The Salt are loading everything that floats onto the carts for the Tide Road. The High Tide has forbidden it. They are doing it anyway.",
			"The daughter of the Tidemother came down to the quay at dawn, with a little bag. Nerissa. She asked me which ship was the fastest. I told her ships don't climb.",
			"She laughed and said this one would. The gate of the Tide Road shut behind them at the eighth bell. I am writing this, and nobody will read it.",
		},
	},
	captain_log = {
		title = "A captain's log",
		author = "A log",
		lines = {
			"The Tidebreaker, stranded. The water went out from under her in a single night, and she lay down on her side like a tired dog.",
			"The crew is going up the Tide Road with the others. I'm staying with my ship. A captain doesn't leave his ship. Even when the sea does.",
		},
	},
	lighthouse = {
		title = "The lighthouse",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE VAULT OF THE SALT OPENS TO THE LIGHT OF THE LIGHTHOUSE.",
			"A CAPTAIN WHO CAN STEER LIGHT CAN STEER A SHIP.",
		},
	},
	salt_vault = {
		title = "The vault of the Salt",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"WHAT THE SALT LEAVES BEHIND, IT LEAVES FOR WHOEVER FOLLOWS.",
			"OUR HOOK, TO CROSS WHAT THE HIGH TIDE CUT. THE RINGS OF THE TERRACES STILL HOLD.",
		},
	},
	last_water = {
		title = "The last water",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE DEEP TIDE FILLED THIS BASIN TO THE QUAYS, TWICE A DAY, AND IT SANG.",
			"THE LAST LOW. THE SHIPS LIE IN THE MUD. TONIGHT THE SALT TAKES THE ROAD.",
		},
	},
	tide_road = {
		title = "The Tide Road",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE TIDE ROAD: THE SHAFT WHERE THE PULL OF THE TIDE STILL RISES, UP TO WHERE THE SEA WENT.",
			"SEALED BY ORDER OF THE HIGH TIDE. NO WATER LEAVES THE CITY. NO CHILD OF THE TIDE LEAVES THE CITY.",
		},
	},
	nerissa_letter = {
		title = "Scratched by the gate",
		author = "Ancient scratches",
		ancient = true,
		lines = {
			"MOTHER. IF YOU EVER COME DOWN TO THE HARBOR: THE SEA IS NOT GONE. IT MOVED. WE ARE GOING TO FIND IT.",
			"THE PULL WILL TAKE US UP TONIGHT. COME WITH US. YOU STILL CAN. - N.",
		},
	},

	-- The city: the Hall of Waters
	registry_lamp = {
		title = "The lamp of the registry",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE REGISTRAR WAKES WHEN ITS LAMP IS LIT. THE LIGHT OF THE BRONZE WING FEEDS IT.",
			"CLERK: TURN THE MIRRORS. KEEP THE WAY CLEAR. DO NOT STAND IN THE LIGHT.",
		},
	},
	the_register = {
		title = "The register",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"HERE IS WRITTEN THE WATER OF EVERY CHILD OF THE TIDE: HIGH TIDE, BRONZE, SALT, CLAY.",
			"WHO IS NOT WRITTEN IS EBB. WHO IS STRUCK IS EBB. THE EBB HAVE NO DOOR.",
		},
	},
	ebb_door = {
		title = "The fifth door",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE DOOR OF THE EBB IS CLOSED BY ORDER OF THE HIGH TIDE. ITS LIGHT IS PUT OUT.",
			"THE LAMP BELOW STILL BURNS. IT ONLY NEEDS A MIRROR, AND SOMEONE TO HOLD IT.",
		},
	},
	register_ebb = {
		title = "The register of the Ebb",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"TESSA OF THE SALT, FEVER: STRUCK. DORAN OF THE BRONZE, LAME: STRUCK. THE CLAY OF THE NORTH GALLERY, ALL: STRUCK.",
			"THE WATCH OF THE FROZEN STAIR, AWAKE: STRUCK. THE SALT, ALL WHO SAILED: STRUCK. NERISSA OF THE HIGH TIDE, SAILED: STRUCK.",
			"FROM THIS DAY THE REGISTRAR STRIKES NO MORE NAMES. THERE IS NO ONE LEFT TO ORDER IT.",
		},
	},
	ward_lenses = {
		title = "The lenses of the ward",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE LENSES WATCH FOR THE EBB. A CITIZEN WITH A WATER HAS NOTHING TO FEAR.",
			"WHOEVER HAS NO WATER IS EBB. WHEN A LENS CRIES, THE GATES CLOSE AND THE HOUNDS RUN.",
		},
	},
	stair_warning = {
		title = "The stair of the gate",
		author = "Ancient tablet",
		ancient = true,
		lines = {
			"THE STAIR OF THE GATE IS GUARDED BY LIGHTNING. WALK BETWEEN THE SPARKS.",
			"THE BREAKER BELOW CUTS THE CURRENT, FOR THOSE WHO BELONG.",
		},
	},
} :: { [string]: Lore }

return module
