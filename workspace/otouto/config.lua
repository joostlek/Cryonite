return {

	-- Your authorization token from the botfather.
	bot_api_key = '214254748:AAEuoE25Sf7KEGb7OxynvCm834WOpd8MklM',
	-- Your Telegram ID.
	admin = 38144652,
	-- Two-letter language code.
	lang = 'en',
	-- The channel, group, or user to send error reports to.
	-- If this is not set, errors will be printed to the console.
	log_chat = -1001055856358,
	-- The port used to communicate with tg for administration.lua.
	-- If you change this, make sure you also modify launch-tg.sh.
	cli_port = 4567,
	-- The block of text returned by /start.
	about_text = [[
I am a bot
	]],

	-- http://console.developers.google.com
	google_api_key = '',
	-- https://cse.google.com/cse
	google_cse_key = '',
	-- http://openweathermap.org/appid
	owm_api_key = '',
	-- http://last.fm/api
	lastfm_api_key = '',
	-- http://api.biblia.com
	biblia_api_key = '',
	-- http://thecatapi.com/docs.html
	thecatapi_key = '',
	-- http://api.nasa.gov
	nasa_api_key = '',
	-- http://tech.yandex.com/keys/get
	yandex_key = '',
	-- http://developer.simsimi.com/signUp
	simsimi_key = '',
	simsimi_trial = true,

	errors = { -- Generic error messages used in various plugins.
		connection = 'Connection error.',
		results = 'No results found.',
		argument = 'Invalid argument.',
		syntax = 'Invalid syntax.',
		chatter_connection = 'I don\'t feel like talking right now.',
		chatter_response = 'I don\'t know what to say to that.'
	},

	plugins = { -- To enable a plugin, add its name to the list.
		'control',
		'administration',
		'blacklist',
		'about',
		'ping',
		'whoami',
		'nick',
		'echo',
		'gSearch',
		'gMaps',
		'wikipedia',
		'hackernews',
		'imdb',
		'calc',
		'urbandictionary',
		'time',
		'eightball',
		'dice',
		'reddit',
		'xkcd',
		'slap',
		'commit',
		'pun',
		'currency',
		'cats',
		'shout',
		'patterns',
		'me',
		'luarun',
		-- Put new plugins above this line.
		'help',
		'greetings'
	}

}
