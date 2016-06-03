local shout = {}

local bindings = require('bindings')
local utilities = require('utilities')

shout.command = 'shout <text>'
shout.doc = [[```
/shout <text>
Shouts something.
```]]

function shout:init()
	shout.triggers = utilities.triggers(self.info.username):t('shout', true).table
end

function shout:action(msg)

	local input = utilities.input(msg.text)

	if not input then
		bindings.sendMessage(self, msg.chat.id, shout.doc, true, msg.message_id, true)
		return
	end
	input = utilities.trim(input)

	if input:len() > 20 then
		input = input:sub(1,20)
	end

	input = input:upper()
	local output = ''
	local inc = 0
	for match in input:gmatch('([%z\1-\127\194-\244][\128-\191]*)') do
		output = output .. match .. ' '
	end
	output = output .. '\n'
	for match in input:sub(2):gmatch('([%z\1-\127\194-\244][\128-\191]*)') do
		local spacing = ''
		for _ = 1, inc do
			spacing = spacing .. '  '
		end
		inc = inc + 1
		output = output .. match .. ' ' .. spacing .. match .. '\n'
	end
	output = '```\n' .. utilities.trim(output) .. '\n```'
	bindings.sendMessage(self, msg.chat.id, output, true, false, true)

end

return shout
