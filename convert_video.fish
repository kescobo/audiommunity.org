#!/usr/bin/env fish
#
# ln -s ~/Repos/audiommunity.org/convert_video.fish ~/.local/bin/vid2aud

set video_file $argv[1]
set md_file $argv[2]

# Validate arguments
if test -z "$video_file"
    echo "Error: No video file specified."
    echo "Usage: vid2aud VIDEO_FILE [MARKDOWN_FILE]"
    exit 1
end

if not test -f "$video_file"
    echo "Error: Video file not found: $video_file"
    exit 1
end

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

# Extract metadata from markdown file if provided
set description ""
set ia_title ""
set ia_date ""
set ia_tags ""
if test -n "$md_file" -a -f "$md_file"
    # Extract description (everything after closing +++)
    set description (awk 'BEGIN{p=0} /^\+\+\+$/{p++; next} p==2{print}' "$md_file")

    # Extract title and episode number
    set title_line (grep '^title = ' "$md_file" | sed 's/title = "\(.*\)"/\1/')
    set episode_num (grep '^episode = ' "$md_file" | sed 's/episode = //')
    if test -n "$title_line" -a -n "$episode_num"
        set ia_title "Audiommunity episode $episode_num - $title_line"
    end

    # Extract date
    set date_line (grep '^date = DateTime' "$md_file" | sed 's/.*(\([0-9]\{4\}\), \([0-9]\+\), \([0-9]\+\).*/\1-\2-\3/')
    if test -n "$date_line"
        set ia_date $date_line
    end

    # Extract tags
    set tags_content (awk '/^tags = \[/,/^\]/' "$md_file" | grep '"' | sed 's/.*"\(.*\)".*/\1/' | tr '\n' ';' | sed 's/;$//')
    if test -n "$tags_content"
        set ia_tags $tags_content
    end
else if test -n "$md_file"
    echo "Warning: Markdown file not found: $md_file"
end

# Upload to archive.org
echo "Uploading to archive.org..."
set ia_identifier $base_name

# Build metadata arguments
set metadata_args --metadata="mediatype:audio" --metadata="creator:Audiommunity" --metadata="language:eng" --metadata="licenseurl:https://creativecommons.org/licenses/by/4.0/"

if test -n "$ia_title"
    set metadata_args $metadata_args --metadata="title:$ia_title"
end

if test -n "$description"
    set metadata_args $metadata_args --metadata="description:$description"
end

if test -n "$ia_date"
    set metadata_args $metadata_args --metadata="date:$ia_date"
end

if test -n "$ia_tags"
    set metadata_args $metadata_args --metadata="subject:$ia_tags"
end

#ia upload "$ia_identifier" "$output_file" $metadata_args
echo "$ia_identifier" "$output_file" $metadata_args

if test $status -ne 0
    echo "Error: Upload failed."
    exit 1
end

# Update markdown file with RSS metadata
if test -n "$md_file" -a -f "$md_file"
    echo "Updating markdown file with RSS metadata..."

    # Create temporary file
    set temp_file (mktemp)

    # Read the file and insert metadata before closing +++
    awk -v enclosure="https://archive.org/download/$base_name/$output_file" \
        -v filesize="$filesize" \
        -v dur="$duration" '
    /^\+\+\+$/ {
        if (!seen) {
            seen = 1
            print
            next
        } else {
            print "rss_enclosure = \"" enclosure "\""
            print "episode_length = \"" filesize "\""
            print "itunes_duration = \"" dur "\""
            print
            next
        }
    }
    { print }
    ' "$md_file" >"$temp_file"

    # Replace original file
    mv "$temp_file" "$md_file"

    echo "Markdown file updated successfully!"
end

echo "Conversion and upload complete!"
