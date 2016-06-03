local time = {}

local HTTPS = require('ssl.https')
local JSON = require('dkjson')
local bindings = require('bindings')
local utilities = require('utilities')

time.command = 'time <location>'
time.doc = [[```
/time <location>
Returns the time, date, and timezone for the given location.
```]]

function time:init()
	time.triggers = utilities.triggers(self.info.username):t('time', true).table
end

function time:action(msg)

	local input = utilities.input(msg.text)
	if not input then
		if msg.reply_to_message and msg.reply_to_message.text then
			input = msg.reply_to_message.text
		else
			bindings.sendMessage(self, msg.chat.id, time.doc, true, msg.message_id, true)
			return
		end
	end

	local coords = utilities.get_coords(self, input)
	if type(coords) == 'string' then
		bindings.sendReply(self, msg, coords)
		return
	end

	local now = os.time()
	local utc = os.time(os.date("!*t", now))

	local url = 'https://maps.googleapis.com/maps/api/timezone/json?location=' .. coords.lat ..','.. coords.lon .. '&timestamp='..utc

	local jstr, res = HTTPS.request(url)
	if res ~= 200 then
		bindings.sendReply(self, msg, self.config.errors.connection)
		return
	end

	local jdat = JSON.decode(jstr)

	local timestamp = now + jdat.rawOffset + jdat.dstOffset
	local utcoff = (jdat.rawOffset + jdat.dstOffset) / 3600
	if utcoff == math.abs(utcoff) then
		utcoff = '+'.. utilities.pretty_float(utcoff)
	else
		utcoff = utilities.pretty_float(utcoff)
	end
	local output = os.date('!%I:%M %p\n', timestamp) .. os.date('!%A, %B %d, %Y\n', timestamp) .. jdat.timeZoneName .. ' (UTC' .. utcoff .. ')'
	output = '```\n' .. output .. '\n```'

	bindings.sendReply(self, msg, output, true)

end

return time
