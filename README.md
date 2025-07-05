This script pulls the sponsor segments from https://sponsor.ajay.app. Optionally you can only use specific SponsorBlock marks if you prefer.

You must include --embed-metadata in your yt-dlp download command to get the URL/Video ID used in the API requests.

To install, place `auto-skip-sponsorblock.lua` in your mpv scripts folder (`~/.config/mpv/scripts`) and it should automatically load.  If it doesn't, add `--msg-level=all=v` for clues as to why.
