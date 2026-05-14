
---@alias MusicBoxID string -- Essentialy tostring(block_state:getPos())

local music_boxes = {}              ---@type table<MusicBoxID, MusicBox>
local open_music_boxes = {}         ---@type table<MusicBoxID, MusicBox>
local nearest_open_music_box = nil  ---@type MusicBox?


local block_center_offset = vectors.vec3(0.5, 0.5, 0.5)

local auto_close_distance = 32

---@param position Vector3
---@return number
local function get_squared_distance_from_client_to_position(position)
    return (position - client:getCameraPos()):lengthSquared()
end

---@param test_pos Vector3
---@param distance number
---@return boolean
local function client_is_near_pos(test_pos, distance)
    local squared_distance = distance*distance
    return get_squared_distance_from_client_to_position(test_pos) < squared_distance
end

---@param new_position Vector3
---@param old_position Vector3
---@return boolean
local function client_is_closer_to_new_position(new_position, old_position)
    return get_squared_distance_from_client_to_position(new_position) < get_squared_distance_from_client_to_position(old_position)
end

---@param block BlockState
---@return MusicBox
local function get_or_add_and_get_music_box(block)
    if music_boxes[tostring(block:getPos())] then
        return music_boxes[tostring(block:getPos())]
    end

    print("new music box "..tostring(block:getPos()))

    ---@class MusicBox
    local new_music_box = {
        id = tostring(block:getPos()),  ---@type MusicBoxID
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

    if not client_is_near_pos((block:getPos() + block_center_offset), auto_close_distance) then
        -- print("too far from "..tostring(block:getPos()))
        return
    end

    local this_box = get_or_add_and_get_music_box(block)

    if open_music_boxes[this_box.id] then -- render it as open
        models.MusicBox.SKULL.MusicBox.Playing:setVisible(true)
        models.MusicBox.SKULL.MusicBox.Closed:setVisible(false)
    end

    if this_box.is_on_wall then -- nudge forward to avoid wall.
        models.MusicBox.SKULL.MusicBox:setPos(0, 0, -2.5)
    end
end


local song_controller    ---@type SongPlayerController?
local song_config        ---@type SongPlayerConfig?
local song_loop_function ---@type fun(stop_reason:SongPlayerStopReason)?

local function move_music_source(new_pos)
    if song_config then song_config.source_pos = new_pos end
    if song_controller then song_controller.set_new_config(song_config) end
end


---@param music_box MusicBox
local function open_box(music_box)
    open_music_boxes[music_box.id] = music_box
    if (not nearest_open_music_box)
        or client_is_closer_to_new_position(music_box.pos + block_center_offset, nearest_open_music_box.pos + block_center_offset)
    then
        nearest_open_music_box = music_box
        move_music_source(music_box.pos + block_center_offset)
    end

    if song_controller and not song_controller.is_playing() then
        song_controller.play()
        song_controller.register_stop_callback(song_loop_function)
    end

    sounds["block.lever.click"]
        :setPos(music_box.pos + block_center_offset)
        :setSubtitle("Music box opens")
        :setPitch(0.6)
        :play()
end

---@param music_box MusicBox
local function close_box(music_box)
    open_music_boxes[music_box.id] = nil
    if not next(open_music_boxes) then -- there are no open music boxes
        nearest_open_music_box = nil
        if song_controller then
            song_controller.remove_stop_callback(song_loop_function)
            song_controller.stop()
        end
    elseif music_box.id == nearest_open_music_box.id then   -- we need to find the next nearest box.
        local _, any_opened_box = next(open_music_boxes)    -- the world tick loop will eventualy find the real nearest box
        nearest_open_music_box = any_opened_box
        move_music_source(any_opened_box.pos + block_center_offset)
    end

    sounds["block.lever.click"]
        :setPos(music_box.pos + block_center_offset)
        :setSubtitle("Music box closes")
        :setPitch(0.5)
        :play()
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
                if open_music_boxes[punched_music_box.id] then
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
    if open_music_boxes[music_box.id] then close_box(music_box) end
    music_boxes[id] = nil
end


local last_checked_id = nil
local function check_next_music_box()
    local current_music_box_id, current_music_box = next(music_boxes, last_checked_id)
    last_checked_id = current_music_box_id
    if not current_music_box_id then -- Either there are no boxes, or we've hit the end of the list. Loop back to the top.
        return
    end

    local test_block_state = world.getBlockState(current_music_box.pos)
    if not test_block_state then -- for whatever reason, this position is invalid
        remove_music_box(current_music_box_id, current_music_box)
        return
    end

    if      test_block_state.id ~= "minecraft:player_head"
        and test_block_state.id ~= "minecraft:player_wall_head"
    then -- there's a block here, but it is not a player head.
        remove_music_box(current_music_box_id, current_music_box)
        return
    end

    if not client_is_near_pos((current_music_box.pos + block_center_offset), auto_close_distance) then
        remove_music_box(current_music_box_id, current_music_box)
        return
    end

    if open_music_boxes[current_music_box.id] and nearest_open_music_box and nearest_open_music_box.id ~= current_music_box_id then
        if client_is_closer_to_new_position(current_music_box.pos + block_center_offset, nearest_open_music_box.pos + block_center_offset) then
            nearest_open_music_box = current_music_box
            move_music_source(current_music_box.pos + block_center_offset)
        end
    end
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
    if avatar:getPermissionLevel() ~= "MAX" then return end -- Delay/Loop init function until we're at max perms.

    events.SKULL_RENDER:remove(fake_init)   -- make sure we don't double init

    upgrade_request_root:remove()
    upgrade_request_billboard:remove()
    upgrade_request_text:remove()

    print("--<< box reloaded | " .. world.getTime() .. " >>--")


    events.SKULL_RENDER:register(music_box_render)
    events.WORLD_TICK:register(check_next_music_box)
    events.WORLD_TICK:register(listen_for_player_interactions)

    animations.MusicBox["animation.model.Playing"]:pause()  -- The animation is what actualy opens the lid. Setting it to pause holds the first frame.



    -- Set up music player stuff

    local library = require("music_player.libraries"):build_library()
    library:add_local_songs()
    local song_holder = library:get_song_by_id("music_player.local_songs.starbound-atlas")
    if not song_holder then
        print("Failed to get the song from the music player library")
    else
        local data_processor = song_holder:start_or_get_data_processor()

        data_processor:register_callback(function (finished_future)
            if finished_future:has_error() then
                print("failed to process song")
                return
            end

            song_config = song_holder.included_config or {}

            song_config.source_entity = nil

            song_config.primary_update_event_key  = "SKULL_RENDER"
            song_config.fallback_update_event_key = "WORLD_RENDER"  -- Good thing we are already requireing max perms

            -- if not song_config.instrument_selections then song_config.instrument_selections = {} end
            -- for track_index, track in ipairs(song_holder.processed_song.tracks) do
            --     if track.instrument_type_id == 0 then
            --         song_config.instrument_selections[track_index] = {
            --             name = "MC/Bell"
            --         }
            --     end
            -- end

            local song_player_api = require("music_player.song_player")
            song_controller = song_player_api.new_player(song_holder.processed_song, song_config)

            song_loop_function = function(_)
                -- just immediatly call the play function when the song ends.
                -- We'll need to unregister this function to actualy stop the song.
                song_controller.play()
            end

            if nearest_open_music_box then
                move_music_source(nearest_open_music_box.pos + block_center_offset)
                song_controller.play()
                song_controller.register_stop_callback(song_loop_function)
            end

            animations.MusicBox["animation.model.Playing"]:stop()   -- calling stop helps un-stick :pause()
            animations.MusicBox["animation.model.Playing"]:play()

            printTable(song_controller)
        end)
    end

end
events.SKULL_RENDER:register(fake_init)
