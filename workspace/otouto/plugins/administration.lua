--[[
	administration.lua
	Version 1.9
	Part of the otouto project.
	© 2016 topkecleon <drew@otou.to>
	GNU General Public License, version 2

	This plugin provides self-hosted, single-realm group administration.
	It requires tg (http://github.com/vysheng/tg) with supergroup support.
	For more documentation, view the readme or the manual (otou.to/rtfm).

	Remember to load this before blacklist.lua.

	Important notices about updates will be here!

	1.9 - Added flag antihammer. Groups with antihammer enabled will not be
	affected by global bans. However, users who are hammer'd from an anti-
	hammer group will also be banned locally. Added autobanning after (default)
	3 autokicks. Threshold onfigurable with antiflood. Autokick counters reset
	within twenty-four hours. Merged antisquig action into generic. There is no
	automatic migration; simply add the following to database.administration:
		autokick_timer = 0
		groups[*].flags[6] = false
		groups[*].autoban = 3
		groups[*].autokicks = {}


]]--

local JSON = require('dkjson')
local drua = dofile('drua-tg.lua')
local bindings = require('bindings')
local utilities = require('utilities')

local administration = {}

function administration:init()
	-- Build the administration db if nonexistent.
	if not self.database.administration then
		self.database.administration = {
			admins = {},
			groups = {},
			activity = {},
			autokick_timer = os.date('%d')
		}
	end

	self.admin_temp = {
		help = {},
		flood = {}
	}

	drua.PORT = self.config.cli_port or 4567

	administration.init_command(self)

end

administration.flags = {
	[1] = {
		name = 'unlisted',
		desc = 'Removes this group from the group listing.',
		short = 'This group is unlisted.',
		enabled = 'This group is no longer listed in /groups.',
		disabled = 'This group is now listed in /groups.'
	},
	[2] = {
		name = 'antisquig',
		desc = 'Automatically removes users who post Arabic script or RTL characters.',
		short = 'This group does not allow Arabic script or RTL characters.',
		enabled = 'Users will now be removed automatically for posting Arabic script and/or RTL characters.',
		disabled = 'Users will no longer be removed automatically for posting Arabic script and/or RTL characters..',
		kicked = 'You were automatically kicked from GROUPNAME for posting Arabic script and/or RTL characters.'
	},
	[3] = {
		name = 'antisquig++',
		desc = 'Automatically removes users whose names contain Arabic script or RTL characters.',
		short = 'This group does not allow users whose names contain Arabic script or RTL characters.',
		enabled = 'Users whose names contain Arabic script and/or RTL characters will now be removed automatically.',
		disabled = 'Users whose names contain Arabic script and/or RTL characters will no longer be removed automatically.',
		kicked = 'You were automatically kicked from GROUPNAME for having aname which contains Arabic script and/or RTL characters.'
	},
	[4] = {
		name = 'antibot',
		desc = 'Prevents the addition of bots by non-moderators.',
		short = 'This group does not allow users to add bots.',
		enabled = 'Non-moderators will no longer be able to add bots.',
		disabled = 'Non-moderators will now be able to add bots.'
	},
	[5] = {
		name = 'antiflood',
		desc = 'Prevents flooding by rate-limiting messages per user.',
		short = 'This group automatically removes users who flood.',
		enabled = 'Users will now be removed automatically for excessive messages. Use /antiflood to configure limits.',
		disabled = 'Users will no longer be removed automatically for excessive messages.',
		kicked = 'You were automatically kicked from GROUPNAME for flooding.'
	},
	[6] = {
		name = 'antihammer',
		desc = 'Removes the ban on globally-banned users. Note that users hammered in this group will also be banned locally.',
		short = 'This group does not acknowledge global bans.',
		enabled = 'This group will no longer remove users for being globally banned.',
		disabled = 'This group will now remove users for being globally banned.'
	}
}

administration.antiflood = {
	text = 10,
	voice = 10,
	audio = 10,
	contact = 10,
	photo = 20,
	video = 20,
	location = 20,
	document = 20,
	sticker = 30
}

administration.ranks = {
	[0] = 'Banned',
	[1] = 'Users',
	[2] = 'Moderators',
	[3] = 'Governors',
	[4] = 'Administrators',
	[5] = 'Owner'
}

function administration:get_rank(target, chat)

	target = tostring(target)
	chat = tostring(chat)

	if tonumber(target) == self.config.admin or tonumber(target) == self.info.id then
		return 5
	end

	if self.database.administration.admins[target] then
		return 4
	end

	if chat and self.database.administration.groups[chat] then
		if self.database.administration.groups[chat].governor == tonumber(target) then
			return 3
		elseif self.database.administration.groups[chat].mods[target] then
			return 2
		elseif self.database.administration.groups[chat].bans[target] then
			return 0
		end
	end

	-- I wrote a more succint statement, but I want to be able to make sense of
	-- it. Basically, blacklisted users get 0, except when the group has flag 6
	-- enabled.
	if self.database.blacklist[target] then
		if chat and self.database.administration.groups[chat] and self.database.administration.groups[chat].flags[6] then
			return 1
		else
			return 0
		end
	end

	return 1

end

function administration:get_target(msg)

	local target = utilities.user_from_message(self, msg)
	if target.id then
		target.rank = administration.get_rank(self, target.id, msg.chat.id)
	end
	return target

end

function administration:mod_format(id)
	id = tostring(id)
	local user = self.database.users[id] or { first_name = 'Unknown' }
	local name = utilities.build_name(user.first_name, user.last_name)
	name = utilities.markdown_escape(name)
	local output = '• ' .. name .. ' `[' .. id .. ']`\n'
	return output
end

function administration:get_desc(chat_id)

	local group = self.database.administration.groups[tostring(chat_id)]
	local t = {}
	if group.link then
		table.insert(t, '*Welcome to* [' .. group.name .. '](' .. group.link .. ')*!*')
	else
		table.insert(t, '*Welcome to* _' .. group.name .. '_*!*')
	end
	if group.motd then
		table.insert(t, '*Message of the Day:*\n' .. group.motd)
	end
	if #group.rules > 0 then
		local rulelist = '*Rules:*\n'
		for i,v in ipairs(group.rules) do
			rulelist = rulelist .. '*' .. i .. '.* ' .. v .. '\n'
		end
		table.insert(t, utilities.trim(rulelist))
	end
	local flaglist = ''
	for i = 1, #administration.flags do
		if group.flags[i] then
			flaglist = flaglist .. '• ' .. administration.flags[i].short .. '\n'
		end
	end
	if flaglist ~= '' then
		table.insert(t, '*Flags:*\n' .. utilities.trim(flaglist))
	end
	if group.governor then
		local gov = self.database.users[tostring(group.governor)]
		local s = utilities.md_escape(utilities.build_name(gov.first_name, gov.last_name)) .. ' `[' .. gov.id .. ']`'
		table.insert(t, '*Governor:* ' .. s)
	end
	local modstring = ''
	for k,_ in pairs(group.mods) do
		modstring = modstring .. administration.mod_format(self, k)
	end
	if modstring ~= '' then
		table.insert(t, '*Moderators:*\n' .. utilities.trim(modstring))
	end
	table.insert(t, 'Run /ahelp@' .. self.info.username .. ' for a list of commands.')
	return table.concat(t, '\n\n')

end

function administration:update_desc(chat)
	local group = self.database.administration.groups[tostring(chat)]
	local desc = 'Welcome to ' .. group.name .. '!\n'
	if group.motd then desc = desc .. group.motd .. '\n' end
	if group.governor then
		local gov = self.database.users[tostring(group.governor)]
		desc = desc .. '\nGovernor: ' .. utilities.build_name(gov.first_name, gov.last_name) .. ' [' .. gov.id .. ']\n'
	end
	local s = '\n/desc@' .. self.info.username .. ' for more information.'
	desc = desc:sub(1, 250-s:len()) .. s
	drua.channel_set_about(chat, desc)
end

function administration:kick_user(chat, target, reason)
	drua.kick_user(chat, target)
	utilities.handle_exception(self, target..' kicked from '..chat, reason)
end

function administration.init_command(self_)
	administration.commands = {

		{ -- generic, mostly autokicks
			triggers = { '' },

			privilege = 0,
			interior = true,

			action = function(self, msg, group)

				local rank = administration.get_rank(self, msg.from.id, msg.chat.id)

				local user = {
					do_kick = false,
					do_ban = false
				}

				if rank < 2 then

					-- banned
					if rank == 0 then
						user.do_kick = true
						user.reason = 'banned'
						user.output = 'Sorry, you are banned from ' .. msg.chat.title .. '.'
					elseif group.flags[2] and ( -- antisquig
						msg.text:match(utilities.char.arabic)
						or msg.text:match(utilities.char.rtl_override)
						or msg.text:match(utilities.char.rtl_mark)
					) then
						user.do_kick = true
						user.reason = 'antisquig'
						user.output = administration.flags[2].kicked:gsub('GROUPNAME', msg.chat.title)
					elseif group.flags[3] and ( -- antisquig++
						msg.from.name:match(utilities.char.arabic)
						or msg.from.name:match(utilities.char.rtl_override)
						or msg.from.name:match(utilities.char.rtl_mark)
					) then
						user.do_kick = true
						user.reason = 'antisquig++'
						user.output = administration.flags[3].kicked:gsub('GROUPNAME', msg.chat.title)
					end

					-- antiflood
					if group.flags[5] then
						if not group.antiflood then
							group.antiflood = JSON.decode(JSON.encode(administration.antiflood))
						end
						if not self.admin_temp.flood[msg.chat.id_str] then
							self.admin_temp.flood[msg.chat.id_str] = {}
						end
						if not self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] then
							self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] = 0
						end
						if msg.sticker then -- Thanks Brazil for discarding switches.
							self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] = self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] + group.antiflood.sticker
						elseif msg.photo then
							self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] = self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] + group.antiflood.photo
						elseif msg.document then
							self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] = self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] + group.antiflood.document
						elseif msg.audio then
							self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] = self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] + group.antiflood.audio
						elseif msg.contact then
							self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] = self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] + group.antiflood.contact
						elseif msg.video then
							self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] = self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] + group.antiflood.video
						elseif msg.location then
							self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] = self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] + group.antiflood.location
						elseif msg.voice then
							self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] = self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] + group.antiflood.voice
						else
							self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] = self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] + group.antiflood.text
						end
						if self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] > 99 then
							user.do_kick = true
							user.reason = 'antiflood'
							user.output = administration.flags[5].kicked:gsub('GROUPNAME', msg.chat.title)
							if group.modgroup then
								if self.database.users[msg.from.id_str].username then
									if self.database.users[msg.from.id_str].last_name then
										bindings.sendMessage(self, group.modgroup, self.database.users[msg.from.id_str].first_name .." ".. self.database.users[msg.from.id_str].last_name .." (@" ..self.database.users[tostring(msg.from.id_str)].username..") has been removed due to antiflood", true, nil, true)
									else
										bindings.sendMessage(self, group.modgroup, self.database.users[msg.from.id_str].first_name .. " (@" ..self.database.users[tostring(msg.from.id_str)].username..") has been removed due to antiflood", true, nil, true)
									end
								else
									if self.database.users[msg.from.id_str].last_name then
										bindings.sendMessage(self, group.modgroup, self.database.users[msg.from.id_str].first_name .." ".. self.database.users[msg.from.id_str].last_name .." has been removed due to antiflood", true, nil, true)
									else
										bindings.sendMessage(self, group.modgroup, self.database.users[msg.from.id_str].first_name ..  " has been removed by antiflood", true, nil ,true)
									end
								end
							end
							self.admin_temp.flood[msg.chat.id_str][msg.from.id_str] = nil
						end
					end

				end

				local new_user = user

				if msg.new_chat_participant then

					-- We'll make a new table for the new guy, unless he's also
					-- the original guy.
					if msg.new_chat_participant.id ~= msg.from.id then
						new_user = {
							do_kick = false
						}
					end

					-- I hate typing this out.
					local newguy = msg.new_chat_participant

					if administration.get_rank(self, msg.new_chat_participant.id, msg.chat.id) < 2 then

						-- banned
						if administration.get_rank(self, newguy.id, msg.chat.id) == 0 then
							new_user.do_kick = true
							new_user.reason = 'banned'
							new_user.output = 'Sorry, you are banned from ' .. msg.chat.title .. '.'
						elseif group.flags[3] and ( -- antisquig++
							newguy.name:match(utilities.char.arabic)
							or newguy.name:match(utilities.char.rtl_override)
							or newguy.name:match(utilities.char.rtl_mark)
						) then
							new_user.do_kick = true
							new_user.reason = 'antisquig++'
							new_user.output = administration.flags[3].kicked:gsub('GROUPNAME', msg.chat.title)
						elseif group.flags[4] and newguy.username and newguy.username:match('bot') and rank < 2 then
							new_user.do_kick = true
							new_user.reason = 'antibot'
						end

					end

				elseif msg.new_chat_title then
					if rank < 3 then
						drua.rename_chat(msg.chat.id, group.name)
					else
						group.name = msg.new_chat_title
						if group.grouptype == 'supergroup' then
							administration.update_desc(self, msg.chat.id)
						end
					end
				elseif msg.new_chat_photo then
					if group.grouptype == 'group' then
						if rank < 3 then
							drua.set_photo(msg.chat.id, group.photo)
						else
							group.photo = drua.get_photo(msg.chat.id)
						end
					else
						group.photo = drua.get_photo(msg.chat.id)
					end
				elseif msg.delete_chat_photo then
					if group.grouptype == 'group' then
						if rank < 3 then
							drua.set_photo(msg.chat.id, group.photo)
						else
							group.photo = nil
						end
					else
						group.photo = nil
					end
				end

				if new_user ~= user and new_user.do_kick then
					administration.kick_user(self, msg.chat.id, msg.new_chat_participant.id, new_user.reason)
					if new_user.output then
						bindings.sendMessage(self, msg.new_chat_participant.id, new_user.output)
					end
					if msg.chat.type == 'supergroup' then
						bindings.unbanChatMember(self, msg.chat.id, msg.from.id)
					end
				end

				if group.flags[5] and user.do_kick then
					if group.autokicks[msg.from.id_str] then
						group.autokicks[msg.from.id_str] = group.autokicks[msg.from.id_str] + 1
					else
						group.autokicks[msg.from.id_str] = 1
					end
					if group.autokicks[msg.from.id_str] >= group.autoban then
						group.autokicks[msg.from.id_str] = 0
						user.do_ban = true
						user.reason = 'antiflood autoban: ' .. user.reason
						user.output = user.output .. '\nYou have been banned for being autokicked too many times.'
					end
				end

				if user.do_ban then
					administration.kick_user(self, msg.chat.id, msg.from.id, user.reason)
					if user.output then
						bindings.sendMessage(self, msg.from.id, user.output)
					end
					group.bans[msg.from.id_str] = true
				elseif user.do_kick then
					administration.kick_user(self, msg.chat.id, msg.from.id, user.reason)
					if user.output then
						bindings.sendMessage(self, msg.from.id, user.output)
					end
					if msg.chat.type == 'supergroup' then
						bindings.unbanChatMember(self, msg.chat.id, msg.from.id)
					end
				end

				if msg.new_chat_participant and not new_user.do_kick then
					local output = administration.get_desc(self, msg.chat.id)
					bindings.sendMessage(self, msg.new_chat_participant.id, output, true, nil, true)
				end

				-- Last active time for group listing.
				if msg.text:len() > 0 then
					for i,v in pairs(self.database.administration.activity) do
						if v == msg.chat.id_str then
							table.remove(self.database.administration.activity, i)
							table.insert(self.database.administration.activity, 1, msg.chat.id_str)
						end
					end
				end

				return true

			end
		},

		{ -- /groups
			triggers = utilities.triggers(self_.info.username):t('groups').table,

			command = 'groups',
			privilege = 1,
			interior = false,

			action = function(self, msg)
				local output = ''
				for _,v in ipairs(self.database.administration.activity) do
					local group = self.database.administration.groups[v]
					if not group.flags[1] then -- no unlisted groups
						if group.link then
							output = output ..  '• [' .. utilities.md_escape(group.name) .. '](' .. group.link .. ')\n'
						else
							output = output ..  '• ' .. group.name .. '\n'
						end
					end
				end
				if output == '' then
					output = 'There are currently no listed groups.'
				else
					output = '*Groups:*\n' .. output
				end
				bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
			end
		},

		{ -- /ahelp
			triggers = utilities.triggers(self_.info.username):t('ahelp').table,

			command = 'ahelp',
			privilege = 1,
			interior = false,

			action = function(self, msg)
				local rank = administration.get_rank(self, msg.from.id, msg.chat.id)
				local output = '*Commands for ' .. administration.ranks[rank] .. ':*\n'
				for i = 1, rank do
					for _, val in ipairs(self.admin_temp.help[i]) do
						output = output .. '• /' .. val .. '\n'
					end
				end
				if bindings.sendMessage(self, msg.from.id, output, true, nil, true) then
					if msg.from.id ~= msg.chat.id then
						bindings.sendReply(self, msg, 'I have sent you the requested information in a private message.')
					end
				else
					bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
				end
			end
		},

		{ -- /alist
			triggers = utilities.triggers(self_.info.username):t('ops'):t('oplist').table,

			command = 'ops',
			privilege = 1,
			interior = true,

			action = function(self, msg, group)
				local modstring = ''
				for k,_ in pairs(group.mods) do
					modstring = modstring .. administration.mod_format(self, k)
				end
				if modstring ~= '' then
					modstring = '*Moderators for* _' .. msg.chat.title .. '_ *:*\n' .. modstring
				end
				local govstring = ''
				if group.governor then
					local gov = self.database.users[tostring(group.governor)]
					govstring = '*Governor:* ' .. utilities.md_escape(utilities.build_name(gov.first_name, gov.last_name)) .. ' `[' .. gov.id .. ']`'
				end
				local output = utilities.trim(modstring) ..'\n\n' .. utilities.trim(govstring)
				if output == '\n\n' then
					output = 'There are currently no moderators for this group.'
				end
				bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
			end

		},

		{ -- /desc
			triggers = utilities.triggers(self_.info.username):t('desc'):t('description').table,

			command = 'description',
			privilege = 1,
			interior = true,

			action = function(self, msg)
				local output = administration.get_desc(self, msg.chat.id)
				if bindings.sendMessage(self, msg.from.id, output, true, nil, true) then
					if msg.from.id ~= msg.chat.id then
						bindings.sendReply(self, msg, 'I have sent you the requested information in a private message.')
					end
				else
					bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
				end
			end
		},

		{ -- /rules
			triggers = utilities.triggers(self_.info.username):t('rules', true).table,

			command = 'rules',
			privilege = 1,
			interior = true,

			action = function(self, msg, group)
				local output
				local input = utilities.get_word(msg.text_lower, 2)
				input = tonumber(input)
				if #group.rules > 0 then
					if input and group.rules[input] then
						output = '*' .. input .. '.* ' .. group.rules[input]
					else
						output = '*Rules for* _' .. msg.chat.title .. '_ *:*\n'
						for i,v in ipairs(group.rules) do
							output = output .. '*' .. i .. '.* ' .. v .. '\n'
						end
					end
				else
					output = 'No rules have been set for ' .. msg.chat.title .. '.'
				end
				bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
			end
		},

		{ -- /motd
			triggers = utilities.triggers(self_.info.username):t('motd').table,

			command = 'motd',
			privilege = 1,
			interior = true,

			action = function(self, msg, group)
				local output = 'No MOTD has been set for ' .. msg.chat.title .. '.'
				if group.motd then
					output = '*MOTD for* _' .. msg.chat.title .. '_ *:*\n' .. group.motd
				end
				bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
			end
		},
		{ -- /modgroup
			triggers = utilities.triggers(self_.info.username):t('modgroup', true).table,

			command = 'modgroup',
			privilege = 3,
			interior = true,

			action = function(self, msg, group)
				local input = utilities.input(msg.text)
				local output = "Something went wrong, contact @joostlek"
				if group.modgroup then
					output = "Modgroup is ".. group.modgroup
				elseif self.database.administration.groups[input] then 
					self.database.administration.groups[msg.chat.id_str].modgroup = input 
					output = "modgroup is set"
					local modput = "This group is now a modgroup"
					bindings.sendMessage(self, group.modgroup, modput, true, nil, true)
				else
					output = "Please add me in that group first, and make sure you use /gadd"
				end
				bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
			end
		},
		{-- /trust
			triggers = utilities.triggers(self_.info.username):t('trust', true).table,

			command = 'trust',
			privilege = 2,
			interior = true,

			action = function(self, msg, group)
				local output = ""
				local modput = ""
				local target = administration.get_target(self, msg)
				local group = self.database.administration.groups[msg.chat.id_str]
				local user = self.database.users
				if target.id then
					if group.mods[tostring(target.id)] == true then
						output = "Greater then mods are always trusted!"
					else
						if group.trust then
							if group.trust[tostring(target.id)] == 1 then
								group.trust[tostring(target.id)] = nil
								output =  user[tostring(target.id)].first_name .." is now untrusted"
								modput =  user[tostring(target.id)].first_name .." is now untrusted"
							else
								group.trust[tostring(target.id)] = 1
								output =  user[tostring(target.id)].first_name .." is now trusted"
								modput =  user[tostring(target.id)].first_name .." is now trusted"
							end
						else 
							group.trust = {}
							group.trust[tostring(target.id)] = 1
							output =  user[tostring(target.id)].first_name .." is now trusted"
							modput =  user[tostring(target.id)].first_name .." is now trusted"
						end
					end
				else
					output = "*Trusted Users:*\n"
					for k,v in pairs(group.trust) do
						if v == 1 then
							output = output .. user[tostring(k)].first_name .."\n"
						end
					end
				end
				bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
				if group.modgroup then
					bindings.sendMessage(self, group.modgroup, modput, true, nil, true)
				end
			end
		},
		{ -- /report
			triggers = utilities.triggers(self_.info.username):t('report', true).table,

			command = 'report',
			privilege = 1,
			interior = true,

			action = function(self, msg, group)
				local output = ""
				local modput = ""
				local target = administration.get_target(self, msg)
				local group = self.database.administration.groups[msg.chat.id_str]
				local user = self.database.users
				
				if group.modgroup then
					if group.trust then
						if group.trust[msg.from.id_str] or group.mods[msg.from.id_str] or group.gov == msg.from.id then
							if target.id then
								output = user[tostring(target.id)].first_name .. " has been reported"
								modput = "@" .. user[tostring(msg.from.id)].username.." has reported " ..user[tostring(target.id)].first_name
							else
								output = "Please reply to the message or provide an username"
							end
						else
							output = "You are not trusted"
						end
					else
						output = "You are not trusted"
					end
				else
					output = "This group doesn't have a modgroup yet, check /modgroup out first!"
				end
				bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
				if group.modgroup then
					bindings.sendMessage(self, group.modgroup, modput, true, nil, true)
				end
			end
		},
		

		{ -- /link
			triggers = utilities.triggers(self_.info.username):t('link').table,

			command = 'link',
			privilege = 1,
			interior = true,

			action = function(self, msg, group)
				local output = 'No link has been set for ' .. msg.chat.title .. '.'
				if group.link then
					output = '[' .. msg.chat.title .. '](' .. group.link .. ')'
				end
				bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
			end
		},

		{ -- /kickme
			triggers = utilities.triggers(self_.info.username):t('leave'):t('kickme').table,

			command = 'kickme',
			privilege = 1,
			interior = true,

			action = function(self, msg)
				if administration.get_rank(self, msg.from.id) == 5 then
					bindings.sendReply(self, msg, 'I can\'t let you do that, '..msg.from.name..'.')
					return
				end
				administration.kick_user(self, msg.chat.id, msg.from.id, 'kickme')
				if msg.chat.type == 'supergroup' then
					bindings.unbanChatMember(self, msg.chat.id, msg.from.id)
				end
			end
		},

		{ -- /kick
			triggers = utilities.triggers(self_.info.username):t('kick', true).table,

			command = 'kick <user>',
			privilege = 2,
			interior = true,

			action = function(self, msg)
				local target = administration.get_target(self, msg)
				if target.err then
					bindings.sendReply(self, msg, target.err)
					return
				elseif target.rank > 1 then
					bindings.sendReply(self, msg, target.name .. ' is too privileged to be kicked.')
					return
				end
				administration.kick_user(self, msg.chat.id, target.id, 'kicked by ' .. msg.from.id)
				if msg.chat.type == 'supergroup' then
					bindings.unbanChatMember(self, msg.chat.id, target.id)
				end
				bindings.sendMessage(self, msg.chat.id, target.name .. ' has been kicked.')
				local group = self.database.administration.groups[msg.chat.id_str]
				if group.modgroup then
					if self.database.users[tostring(target.id)].username then
					bindings.sendMessage(self, group.modgroup, target.name ..  " (@" .. self.database.users[tostring(target.id)].username.. ") has been kicked by @"..msg.from.username, true, nil ,true)
					else
					bindings.sendMessage(self, group.modgroup, target.name .. " has been kicked by @" ..msg.from.username, true, nil, true)
					end
				end
			end
		},

		{ -- /ban
			triggers = utilities.triggers(self_.info.username):t('ban', true):t('unban', true).table,

			command = 'ban <user> <reason>',
			privilege = 2,
			interior = true,

			action = function(self, msg, group)
				local target = administration.get_target(self, msg)
				if target.err then
					bindings.sendReply(self, msg, target.err)
					return
				end
				if target.rank > 1 then
					bindings.sendReply(self, msg, target.name .. ' is too privileged to be banned.')
					return
				end
				if group.bans[target.id_str] then
					group.bans[target.id_str] = nil
					if msg.chat.type == 'supergroup' then
						bindings.unbanChatMember(self, msg.chat.id, target.id)
					end
					bindings.sendReply(self, msg, target.name .. ' has been unbanned.')
					if group.modgroup then
						if self.database.users[tostring(target.id)].username then
							bindings.sendMessage(self, group.modgroup, target.name.." (@"..self.database.users[tostring(target.id)].username.. ") has been unbanned by @"..self.database.users[tostring(msg.from.id)].username, true, nil,true)
						else
						bindings.sendMessage(self, group.modgroup, target.name ..  " has been unbanned by @"..self.database.users[tostring(msg.from.id)].username, true, nil ,true)
						end
					end
				else
					group.bans[target.id_str] = true
					administration.kick_user(self, msg.chat.id, target.id, ' banned by '..msg.from.id)
					bindings.sendReply(self, msg, target.name .. ' has been banned.')
					
					if group.modgroup then
						if self.database.users[tostring(target
							.id)].username then
						bindings.sendMessage(self, group.modgroup, target.name .. " (@" ..self.database.users[tostring(target.id)].username..") has been banned by @".. self.database.users[tostring(msg.from.id)].username, true, nil, true)
						else
						bindings.sendMessage(self, group.modgroup, target.name ..  " has been banned by @"..self.database.users[tostring(msg.from.id)].username, true, nil ,true)
						end
					end
				end
			end
		},

		{ -- /changerule
			triggers = utilities.triggers(self_.info.username):t('changerule', true).table,

			command = 'changerule <i> <rule>',
			privilege = 3,
			interior = true,

			action = function(self, msg, group)
				local usage = 'usage: `/changerule <i> <newrule>`\n`/changerule <i> -- `deletes.'
				local input = utilities.input(msg.text)
				if not input then
					bindings.sendMessage(self, msg.chat.id, usage, true, msg.message_id, true)
					return
				end
				local rule_num = input:match('^%d+')
				if not rule_num then
					local output = 'Please specify which rule you want to change.\n' .. usage
					bindings.sendMessage(self, msg.chat.id, output, true, msg.message_id, true)
					return
				end
				rule_num = tonumber(rule_num)
				local rule_new = utilities.input(input)
				if not rule_new then
					local output = 'Please specify the new rule.\n' .. usage
					bindings.sendMessage(self, msg.chat.id, output, true, msg.message_id, true)
					return
				end
				if not group.rules then
					local output = 'Sorry, there are no rules to change. Please use /setrules.\n' .. usage
					bindings.sendMessage(self, msg.chat.id, output, true, msg.message_id, true)
					return
				end
				if not group.rules[rule_num] then
					rule_num = #group.rules + 1
				end
				if rule_new == '--' or rule_new == '—' then
					if group.rules[rule_num] then
						table.remove(group.rules, rule_num)
						bindings.sendReply(self, msg, 'That rule has been deleted.')
					else
						bindings.sendReply(self, msg, 'There is no rule with that number.')
					end
					return
				end
				group.rules[rule_num] = rule_new
				local output = '*' .. rule_num .. '*. ' .. rule_new
				bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
			end
		},

		{ -- /setrules
			triggers = utilities.triggers(self_.info.username):t('setrules', true).table,

			command = 'setrules <rules>',
			privilege = 3,
			interior = true,

			action = function(self, msg, group)
				local input = msg.text:match('^/setrules[@'..self.info.username..']*(.+)')
				if not input then
					bindings.sendMessage(self, msg.chat.id, '```\n/setrules [rule]\n<rule>\n[rule]\n...\n```', true, msg.message_id, true)
					return
				elseif input == ' --' or input == ' —' then
					group.rules = {}
					bindings.sendReply(self, msg, 'The rules have been cleared.')
					return
				end
				group.rules = {}
				input = utilities.trim(input) .. '\n'
				local output = '*Rules for* _' .. msg.chat.title .. '_ *:*\n'
				local i = 1
				for l in input:gmatch('(.-)\n') do
					output = output .. '*' .. i .. '.* ' .. l .. '\n'
					i = i + 1
					table.insert(group.rules, utilities.trim(l))
				end
				bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
			end
		},

		{ -- /setmotd
			triggers = utilities.triggers(self_.info.username):t('setmotd', true).table,

			command = 'setmotd <motd>',
			privilege = 3,
			interior = true,

			action = function(self, msg, group)
				local input = utilities.input(msg.text)
				if not input then
					if msg.reply_to_message and msg.reply_to_message.text then
						input = msg.reply_to_message.text
					else
						bindings.sendReply(self, msg, 'Please specify the new message of the day.')
						return
					end
				end
				if input == '--' or input == '—' then
					group.motd = nil
					bindings.sendReply(self, msg, 'The MOTD has been cleared.')
				else
					input = utilities.trim(input)
					group.motd = input
					local output = '*MOTD for* _' .. msg.chat.title .. '_ *:*\n' .. input
					bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
				end
				if group.grouptype == 'supergroup' then
					administration.update_desc(self, msg.chat.id)
				end
			end
		},

		{ -- /setlink
			triggers = utilities.triggers(self_.info.username):t('setlink', true).table,

			command = 'setlink <link>',
			privilege = 3,
			interior = true,

			action = function(self, msg, group)
				local input = utilities.input(msg.text)
				if not input then
					bindings.sendReply(self, msg, 'Please specify the new link.')
					return
				elseif input == '--' or input == '—' then
					group.link = drua.export_link(msg.chat.id)
					bindings.sendReply(self, msg, 'The link has been regenerated.')
					return
				end
				group.link = input
				local output = '[' .. msg.chat.title .. '](' .. input .. ')'
				bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
			end
		},

		{ -- /alist
			triggers = utilities.triggers(self_.info.username):t('alist').table,

			command = 'alist',
			privilege = 3,
			interior = true,

			action = function(self, msg)
				local output = '*Administrators:*\n'
				output = output .. administration.mod_format(self, self.config.admin):gsub('\n', ' ★\n')
				for id,_ in pairs(self.database.administration.admins) do
					output = output .. administration.mod_format(self, id)
				end
				bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
			end
		},

		{ -- /flags
			triggers = utilities.triggers(self_.info.username):t('flags?', true).table,

			command = 'flag <i>',
			privilege = 3,
			interior = true,

			action = function(self, msg, group)
				local input = utilities.input(msg.text)
				if input then
					input = utilities.get_word(input, 1)
					input = tonumber(input)
					if not input or not administration.flags[input] then input = false end
				end
				if not input then
					local output = '*Flags for* _' .. msg.chat.title .. '_ *:*\n'
					for i,v in ipairs(administration.flags) do
						local status = group.flags[i] or false
						output = output .. '`[' .. i .. ']` *' .. v.name .. '*` = ' .. tostring(status) .. '`\n• ' .. v.desc .. '\n'
					end
					bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
					return
				end
				if group.flags[input] == true then
					group.flags[input] = false
					bindings.sendReply(self, msg, administration.flags[input].disabled)
				else
					group.flags[input] = true
					bindings.sendReply(self, msg, administration.flags[input].enabled)
				end
			end
		},

		{ -- /antiflood
			triggers = utilities.triggers(self_.info.username):t('antiflood', true).table,

			command = 'antiflood <type> <i>',
			privilege = 3,
			interior = true,

			action = function(self, msg, group)
				if not group.flags[5] then
					bindings.sendMessage(self, msg.chat.id, 'antiflood is not enabled. Use `/flag 5` to enable it.', true, nil, true)
					return
				end
				if not group.antiflood then
					group.antiflood = JSON.decode(JSON.encode(administration.antiflood))
				end
				local input = utilities.input(msg.text_lower)
				local output
				if input then
					local key, val = input:match('(%a+) (%d+)')
					if not key or not val or not tonumber(val) then
						output = 'Not a valid message type or number.'
					elseif key == 'autoban' then
						group.autoban = tonumber(val)
						output = 'Users will now be autobanned after *' .. val .. '* autokicks.'
					else
						group.antiflood[key] = tonumber(val)
						output = '*' .. key:gsub('^%l', string.upper) .. '* messages are now worth *' .. val .. '* points.'
					end
				else
					output = 'usage: `/antiflood <type> <i>`\nexample: `/antiflood text 5`\nUse this command to configure the point values for each message type. When a user reaches 100 points, he is kicked. The points are reset each minute. The current values are:\n'
					for k,v in pairs(group.antiflood) do
						output = output .. '*'..k..':* `'..v..'`\n'
					end
					output = output .. 'Users will be banned automatically after *' .. group.autoban .. '* autokicks. Configure this with the *autoban* keyword.'
				end
				bindings.sendMessage(self, msg.chat.id, output, true, msg.message_id, true)
			end
		},

		{ -- /mod
			triggers = utilities.triggers(self_.info.username):t('mod', true):t('demod', true).table,

			command = 'mod <user>',
			privilege = 3,
			interior = true,

			action = function(self, msg, group)
				local target = administration.get_target(self, msg)
				if target.err then
					bindings.sendReply(self, msg, target.err)
					return
				end
				if group.mods[target.id_str] then
					if group.grouptype == 'supergroup' then
						drua.channel_set_admin(msg.chat.id, target.id, 0)
					end
					group.mods[target.id_str] = nil
					bindings.sendReply(self, msg, target.name .. ' is no longer a moderator.')
				else
					if target.rank > 2 then
						bindings.sendReply(self, msg, target.name .. ' is greater than a moderator.')
						return
					end
					if group.grouptype == 'supergroup' then
						drua.channel_set_admin(msg.chat.id, target.id, 2)
					end
					group.mods[target.id_str] = true
					bindings.sendReply(self, msg, target.name .. ' is now a moderator.')
				end
			end
		},

		{ -- /gov
			triggers = utilities.triggers(self_.info.username):t('gov', true):t('degov', true).table,

			command = 'gov <user>',
			privilege = 4,
			interior = true,

			action = function(self, msg, group)
				local target = administration.get_target(self, msg)
				if target.err then
					bindings.sendReply(self, msg, target.err)
					return
				end
				if group.governor and group.governor == target.id then
					if group.grouptype == 'supergroup' then
						drua.channel_set_admin(msg.chat.id, target.id, 0)
					end
					group.governor = self.config.admin
					bindings.sendReply(self, msg, target.name .. ' is no longer the governor.')
				else
					if group.grouptype == 'supergroup' then
						if group.governor then
							drua.channel_set_admin(msg.chat.id, group.governor, 0)
						end
						drua.channel_set_admin(msg.chat.id, target.id, 2)
					end
					if target.rank == 2 then
						group.mods[target.id_str] = nil
					end
					group.governor = target.id
					bindings.sendReply(self, msg, target.name .. ' is the new governor.')
				end
				if group.grouptype == 'supergroup' then
					administration.update_desc(self, msg.chat.id)
				end
			end
		},

		{ -- /hammer
			triggers = utilities.triggers(self_.info.username):t('hammer', true):t('unhammer', true).table,

			command = 'hammer <user>',
			privilege = 4,
			interior = false,

			action = function(self, msg, group)
				local target = administration.get_target(self, msg)
				if target.err then
					bindings.sendReply(self, msg, target.err)
					return
				end
				if target.rank > 3 then
					bindings.sendReply(self, msg, target.name .. ' is too privileged to be globally banned.')
					return
				end
				if self.database.blacklist[target.id_str] then
					self.database.blacklist[target.id_str] = nil
					bindings.sendReply(self, msg, target.name .. ' has been globally unbanned.')
				else
					administration.kick_user(self, msg.chat.id, target.id, 'hammered by '..msg.from.id)
					self.database.blacklist[target.id_str] = true
					for k,v in pairs(self.database.administration.groups) do
						if not v.flags[6] then
							drua.kick_user(k, target.id)
						end
					end
					local output = target.name .. ' has been globally banned.'
					if group.flags[6] == true then
						group.bans[target.id_str] = true
						output = target.name .. ' has been globally and locally banned.'
					end
					bindings.sendReply(self, msg, output)
				end
			end
		},

		{ -- /admin
			triggers = utilities.triggers(self_.info.username):t('admin', true):t('deadmin', true).table,

			command = 'admin <user>',
			privilege = 5,
			interior = false,

			action = function(self, msg)
				local target = administration.get_target(self, msg)
				if target.err then
					bindings.sendReply(self, msg, target.err)
					return
				end
				if self.database.administration.admins[target.id_str] then
					self.database.administration.admins[target.id_str] = nil
					bindings.sendReply(self, msg, target.name .. ' is no longer an administrator.')
				else
					if target.rank == 5 then
						bindings.sendReply(self, msg, target.name .. ' is greater than an administrator.')
						return
					end
					for _,group in pairs(self.database.administration.groups) do
						group.mods[target.id_str] = nil
					end
					self.database.administration.admins[target.id_str] = true
					bindings.sendReply(self, msg, target.name .. ' is now an administrator.')
				end
			end
		},

		{ -- /gadd
			triggers = utilities.triggers(self_.info.username):t('gadd').table,

			command = 'gadd',
			privilege = 5,
			interior = false,

			action = function(self, msg)
				if self.database.administration.groups[msg.chat.id_str] then
					bindings.sendReply(self, msg, 'I am already administrating this group.')
					return
				end
				self.database.administration.groups[msg.chat.id_str] = {
					mods = {},
					governor = msg.from.id,
					bans = {},
					flags = {},
					rules = {},
					grouptype = msg.chat.type,
					name = msg.chat.title,
					link = drua.export_link(msg.chat.id),
					photo = drua.get_photo(msg.chat.id),
					founded = os.time(),
					autokicks = {},
					autoban = 3
				}
				administration.update_desc(self, msg.chat.id)
				for i = 1, #administration.flags do
					self.database.administration.groups[msg.chat.id_str].flags[i] = false
				end
				table.insert(self.database.administration.activity, msg.chat.id_str)
				bindings.sendReply(self, msg, 'I am now administrating this group.')
				drua.channel_set_admin(msg.chat.id, self.info.id, 2)
			end
		},

		{ -- /grem
			triggers = utilities.triggers(self_.info.username):t('grem', true):t('gremove', true).table,

			command = 'gremove \\[chat]',
			privilege = 5,
			interior = false,

			action = function(self, msg)
				local input = utilities.input(msg.text) or msg.chat.id_str
				local output
				if self.database.administration.groups[input] then
					local chat_name = self.database.administration.groups[input].name
					self.database.administration.groups[input] = nil
					for i,v in ipairs(self.database.administration.activity) do
						if v == input then
							table.remove(self.database.administration.activity, i)
						end
					end
					output = 'I am no longer administrating _' .. utilities.md_escape(chat_name) .. '_.'
				else
					if input == msg.chat.id_str then
						output = 'I do not administrate this group.'
					else
						output = 'I do not administrate that group.'
					end
				end
				bindings.sendMessage(self, msg.chat.id, output, true, nil, true)
			end
		},

		{ -- /glist
			triggers = utilities.triggers(self_.info.username):t('glist', false).table,

			command = 'glist',
			privilege = 5,
			interior = false,

			action = function(self, msg)
				local output = ''
				if utilities.table_size(self.database.administration.groups) > 0 then
					for k,v in pairs(self.database.administration.groups) do
						output = output .. '[' .. utilities.md_escape(v.name) .. '](' .. v.link .. ') `[' .. k .. ']`\n'
						if v.governor then
							local gov = self.database.users[tostring(v.governor)]
							output = output .. '★ ' .. utilities.md_escape(utilities.build_name(gov.first_name, gov.last_name)) .. ' `[' .. gov.id .. ']`\n'
						end
					end
				else
					output = 'There are no groups.'
				end
				if bindings.sendMessage(self, msg.from.id, output, true, nil, true) then
					if msg.from.id ~= msg.chat.id then
						bindings.sendReply(self, msg, 'I have sent you the requested information in a private message.')
					end
				end
			end
		},

		{ -- /broadcast
			triggers = utilities.triggers(self_.info.username):t('broadcast', true).table,

			command = 'broadcast <message>',
			privilege = 5,
			interior = false,

			action = function(self, msg)
				local input = utilities.input(msg.text)
				if not input then
					bindings.sendReply(self, msg, 'Give me something to broadcast.')
					return
				end
				input = '*Admin Broadcast:*\n' .. input
				for id,_ in pairs(self.database.administration.groups) do
					bindings.sendMessage(self, id, input, true, nil, true)
				end
			end
		}

	}

	-- Generate trigger table.
	administration.triggers = {}
	for _, command in ipairs(administration.commands) do
		for _, trigger in ipairs(command.triggers) do
			table.insert(administration.triggers, trigger)
		end
	end

	self_.database.administration.help = {}
	for i,_ in ipairs(administration.ranks) do
		self_.admin_temp.help[i] = {}
	end
	for _,v in ipairs(administration.commands) do
		if v.command then
			table.insert(self_.admin_temp.help[v.privilege], v.command)
		end
	end
end

function administration:action(msg)
	for _,command in ipairs(administration.commands) do
		for _,trigger in pairs(command.triggers) do
			if msg.text_lower:match(trigger) then
				if command.interior and not self.database.administration.groups[msg.chat.id_str] then
					break
				end
				if administration.get_rank(self, msg.from.id, msg.chat.id) < command.privilege then
					break
				end
				local res = command.action(self, msg, self.database.administration.groups[msg.chat.id_str])
				if res ~= true then
					return res
				end
			end
		end
	end
	return true
end

function administration:cron()
	self.admin_temp.flood = {}
	if os.date('%d') ~= self.database.administration.autokick_timer then
		self.database.administration.autokick_timer = os.date('%d')
		for _,v in pairs(self.database.administration.groups) do
			v.autokicks = {}
		end
	end
end

administration.command = 'groups'
administration.doc = '`Returns a list of administrated groups.\nUse /ahelp for more administrative commands.`'

return administration
