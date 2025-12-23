#!/usr/bin/env julia
#
# ln -s ~/Repos/audiommunity.org/convert_video.jl ~/.local/bin/vid2aud

"""
Convert video file to audio and upload to archive.org with metadata from markdown file.
"""
module ConvertVideo

export main

using Logging
using Markdown

function file_parts(md_file)
    lines = readlines(md_file)
    mdfences = findall(line-> line == "+++", lines)
    (first(mdfences) == 1 && length(mdfences) == 2) || error("Malformed metadata")
    f2 = last(mdfences)
    metadata = lines[2:f2-1]
    rest = lines[f2+1:end]
    return (metadata, rest)
end

function findfirst_and_get(pred, itr, default=nothing)
    idx = findfirst(pred, itr)
    isnothing(idx) ? (nothing, default) : (idx, itr[idx])
end

"""
Extract metadata from episode markdown file.

Returns a named tuple with description, ia_title, ia_date, and ia_tags.
"""
function extract_markdown_metadata(md_file)
    # description = html-formatted "rest"
    metadata,rest = file_parts(md_file)

    # Extract title and episode number
    _, title_line = findfirst_and_get(line-> startswith(line, r"title ?="), metadata)
    title = replace(title_line, r"title ?= ?\"(.+)\"" => s"\1") 

    _, episode_line = findfirst_and_get(line-> startswith(line, r"episode ?="), metadata)
    episode = parse(Int, replace(episode_line, r"episode ?= ?(.+)" => s"\1"))
    
    ia_title = "Audiommunity episode $episode - $title_line"

    # Extract date
    date = ""
    _, date_line = findfirst_and_get(line-> startswith(line, r"date ?="), metadata)
    date_match = match(r".*\((\d{4}), ?(\d+), ?(\d+).*", date_line)
    year, month, day = date_match.captures
    ia_date = "$year-$month-$day"

    # Extract tags
    tag_list = String[]
    tagst, tagline = findfirst_and_get(line->startswith(line, r"tags ?= ?\["), metadata)
    tagend = findfirst(line-> contains(line, "]"), metadata[tagst:end]) + tagst - 1
    for line in metadata[tagst:tagend]
        tags = split(line, r"[,\"]")
        tags = strip.(replace.(tags, "tags ="=> "", r"[^\w ]"=>""))
        for tag in replace.(tags, "tags ="=> "", r"[^\w ]"=>"")
            !isempty(tag) && push!(tag_list, tag)
        end
    end
    ia_tags = !isempty(tag_list) ? join(tag_list, ';') : ""

    description = html(Markdown.parse(join(rest, "\n")))


    return (description=description, ia_title=ia_title, ia_date=ia_date, ia_tags=ia_tags)
end

"""
Update markdown file with RSS metadata (enclosure URL, file size, duration).
"""
function update_markdown_with_rss(md_file::String, episode_num::Int, filesize::Int, duration::Int)
    @info "Updating markdown file with RSS metadata"
    metadata, rest = file_parts(md_file)
    eppath = "audiommunity_episode$(lpad(episode_num, 3, '0'))"
    enclosure = "https://archive.org/download/$eppath/$eppath.mp3"
    plus_count = 0

    if !any(line-> startswith(line, "rss_enclosure"), metadata)
        push!(metadata, "rss_enclosure = \"$enclosure\"")
    end
    if !any(line-> startswith(line, "episode_length"), metadata)
        push!(metadata, "episode_length = \"$filesize\"")
    end
    if !any(line-> startswith(line, "itunes_duration"), metadata)
        push!(metadata, "itunes_duration = \"$duration\"")
    end

    write(md_file, join(["+++"; metadata; "+++"; rest], '\n'))
    @info "Markdown file updated successfully"
end

function (@main)(args)
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
    epnum = parse(Int, match(r"(\d+)", base_name)[1])

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
    metadata = extract_markdown_metadata(md_file)

    # Upload to archive.org
    @info "Uploading to archive.org" ia_identifier=base_name
    ia_identifier = base_name

    # Build metadata arguments
    metadata_args = [
        "--metadata=mediatype:audio",
        "--metadata=creator:Audiommunity",
        "--metadata=language:eng",
        "--metadata=licenseurl:https://creativecommons.org/licenses/by/4.0/",
        "--metadata=title:$(metadata.ia_title)",
        "--metadata=description:$(metadata.description)",
        "--metadata=date:$(metadata.ia_date)",
        "--metadata=subject:$(metadata.ia_tags)",
    ]
    # For now, just echo the command (uncomment to actually upload)
    cmd = Cmd([["ia", "upload", ia_identifier, output_file]; metadata_args])
    @info cmd

    # ia_result = run(cmd)
    #
    # if !success(ia_result)
    #     @error "Upload failed"
    #     return 1
    # end

    # Upload to YouTube (requires youtube-upload tool and OAuth setup)
    # Setup:
    #   1. pip install --upgrade youtube-upload
    #   2. Create OAuth 2.0 credentials at https://console.cloud.google.com/
    #   3. Enable YouTube Data API v3
    #   4. Download client_secrets.json
    #   5. First run: youtube-upload --client-secrets=client_secrets.json test.mp4
    #      (creates request.token for future automated uploads)
    # Note: Unverified projects can only upload as "unlisted" or "private"
    #
    # @info "Uploading to YouTube" video_file
    # yt_args = ["--client-secrets", "client_secrets.json"]
    #
    # if !isempty(metadata.ia_title)
    #     push!(yt_args, "--title", metadata.ia_title)
    # end
    #
    # if !isempty(metadata.description)
    #     push!(yt_args, "--description", metadata.description)
    # end
    #
    # if !isempty(metadata.ia_tags)
    #     # YouTube uses comma-separated tags, archive.org uses semicolons
    #     yt_tags = replace(metadata.ia_tags, ';' => ',')
    #     push!(yt_args, "--tags", yt_tags)
    # end
    #
    # push!(yt_args, "--category", "Education")
    # push!(yt_args, "--privacy", "unlisted")  # or "public" once verified
    # push!(yt_args, video_file)
    #
    # yt_result = run(`youtube-upload $yt_args`, wait=false)
    # wait(yt_result)
    #
    # if !success(yt_result)
    #     @error "YouTube upload failed"
    #     return 1
    # end

    # Update markdown file with RSS metadata
    if !isempty(md_file)
        update_markdown_with_rss(md_file, epnum, filesize, duration)
    end

    @info "Conversion and upload complete"
    return 0
end

end # module
