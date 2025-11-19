#!/usr/bin/env julia
#
# ln -s ~/Repos/audiommunity.org/convert_video.jl ~/.local/bin/vid2aud

"""
Convert video file to audio and upload to archive.org with metadata from markdown file.
"""
module ConvertVideo

using Logging

"""
Extract metadata from episode markdown file.

Returns a named tuple with description, ia_title, ia_date, and ia_tags.
"""
function extract_markdown_metadata(md_file::String)
    if !isfile(md_file)
        @warn "Markdown file not found" md_file
        return (description="", ia_title="", ia_date="", ia_tags="")
    end

    md_content = read(md_file, String)
    lines = split(md_content, '\n')

    # Extract description (everything after closing +++)
    plus_count = 0
    description_lines = String[]
    for line in lines
        if line == "+++"
            plus_count += 1
            continue
        end
        if plus_count >= 2
            push!(description_lines, line)
        end
    end
    description = join(description_lines, '\n')

    # Extract title and episode number
    title_line = ""
    episode_num = ""
    for line in lines
        if startswith(line, "title = ")
            title_match = match(r"title = \"(.*)\"", line)
            if title_match !== nothing
                title_line = title_match.captures[1]
            end
        elseif startswith(line, "episode = ")
            episode_match = match(r"episode = (.*)", line)
            if episode_match !== nothing
                episode_num = episode_match.captures[1]
            end
        end
    end

    ia_title = ""
    if !isempty(title_line) && !isempty(episode_num)
        ia_title = "Audiommunity episode $episode_num - $title_line"
    end

    # Extract date
    ia_date = ""
    for line in lines
        if startswith(line, "date = DateTime")
            date_match = match(r".*\((\d{4}), (\d+), (\d+).*", line)
            if date_match !== nothing
                year, month, day = date_match.captures
                ia_date = "$year-$month-$day"
            end
        end
    end

    # Extract tags
    in_tags = false
    tag_list = String[]
    for line in lines
        if startswith(line, "tags = [")
            in_tags = true
            if contains(line, "]")
                in_tags = false
                tag_match = match(r"tags = \[(.*)\]", line)
                if tag_match !== nothing
                    tags_str = tag_match.captures[1]
                    for tag in split(tags_str, ',')
                        tag_cleaned = strip(tag)
                        tag_quoted = match(r"\"(.*)\"", tag_cleaned)
                        if tag_quoted !== nothing
                            push!(tag_list, tag_quoted.captures[1])
                        end
                    end
                end
            end
            continue
        end

        if in_tags
            if startswith(line, "]")
                in_tags = false
                continue
            end
            tag_match = match(r"\"(.*)\"", line)
            if tag_match !== nothing
                push!(tag_list, tag_match.captures[1])
            end
        end
    end

    ia_tags = !isempty(tag_list) ? join(tag_list, ';') : ""

    return (description=description, ia_title=ia_title, ia_date=ia_date, ia_tags=ia_tags)
end

"""
Update markdown file with RSS metadata (enclosure URL, file size, duration).
"""
function update_markdown_with_rss(md_file::String, base_name::String, output_file::String, filesize::Int, duration::Int)
    if !isfile(md_file)
        return
    end

    @info "Updating markdown file with RSS metadata"

    lines = readlines(md_file)

    enclosure = "https://archive.org/download/$base_name/$output_file"
    plus_count = 0
    new_lines = String[]

    for line in lines
        if line == "+++"
            plus_count += 1
            if plus_count == 1
                push!(new_lines, line)
            elseif plus_count == 2
                push!(new_lines, "rss_enclosure = \"$enclosure\"")
                push!(new_lines, "episode_length = \"$filesize\"")
                push!(new_lines, "itunes_duration = \"$duration\"")
                push!(new_lines, line)
            end
        else
            push!(new_lines, line)
        end
    end

    write(md_file, join(new_lines, '\n'))
    @info "Markdown file updated successfully"
end

"""
Main entry point for video to audio conversion and upload.

Usage: convert_video.jl VIDEO_FILE [MARKDOWN_FILE]
"""
@main function main(args)
    # Parse arguments
    video_file = length(args) >= 1 ? args[1] : ""
    md_file = length(args) >= 2 ? args[2] : ""

    # Validate arguments
    if isempty(video_file)
        @error "No video file specified" usage="convert_video.jl VIDEO_FILE [MARKDOWN_FILE]"
        return 1
    end

    if !isfile(video_file)
        @error "Video file not found" video_file
        return 1
    end

    # Get base name without extension
    base_name = splitext(basename(video_file))[1]
    output_file = "$base_name.mp3"

    # Convert video to audio using ffmpeg
    @info "Converting video to audio" video_file output_file
    ffmpeg_result = run(pipeline(`ffmpeg -i $video_file -q:a 0 -map a $output_file -y -loglevel error`,
                                 stderr=stderr), wait=false)
    wait(ffmpeg_result)

    if !success(ffmpeg_result)
        @error "Conversion failed"
        return 1
    end

    # Get file size in bytes
    filesize = stat(output_file).size

    # Get duration in seconds using ffprobe
    duration_output = read(`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $output_file`, String)
    duration = round(Int, parse(Float64, strip(duration_output)))

    # Extract metadata from markdown file if provided
    metadata = (description="", ia_title="", ia_date="", ia_tags="")
    if !isempty(md_file)
        metadata = extract_markdown_metadata(md_file)
    end

    # Upload to archive.org
    @info "Uploading to archive.org" ia_identifier=base_name
    ia_identifier = base_name

    # Build metadata arguments
    metadata_args = [
        "--metadata=mediatype:audio",
        "--metadata=creator:Audiommunity",
        "--metadata=language:eng",
        "--metadata=licenseurl:https://creativecommons.org/licenses/by/4.0/"
    ]

    if !isempty(metadata.ia_title)
        push!(metadata_args, "--metadata=title:$(metadata.ia_title)")
    end

    if !isempty(metadata.description)
        push!(metadata_args, "--metadata=description:$(metadata.description)")
    end

    if !isempty(metadata.ia_date)
        push!(metadata_args, "--metadata=date:$(metadata.ia_date)")
    end

    if !isempty(metadata.ia_tags)
        push!(metadata_args, "--metadata=subject:$(metadata.ia_tags)")
    end

    # For now, just echo the command (uncomment to actually upload)
    @info "Upload command" ia_identifier output_file metadata=join(metadata_args, " ")
    # ia_result = run(`ia upload $ia_identifier $output_file $metadata_args`, wait=false)
    # wait(ia_result)
    #
    # if !success(ia_result)
    #     @error "Upload failed"
    #     return 1
    # end

    # Update markdown file with RSS metadata
    if !isempty(md_file)
        update_markdown_with_rss(md_file, base_name, output_file, filesize, duration)
    end

    @info "Conversion and upload complete"
    return 0
end

end # module
