
local music_boxes = {}
local music_box_skull_owner_id = {1691807430,517033792,-1227640045,902324743}
  -- ^^ Tanner_Limes uuid

local function get_music_box(blockState)
  if type(blockState) == "string" then
    error("Todo: get_music_box needs to take pos as a string")
  elseif type(blockState) == "Vector" then  -- can accept vector
    blockState = world.getBlockState(blockState)
  end

  -- find block in list of music_boxes
  if type(blockState) ~= "BlockState" then return nil

  elseif music_boxes[tostring(blockState:getPos())] ~= nil then
    return music_boxes[tostring(blockState:getPos())]

  -- looks like we don't have this block recorded. See if this block is a
  -- music box, and if it is, record it.
  elseif (blockState:getID() == "minecraft:player_wall_head"
       or blockState:getID() == "minecraft:player_head"
    )
    and blockState:getEntityData() ~= nil
    and blockState:getEntityData()["SkullOwner"] ~= nil
    and table.concat(blockState:getEntityData()["SkullOwner"]["Id"])
      == table.concat(music_box_skull_owner_id)
  then
    music_boxes[tostring(blockState:getPos())] = {
      is_open = true,
      pos = blockState:getPos(),
      is_on_wall = blockState:getID() == "minecraft:player_wall_head"
    }
    print("here")
    return music_boxes[tostring(blockState:getPos())]
  end

  return nil
end

local function music_box_render(delta,blockState)
  -- Non placed boxes (ie, in an inventory or on a head), should be
  -- rendered as closed
  if not blockState then
    models.MusicBox.SKULL.MusicBox.Playing:setVisible(false)
    models.MusicBox.SKULL.MusicBox.Closed:setVisible(true)
    models.MusicBox.SKULL.MusicBox:setPos(0,1,0)
    return
  end

  -- check if box is in table

  local this_box = get_music_box(blockState)
  if not this_box then
    clean_music_box_table()
  end
  --printTable(this_box)

  models.MusicBox.SKULL.MusicBox.Playing:setVisible(this_box.is_open)
  models.MusicBox.SKULL.MusicBox.Closed:setVisible(not this_box.is_open)
  if this_box.is_on_wall then
    models.MusicBox.SKULL.MusicBox:setPos(0,0,-2.5)
  else
    models.MusicBox.SKULL.MusicBox:setPos(0,0,0)
  end


  -- Only placed boxes beyond this point
end

local function listen_for_player_interactions()
  -- checks all players. If they are targeting the head, change head state.
end

local function remove_missing_music_boxes()
  -- scans known music boxes, and checks if they're
  for i,v in pairs(music_boxes) do
    if world.getBlockState(v.pos).id ~= "minecraft:player_head"
      and world.getBlockState(v.pos).id ~= "minecraft:player_wall_head"
    then
      music_boxes[i] = nil
    end
  end
end

events.ENTITY_INIT:register(function()
  print("--<< box reloaded | "..world:getTime().." >>--")
  animations.MusicBox["animation.model.Playing"]:play()
  models.MusicBox.SKULL.MusicBox.Closed:setVisible(false)
  models.MusicBox.SKULL.MusicBox.Playing:setVisible(true)

  events.SKULL_RENDER:register(music_box_render)
  --events.WORLD_TICK:register(listen_for_player_interactions)
end)
