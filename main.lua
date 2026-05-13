
---@alias MusicBoxID string -- Essentialy tostring(block_state:getPos())

---@type table<MusicBoxID, MusicBox>
local music_boxes = {}

---@param block BlockState
---@return MusicBox
local function get_or_add_and_get_music_box(block)
    if music_boxes[tostring(block:getPos())] then
        return music_boxes[tostring(block:getPos())]
    end

    print("new music box "..tostring(block:getPos()))

    ---@class MusicBox
    local new_music_box = {
        is_open = false,
        pos = block:getPos(),
        is_on_wall = block:getID() == "minecraft:player_wall_head"
    }

    music_boxes[tostring(block:getPos())] = new_music_box
    return new_music_box
end


local function reset_music_box_render()
    models.MusicBox.SKULL.MusicBox.Playing:setVisible(false)
    models.MusicBox.SKULL.MusicBox.Closed:setVisible(true)
    models.MusicBox.SKULL.MusicBox:setPos(0, 0, 0)
end

---@type Event.SkullRender.func
local function music_box_render(_, block, item, entity, context)
    reset_music_box_render()

    if not block then -- This render call is not for a block.
        models.MusicBox.SKULL.MusicBox:setPos(0, 1, 0)
        return
    end

    local this_box = get_or_add_and_get_music_box(block)

    if this_box.is_open then -- render it as open
        models.MusicBox.SKULL.MusicBox.Playing:setVisible(true)
        models.MusicBox.SKULL.MusicBox.Closed:setVisible(false)
    end

    if this_box.is_on_wall then -- nudge forward to avoid wall.
        models.MusicBox.SKULL.MusicBox:setPos(0, 0, -2.5)
    end


    -- Only placed boxes beyond this point
end

local block_center_offset = vectors.vec3(0.5, 0.5, 0.5)

---@param music_box MusicBox
local function open_box(music_box)
    music_box.is_open = true

    sounds["block.lever.click"]
        :setPos(music_box.pos + block_center_offset)
        :setSubtitle("Music box opens")
        :setPitch(0.6)
        :play()


    -- TODO: if there is no active player, start it at this position
    -- TODO: See if this box is closer and move the SongPlayer here if it's already started.
    -- TODO: update sound player to be positioned at the next nearest box.
end

---@param music_box MusicBox
local function close_box(music_box)
    music_box.is_open = false

    sounds["block.lever.click"]
        :setPos(music_box.pos + block_center_offset)
        :setSubtitle("Music box closes")
        :setPitch(0.5)
        :play()


    -- TODO: if there are no open boxes, then stop the song player.
    -- TODO: update sound player to be positioned at the next nearest box.
end

local block_reach = 8
local function listen_for_player_interactions()

    -- checks all players. If they are targeting the a music box, change that box's state.

    for _, test_player in pairs(world.getPlayers()) do
        if (test_player:getSwingTime() == 1) then -- this player punched this tick
            print("SWING")
            local punchedBlock, _, _ = test_player:getTargetedBlock(true, block_reach)
            local punched_block_pos = punchedBlock:getPos()
            local punched_music_box = music_boxes[tostring(punched_block_pos)]
            if punched_music_box then
                if punched_music_box.is_open then
                    close_box(punched_music_box)
                else
                    open_box(punched_music_box)
                end
            end
        end
    end
end

---@param id MusicBoxID
---@param music_box MusicBox
local function remove_music_box(id, music_box)
    print("removeing music box "..id)
    if music_box.is_open then close_box(music_box) end
    music_boxes[id] = nil
end

local last_checked_id = nil
local function check_next_music_box()
    local current_key, music_box = next(music_boxes, last_checked_id)
    last_checked_id = current_key
    if not current_key then -- Either there are no boxes, or we've hit the end of the list. Loop back to the top.
        return
    end


    local test_block_state = world.getBlockState(music_box.pos)
    if not test_block_state then -- for whatever reason, this position is invalid
        remove_music_box(current_key, music_box)
        return
    end

    if      test_block_state.id ~= "minecraft:player_head"
        and test_block_state.id ~= "minecraft:player_wall_head"
    then -- there's a block here, but it is not a player head.
        remove_music_box(current_key, music_box)
        return
    end

    -- TODO: test distance. If too far, remove the box.
end


local upgrade_request_root = models:newPart("Please Upgrade perms to Max", "SKULL")
    :setPos(0,13,0)
local upgrade_request_billboard = upgrade_request_root:newPart("camera", "Camera")
local upgrade_request_text = upgrade_request_billboard:newText("text")
    :setText(
        "Please set ".. avatar:getEntityName() .."\nto MAX permissions."
        .."\nYou may need to click\n`show disconected avatars`."
    )
    :alignment("CENTER")
    :scale(0.15)
    :setOpacity(0.7)
    :shadow(true)

---@type Event.SkullRender.func
local function fake_init()
    if avatar:getPermissionLevel() ~= "MAX" then return end

    events.SKULL_RENDER:remove(fake_init)

    upgrade_request_root:remove()
    upgrade_request_billboard:remove()
    upgrade_request_text:remove()

    print("--<< box reloaded | " .. world.getTime() .. " >>--")
    animations.MusicBox["animation.model.Playing"]:play()
    models.MusicBox.SKULL.MusicBox.Closed:setVisible(false)
    models.MusicBox.SKULL.MusicBox.Playing:setVisible(true)

    events.SKULL_RENDER:register(music_box_render)
    events.WORLD_TICK:register(check_next_music_box)
    events.WORLD_TICK:register(listen_for_player_interactions)
    --events.WORLD_TICK:register(listen_for_player_interactions)
end
events.SKULL_RENDER:register(fake_init)
