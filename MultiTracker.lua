--[[
Copyright © 2019, Maverickdfz of Odin
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of MultiTracker nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Sammeh BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.name = 'MultiTracker'
_addon.author = 'Maverick'
_addon.version = '0.0.4.0'
_addon.commands = {'tracker', 'multitracker', 'mt'}

require('tables')
require('logger')

config = require('config')
res = require('resources')
texts = require('texts')

items = {}
key_items = {}

defaults = {}
defaults.output = {}
defaults.output.pos = {}
defaults.output.pos.x = 900
defaults.output.pos.y = 200
defaults.output.text = {}
defaults.output.text.font = 'Arial'
defaults.output.text.size = 8
defaults.output.flags = {}
--defaults.output.flags.right = true
defaults.output.visible = true
defaults.keys = S{}

settings = config.load(defaults)

output = texts.new('${value||%s}', settings.output)

meta = 0
item = 1
key_item = 2
count_items = 3

path = 'res/'

tracker = {}
tracker.keys = S{}
tracker.items = {}

indices = {}

function add_tracker_item(key, with_save)
  local exists = windower.file_exists(windower.addon_path..path..key..'.lua')
  if exists then
    tracker.keys:add(key)
    if(with_save) then
      settings.keys = tracker.keys
      config.save(settings)
    end
    table.insert(tracker.items, require(path..key))
    indices[key] = #tracker.items
  end
end

for value in pairs(settings.keys) do
  add_tracker_item(value, false)
end

function check_item(id)
  for _, data in ipairs(items['inventory']) do
    if type(data) == 'table' then
      if data.id ~= 0 then
        if data.id == id then
          return true, res.items[id].name
        end
      end
    end
  end
  return false, res.items[id].name
end

function check_key_item(id)
  for _, key_item_id in ipairs(key_items) do
    if key_item_id == id then
      return true, res.key_items[id].name
    end
  end
  return false, res.key_items[id].name
end

function check_count_items(id, amount)
  local found = false
  local count = 0
  for _, data in ipairs(items['inventory']) do
    if type(data) == 'table' then
      if data.id ~= 0 then
        if data.id == id then
          found = true
          count = count + data.count
        end
      end
    end
  end
  local got = false
  if found then
    if count >= amount then
      got = true
    end
  end
  return got, res.items[id].name .. " (" .. count .. "/" .. amount .. ")"
end

function update_tracked(rules)
  if not windower.ffxi.get_info().logged_in then
    output.value = 'Not logged in...'
    output:visible(true)
    return
  end

  items = windower.ffxi.get_items()
  key_items = windower.ffxi.get_key_items()

  local value = ''

  if #tracker.items == 0 then
    value = 'Nothing is being tracked...'
  else
    for _, tracker_item in pairs(tracker.items) do
      for _, thing in pairs(tracker_item) do
        if thing.type == meta then
          if value:len() > 0 then
            value = value .. '\n'
          end
          value = value .. thing.value
        else
          got = false
          name = ''
          if thing.type == item then
            got, name = check_item(thing.id)
          elseif thing.type == key_item then
            got, name = check_key_item(thing.id)
          elseif thing.type == count_items then
            got, name = check_count_items(thing.id, thing.amount)
          end
          if value:len() > 0 then
            value = value .. '\n'
          end
          if got then
            value = value .. '  ' .. '\\cs(0,255,0)'..name..'\\cr'
          else
            value = value .. '  ' .. name
          end
        end
      end
    end
  end

  output.value = value
  output:visible(true)
end

windower.register_event('prerender', function()
  update_tracked(rules)
end)

windower.register_event('addon command', function(...)
  local args = T({...})

  if args[1] == nil then
    windower.send_command('reive help')
    return
  end

  local command = args:remove(1):lower()

  if command:lower() == 'help' then
    windower.add_to_chat(8,'MultiTracker: //mt')
    windower.add_to_chat(8,'MultiTracker: //multitracker help')
    windower.add_to_chat(8,'MultiTracker: //multitracker pos x y')
    windower.add_to_chat(8,'MultiTracker: //multitracker track')
    windower.add_to_chat(8,'MultiTracker: //multitracker remove')
  elseif command:lower() == 'pos' then
    output:pos(args[1], args[2])
    settings.output.pos.x = args[1]
    settings.output.pos.y = args[2]
    settings:save('all')
  elseif command:lower() == 'track' or command:lower() == 'add' then
    local key = args[1]
    add_tracker_item(key, true)
  elseif command:lower() == 'remove' then
    local key = args[1]
    if type(indices[key]) ~= nil then
      table.remove(tracker.items, indices[key])
      tracker.keys:remove(key)
      settings.keys = tracker.keys
      config.save(settings)
      indices[key] = nil
    end
  end
end)