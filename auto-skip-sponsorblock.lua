-- ~/.config/mpv/scripts/auto-skip-sponsorblock.lua
-- download your file with yt-dlp --sponsorblock-mark all [youtube url]

-- Define the SponsorBlock categories that should be automatically skipped.
local categories_to_skip = {
    ["Sponsor"] = true,
    ["Self-promotion"] = true,
    ["Interaction Reminder"] = true,
    ["Highlight"] = true,
    ["Filler Dialogue"] = true,
    ["Music Off-Topic"] = true,
    ["Preview"] = true,
}

-- Function to check the current chapter and skip if it's a designated SponsorBlock segment.
function check_and_skip_chapter()
    mp.msg.verbose("Running check_and_skip_chapter()")

    local chapter_list = mp.get_property_native("chapter-list")
    if not chapter_list or #chapter_list == 0 then
        mp.msg.verbose("No chapters found.")
        return
    end

    local current_chapter_index = mp.get_property_number("chapter")
    if current_chapter_index == nil or current_chapter_index < 0 then
        mp.msg.verbose("Not currently in a valid chapter.")
        return
    end

    -- Lua tables are 1-indexed, so we access the list with +1.
    local lua_index = current_chapter_index + 1
    local current_chapter_data = chapter_list[lua_index]

    if not current_chapter_data then
        mp.msg.verbose("Could not retrieve data for current chapter.")
        return
    end

    local chapter_title = current_chapter_data.title or ""

    -- Check if the chapter title indicates a SponsorBlock segment.
    if string.find(chapter_title, "^%[SponsorBlock%]: ") then
        local category_name = string.gsub(chapter_title, "^%[SponsorBlock%]: ", "")

        -- Check if this specific SponsorBlock category is marked for skipping.
        if categories_to_skip[category_name] then
            -- The end time is the start time of the *next* chapter.
            local next_chapter_data = chapter_list[lua_index + 1]

            if next_chapter_data then
                local chapter_end_time = next_chapter_data.time
                mp.msg.info("SponsorBlock: Skipping '" .. category_name .. "' segment.")
                mp.set_property_number("time-pos", chapter_end_time)
                mp.msg.info("SponsorBlock: Skipped to " .. chapter_end_time .. " seconds.")
            else
                -- This was the last chapter, so there is nowhere to skip to.
                mp.msg.verbose("SponsorBlock: Cannot skip last chapter.")
            end
        else
            mp.msg.verbose("SponsorBlock: Not skipping category '" .. category_name .. "' (not in skip list).")
        end
    end
end

-- Register events and properties for the script to react to.
mp.observe_property("chapter", "native", check_and_skip_chapter)
mp.register_event("start-file", check_and_skip_chapter)
mp.register_event("seek", check_and_skip_chapter)

mp.msg.info("auto-skip-sponsorblock.lua loaded successfully.")
