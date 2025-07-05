--[[
    auto-skip-sponsorblock.lua
    Version 9 (Production)

    This script automatically skips sponsored segments in local video files
    that contain a YouTube URL in their metadata. It is designed to be
    lightweight and silent during normal operation.
--]]

-- Load required utilities.
local utils = require 'mp.utils'
local msg = require 'mp.msg'

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

-- Map the yt-dlp category names to the names used by the SponsorBlock API.
local category_map = {
    ["Sponsor"] = "sponsor",
    ["Self-promotion"] = "selfpromo",
    ["Interaction Reminder"] = "interaction",
    ["Highlight"] = "highlight",
    ["Music Off-Topic"] = "music_offtopic",
    ["Preview"] = "preview",
}

-- Global variable to hold segments fetched from the API.
local sponsor_segments = nil

-----------------------------------------------------------------------------
-- Core Parsing and API Functions
-----------------------------------------------------------------------------

-- Finds the first plausible YouTube URL in a block of text.
function extract_url_from_text(text_blob)
    if not text_blob or text_blob == "" then return nil end
    local pattern = "(https?://[%w%./?=&~%-%_]+youtu%.?be[%w%./?=&~%-%_]+)"
    return string.match(text_blob, pattern)
end

-- Extracts a YouTube video ID from a URL using correct Lua Patterns.
function get_youtube_id(url)
    if not url then return nil end
    local patterns_to_try = {
        ["watch%?v=([%w%-]+)"] = true,
        ["youtu%.be/([%w%-]+)"] = true,
        ["shorts/([%w%-]+)"] = true,
    }
    for pattern, _ in pairs(patterns_to_try) do
        local result = string.match(url, pattern)
        if result then return result end
    end
    return nil
end

-- Fetches sponsor segments from the SponsorBlock API.
function fetch_segments_from_api(video_id)
    if not video_id then return end

    local categories_query_parts = {}
    for cat_name, _ in pairs(categories_to_skip) do
        local api_category = category_map[cat_name]
        if api_category then table.insert(categories_query_parts, "category=" .. api_category) end
    end
    if #categories_query_parts == 0 then return end

    local base_url = "https://sponsor.ajay.app/api/skipSegments"
    local query_string = "videoID=" .. video_id .. "&" .. table.concat(categories_query_parts, "&")
    local full_url = base_url .. "?" .. query_string

    local args = {"curl", "-s", "-L", full_url}
    local res = utils.subprocess({args = args})

    if res.status == 0 and res.stdout and res.stdout ~= "" then
        local segments, err = utils.parse_json(res.stdout)
        if segments and type(segments) == "table" and #segments > 0 then
            msg.info("SponsorBlock API: Found " .. #segments .. " segment(s).")
            sponsor_segments = segments
        end
    end
end

-----------------------------------------------------------------------------
-- Main Logic and Event Handlers
-----------------------------------------------------------------------------

-- Main initialization function, triggered after a file is fully loaded.
function initialize_script_for_file()
    sponsor_segments = nil
    local metadata_blob = nil

    local metadata = mp.get_property_native("metadata")
    if metadata then
        if metadata.comment then metadata_blob = metadata.comment
        elseif metadata.Comment then metadata_blob = metadata.Comment end
    end

    if metadata_blob then
        local extracted_url = extract_url_from_text(metadata_blob)
        if extracted_url then
            local video_id = get_youtube_id(extracted_url)
            if video_id then
                fetch_segments_from_api(video_id)
            end
        end
    end

    -- Run once at the beginning in case we start inside a chapter.
    check_and_skip_chapter()
end

-- Checks the current time against API-provided segments.
function check_api_segments()
    if not sponsor_segments or #sponsor_segments == 0 then return end
    local current_time = mp.get_property_number("time-pos")
    if not current_time then return end

    for _, segment in ipairs(sponsor_segments) do
        if segment.segment and type(segment.segment) == "table" and #segment.segment == 2 then
            local start_time = segment.segment[1]
            local end_time = segment.segment[2]
            if current_time >= start_time and current_time < end_time then
                msg.info("SponsorBlock (API): Skipping '" .. segment.category .. "'.")
                mp.set_property_number("time-pos", end_time)
                return
            end
        end
    end
end

-- Fallback: Checks the current chapter for SponsorBlock markers.
function check_and_skip_chapter()
    -- This fallback logic only runs if the API method has failed.
    if sponsor_segments then return end

    local chapter_list = mp.get_property_native("chapter-list")
    if not chapter_list or #chapter_list == 0 then return end

    local current_chapter_index = mp.get_property_number("chapter")
    if current_chapter_index == nil or current_chapter_index < 0 then return end

    local lua_index = current_chapter_index + 1
    local current_chapter_data = chapter_list[lua_index]
    if not current_chapter_data then return end

    local chapter_title = current_chapter_data.title or ""
    if string.find(chapter_title, "^%[SponsorBlock%]: ") then
        local category_name = string.gsub(chapter_title, "^%[SponsorBlock%]: ", "")
        if categories_to_skip[category_name] then
            local next_chapter_data = chapter_list[lua_index + 1]
            if next_chapter_data then
                msg.info("SponsorBlock (Chapter): Skipping '" .. category_name .. "'.")
                mp.set_property_number("time-pos", next_chapter_data.time)
            end
        end
    end
end

-- Decides which check to run on seek or chapter change.
function on_seek_or_chapter_change()
    if sponsor_segments then
        check_api_segments()
    else
        check_and_skip_chapter()
    end
end

-----------------------------------------------------------------------------
-- Event Registration
-----------------------------------------------------------------------------

mp.register_event("file-loaded", initialize_script_for_file)
mp.observe_property("chapter", "native", on_seek_or_chapter_change)
mp.register_event("seek", on_seek_or_chapter_change)
mp.add_periodic_timer(1, check_api_segments)

msg.info("auto-skip-sponsorblock.lua loaded successfully.")
