This script watches for chapters that are title: [SponsorBlock]: Sponsor or similar and skips to the next chapter.

Be sure that you include `--sponsorblock-mark all` on your yt-dlp so as to mark the ads.  Optionally you can only pull specific SponsorBlock marks if you prefer.

To install, place `auto-skip-sponsorblock.lua` in your mpv scripts folder (`~/.config/mpv/scripts`) and it should automatically load.  If it doesn't, add `--msg-level=all=v` for clues as to why.
