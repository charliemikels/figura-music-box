
---@type table<integer, string>
local samples = {
    [27] = "177954__ubikphonik__eb1"    -- == D#1   -- I have a suspicion that "Eb1" is a lie
}

local _, example_sample_name = next(samples)
local sound_id_prefix = nil ---@type string?
for _, full_sound_id in pairs(sounds:getCustomSounds()) do
    if string.find(full_sound_id, example_sample_name) then
        sound_id_prefix = full_sound_id:gsub(example_sample_name, "");
        break
    end
end

if not sound_id_prefix then -- prefix not found. Bail out early.
    return {}
end

-- local nearest_sample = {
--
-- }

---Converts a midi note ID to a multiplier usable in minecraft (reletive to the instrument's initial tuning)
---@param note_id integer
---@param base_tuneing integer    The midi id for the instrument's base tuning
---@return number multiplier
local function midi_note_to_multiplier(note_id, base_tuneing)
    local semitones_from_base_tuning = note_id - base_tuneing
    return 2^(semitones_from_base_tuning / 12)
end


local music_box_instrument_builder
---@type InstrumentBuilder
music_box_instrument_builder = {
    name = "Music Box",
    is_available = function() return avatar:canUseCustomSounds() end,
    features = {},

    new_instance = function(params)

        local song_player_api = require("../../song_player")  ---@type SongPlayerAPI
        local fallback_instrument_builder = song_player_api.get_instrument_builder("MC/Harp")
        local fallback_instrument_instance = fallback_instrument_builder and fallback_instrument_builder.new_instance({}) or nil

        ---@type Instrument
        local new_instance = {
            play_instruction = function(instruction, position, time_since_due)
                if music_box_instrument_builder.is_available() then
                    local new_sound = sounds[sound_id_prefix .. samples[27]]
                        :setPitch(midi_note_to_multiplier(instruction.note, 27+(12*2)))  -- For this speciffic avatar, drop the octive by 2 (by saying the sample target is two octives up.)
                        :setPos(position)
                        :setSubtitle("Music from "..(player:isLoaded() and player:getName() or avatar:getName()))
                        :setVolume( (instruction.start_velocity/127) * 0.8)  -- TODO: :setVolume(… * instruction.modifiers.(now).volume)
                    new_sound:play()
                else
                    fallback_instrument_instance.play_instruction(instruction, position, time_since_due)
                end
            end,
            update_sounds = function(position)
                -- Notes do not linger, nothing to update
                fallback_instrument_instance.update_sounds(position)
            end,
            stop_one_sound_immediatly = function()
                -- Notes do not linger and so there's nothing to clean
                fallback_instrument_instance.stop_one_sound_immediatly()
            end,
            stop_all_sounds_immediatly = function()
                -- Notes do not linger and so there's nothing to clean
                fallback_instrument_instance.stop_all_sounds_immediatly()
            end,
            is_finished = function()
                -- Notes do not linger and so there's nothing to clean
                return fallback_instrument_instance.is_finished()
            end
        }
        return new_instance
    end
}

return {music_box_instrument_builder}
