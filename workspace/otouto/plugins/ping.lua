 -- Actually the simplest plugin ever!

local hailhydra = {}

local utilities = require('utilities')
local bindings = require('bindings')

function hailhydra:init()
	hailhydra.triggers = utilities.triggers(self.info.username):t('hailhydra').table
end

function hailhydra:action(msg)
	local output = ":dragon::dragon: \n HAIL HYDRA \n AVE AVE AVE \n LOVE THE HYDRA \n LODE A TE HYDRA \n L'HYDRA È POTENTE \n L'HYDRA È OVUNQUE \n L'HYDRA È IMMORTALE"
	bindings.sendMessage(self, msg.chat.id, output)
end

return hailhydra
