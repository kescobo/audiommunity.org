#!/usr/bin/env fish
#
# ln -s ~/Repos/audiommunity.org/convert_video.fish ~/.local/bin/vid2aud

set video_file $argv[1]

# Get base name without extension
set base_name (basename $video_file .mp4)
set output_file "$base_name.mp3"

# Convert video to audio using ffmpeg
echo "Converting $video_file to $output_file..."
ffmpeg -i "$video_file" -q:a 0 -map a "$output_file" -y -loglevel error

# Check if conversion was successful
if test $status -ne 0
    echo "Error: Conversion failed."
    exit 1
end

# Get file size in bytes
set filesize (stat -c %s "$output_file" 2>/dev/null; or stat -f %z "$output_file")

# Get duration in seconds using ffprobe
set duration (ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$output_file")
set duration (printf "%.0f" $duration)

# Print the requested information
echo "rss_enclosure = \"https://archive.org/download/$base_name/$output_file\""
echo "episode_length = \"$filesize\""
echo "itunes_duration = \"$duration\""

echo "Conversion complete!"

