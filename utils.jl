"""
Utilities for Audiommunity.org website built with Xranklin.jl

This file contains helper functions for generating HTML content, managing episodes,
and handling about page functionality for the Audiommunity podcast website.
"""

@reexport using Dates
import Hyperscript as HS

node = HS.m

# ===============================================
# SHARED UTILITY FUNCTIONS
# ===============================================

"""
    extract_markdown_content(file_path::String)::String

Extract markdown content from a file, removing frontmatter delimiters.
Returns the content after the second '+++' delimiter, or empty string if not found.
"""
function extract_markdown_content(file_path::String)
    if !isfile(file_path)
        return ""
    end
    
    file_content = read(file_path, String)
    parts = split(file_content, "+++")
    
    return length(parts) >= 3 ? strip(parts[3]) : ""
end

"""
    format_duration_from_seconds(duration_str::String)::String

Convert a duration in seconds (as string) to HH:MM:SS format.
Returns empty string if input is invalid or empty.
"""
function format_duration_from_seconds(duration_str::String)
    if isempty(duration_str) || !occursin(r"^\d+$", duration_str)
        return ""
    end
    
    total_seconds = parse(Int, duration_str)
    hours = total_seconds ÷ 3600
    minutes = (total_seconds % 3600) ÷ 60
    seconds = total_seconds % 60
    
    return "$(hours):$(lpad(minutes, 2, '0')):$(lpad(seconds, 2, '0'))"
end

"""
    format_date_display(date::Union{Date,DateTime})::String

Format a date for display in the website (e.g., "January 15, 2024").
Accepts both Date and DateTime objects.
"""
format_date_display(date::Union{Date,DateTime}) = Dates.format(date, "U d, yyyy")

"""
    extract_youtube_video_id(url::String)::String

Extract video ID from a YouTube URL. Supports both youtube.com/watch and youtu.be formats.
Returns empty string if URL is invalid or no video ID found.
"""
function extract_youtube_video_id(url::String)
    if isempty(url)
        return ""
    end
    
    if occursin("youtube.com/watch?v=", url)
        return string(split(split(url, "v=")[2], "&")[1])
    elseif occursin("youtu.be/", url)
        return string(split(split(url, "youtu.be/")[2], "?")[1])
    end
    
    return ""
end

"""
    create_youtube_embed_node(video_id::String)::Node

Create a YouTube iframe embed node for the given video ID.
"""
function create_youtube_embed_node(video_id::String)
    return node("div", class="youtube-container",
        node("iframe", 
            src="https://www.youtube.com/embed/$video_id",
            title="YouTube video player",
            frameborder="0",
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share",
            referrerpolicy="strict-origin-when-cross-origin",
            allowfullscreen="true"
        )
    )
end

"""
    get_episode_file_path(episode_number)::String

Generate the file path for an episode given its number.
"""
get_episode_file_path(episode_number) = "episodes/episode$(lpad(episode_number, 3, "0")).md"

"""
    collect_markdown_files(basepath::String)::Vector{String}

Collect all markdown files in a directory, excluding index.md files.
"""
function collect_markdown_files(basepath::String)
    paths = String[]
    for (root, dirs, files) in walkdir(basepath)
        filter!(p -> endswith(p, ".md") && p != "index.md", files)
        append!(paths, joinpath.(root, files))
    end
    return paths
end

# ===============================================
# TAG SYSTEM FUNCTIONS
# ===============================================

"""
    hfun_page_tags()::String

Generate HTML for displaying tags on a page, with links to tag index pages.
"""
function hfun_page_tags()
    tags = get_page_tags()
    base = globvar(:tags_prefix)
    return join(
        (
            node("span", class="tag",
                node("a", href="/$base/$id/", name)
            )
            for (id, name) in tags
        ),
        node("span", class="separator", "•")
    )
end

"""
    create_tag_nodes(tags, base_path::String)::Vector{Node}

Create a vector of tag nodes for display, with links to tag pages.
"""
function create_tag_nodes(tags, base_path::String)
    return [
        node("span", class="tag",
            node("a", href="/$base_path/$id/", name)
        )
        for (id, name) in tags
    ]
end

# ===============================================
# EPISODE MANAGEMENT FUNCTIONS
# ===============================================

"""
    get_episodes(tag::String="", basepath::String="episodes")::Vector{NamedTuple}

Retrieve and process episode information from markdown files.
Returns a vector of episode data sorted by date (newest first).
"""
function get_episodes(tag::String="", basepath::String="episodes")
    paths = collect_markdown_files(basepath)
    
    # Extract episode information from each file
    episodes = [
        (
            date    = getvarfrom(:date, rp),
            title   = getvarfrom(:title, rp),
            href    = "/$(splitext(rp)[1])",
            draft   = getvarfrom(:draft, rp, false),
            tags    = get_page_tags(rp),
            episode = getvarfrom(:episode, rp, "X"),
            season  = getvarfrom(:season, rp, "Y"),
        )
        for rp in paths
    ]
    
    # Sort by date (newest first)
    sort!(episodes, by=x -> x.date, rev=true)
    
    # Filter by tag if specified
    if !isempty(tag)
        filter!(episodes) do ep
            tag in values(ep.tags) && !isnothing(ep.draft) && !ep.draft
        end
    end
    
    return episodes
end

"""
    hfun_list_episodes(tag::String="", basepath::String="episodes")::String

Generate HTML for displaying a list of episodes in a grid format.
"""
function hfun_list_episodes(tag::String="", basepath::String="episodes")
    episodes = get_episodes(tag, basepath)
    
    return string(
        node("div", class="podcast-grid",
            Iterators.flatten(
                (
                    node("div", class="date", format_date_display(ep.date)),
                    node("div", class="title",
                        node("a", href=ep.href, "Episode $(ep.episode) - $(ep.title)")
                    )
                )
                for ep in episodes if !ep.draft
            )...
        )
    )
end

"""
    hfun_episode_title()::String

Generate the main title for an episode page.
"""
function hfun_episode_title()
    title = getlvar(:title)
    episode_num = getlvar(:episode)
    return "<h1>Episode $episode_num - $title</h1>"
end

"""
    hfun_episode_metadata()::String

Generate the metadata section for an episode page, including date, duration, and tags.
"""
function hfun_episode_metadata()
    date = getlvar(:date) 
    duration = getlvar(:itunes_duration, "")
    
    # Build metadata items
    metadata_items = [
        node("div", class="metadata-item",
            node("span", class="metadata-label", "Published: "),
            node("span", class="metadata-value", format_date_display(date))
        )
    ]
    
    # Add duration if available
    formatted_duration = format_duration_from_seconds(duration)
    if !isempty(formatted_duration)
        push!(metadata_items, 
            node("div", class="metadata-item",
                node("span", class="metadata-label", "Duration: "),
                node("span", class="metadata-value", formatted_duration)
            )
        )
    end
    
    # Add tags if available
    tags = get_page_tags()
    if !isempty(tags)
        base = globvar(:tags_prefix)
        tag_nodes = create_tag_nodes(tags, base)
        
        push!(metadata_items,
            node("div", class="metadata-item",
                node("span", class="metadata-label", "Topics: "),
                node("div", class="metadata-tags", tag_nodes...)
            )
        )
    end
    
    return string(
        node("div", class="episode-metadata", metadata_items...)
    )
end

"""
    hfun_tag_episodes_table()::String

Generate a table of episodes for a specific tag page.
"""
function hfun_tag_episodes_table()
    # Determine the current tag from various possible sources
    tag = getlvar(:tag, nothing)
    if tag === nothing
        tag = getlvar(:fd_tag, nothing) 
    end
    if tag === nothing
        tag = getlvar(:tag_name, nothing)
    end
    if tag === nothing
        # Try extracting from URL path
        rpath = getlvar(:fd_rpath, "")
        if !isempty(rpath)
            path_parts = split(rpath, "/")
            if length(path_parts) >= 2 && path_parts[end-1] != ""
                tag = path_parts[end-1]
            end
        end
    end
    
    # Get episodes and filter by tag
    all_episodes = get_episodes("", "episodes")
    filtered_episodes = filter(all_episodes) do ep
        !ep.draft && (haskey(ep.tags, tag) || tag in values(ep.tags))
    end
 
    if isempty(filtered_episodes)
        return "<p>No episodes found for this topic.</p>"
    end
 
    # Create episode blocks
    episode_blocks = [
        node("div", class="episode-block",
            node("div", class="episode-header",
                node("span", class="episode-date", format_date_display(ep.date)),
                node("span", class="episode-title",
                    node("a", href=ep.href, "Episode $(ep.episode) - $(ep.title)")
                )
            ),
            node("div", class="episode-description", 
                getvarfrom(:rss_descr, get_episode_file_path(ep.episode), "")
            )
        )
        for ep in filtered_episodes
    ]
 
    return string(
        node("div", class="tag-episodes-container", episode_blocks...)
    )
end

"""
    hfun_latest_episode()::String

Generate the "Latest Episode" box for the homepage, including audio player and optional YouTube embed.
"""
function hfun_latest_episode()
    episodes = get_episodes("", "episodes")
    
    if isempty(episodes)
        return "<p>No episodes found.</p>"
    end
    
    latest = first(episodes)
    episode_file = get_episode_file_path(latest.episode)
    
    # Get episode metadata
    description = getvarfrom(:rss_descr, episode_file, "")
    duration = getvarfrom(:itunes_duration, episode_file, "")
    audio_file = getvarfrom(:rss_enclosure, episode_file, "")
    
    # Format duration
    formatted_duration = format_duration_from_seconds(duration)
    
    # Handle YouTube embed if available
    youtube_url = getvarfrom(:youtube, episode_file, "")
    youtube_nodes = []
    if !isempty(youtube_url)
        video_id = extract_youtube_video_id(youtube_url)
        if !isempty(video_id)
            push!(youtube_nodes, create_youtube_embed_node(video_id))
        end
    end
    
    # Build the episode box
    return string(
        node("div", class="latest-episode-box",
            node("div", class="latest-episode-header",
                node("h3", "Latest Episode"),
                node("span", class="episode-date", format_date_display(latest.date))
            ),
            node("div", class="latest-episode-content",
                node("h4", class="episode-title",
                    node("a", href=latest.href, "Episode $(latest.episode) - $(latest.title)")
                ),
                !isempty(description) ? node("p", class="episode-description", description) : "",
                !isempty(formatted_duration) ? node("div", class="episode-meta",
                    node("span", class="duration", "Duration: $formatted_duration")
                ) : "",
                !isempty(audio_file) ? node("div", class="episode-player",
                    node("audio", controls="controls", preload="metadata",
                        node("source", src=audio_file, type="audio/mpeg"),
                        "Your browser does not support the audio element."
                    )
                ) : "",
                youtube_nodes...,
                node("div", class="episode-actions",
                    node("a", href=latest.href, class="btn-listen", "Episode Page"),
                    node("a", href="/episodes/", class="btn-all-episodes", "All Episodes")
                )
            )
        )
    )
end

# ===============================================
# MEDIA EMBEDDING FUNCTIONS
# ===============================================

"""
    hfun_embed_audio()::String

Generate HTML for embedding the audio player on episode pages.
Uses the rss_enclosure variable from the episode's frontmatter.
"""
function hfun_embed_audio()
    file = getlvar(:rss_enclosure)
    return """
    
    <p>
    <audio controls preload="metadata">
        <source src="$file" type="audio/mpeg">
        Your browser does not support the audio element.
    </audio>
    </p>
    """
end

"""
    hfun_embed_youtube()::String

Generate HTML for embedding YouTube videos on episode pages.
Shows placeholder message if no video is available or URL is invalid.
"""
function hfun_embed_youtube()
    youtube_url = getlvar(:youtube, "")
    
    if isempty(youtube_url)
        return string(
            node("div", class="youtube-placeholder",
                node("p", "No YouTube video available for this episode")
            )
        )
    end
    
    video_id = extract_youtube_video_id(youtube_url)
    
    if isempty(video_id)
        return string(
            node("div", class="youtube-placeholder",
                node("p", "Invalid YouTube URL for this episode")
            )
        )
    end
    
    return string(create_youtube_embed_node(video_id))
end

# ===============================================
# PEOPLE/ABOUT PAGE FUNCTIONS
# ===============================================

"""
    person_info(file_path::String)::NamedTuple

Extract information about a person from their markdown file.
Returns a named tuple with all relevant person data including social media links.
"""
function person_info(file_path::String)
    content = extract_markdown_content(file_path)
    
    return (
        name = getvarfrom(:name, file_path),
        title = getvarfrom(:title, file_path),
        portrait = getvarfrom(:portrait, file_path, "/assets/portrait_placeholder.png"),
        href = "/$(splitext(file_path)[1])",
        tags = get_page_tags(file_path),
        content = content,
        linkedin = getvarfrom(:linkedin, file_path, ""),
        bluesky = getvarfrom(:bluesky, file_path, "")
    )
end

"""
    get_people(basepath::String="about")::Vector{NamedTuple}

Retrieve information about all people from markdown files in the specified directory.
"""
function get_people(basepath::String="about")
    paths = collect_markdown_files(basepath)
    return [person_info(rp) for rp in paths]
end

"""
    create_social_media_links(person)::Vector{Node}

Create social media link nodes for a person's LinkedIn and Bluesky profiles.
"""
function create_social_media_links(person)
    social_links = []
    
    if !isempty(person.linkedin)
        push!(social_links, 
            node("a", href="https://linkedin.com/in/$(person.linkedin)", target="_blank", class="social-link",
                node("i", class="fab fa-linkedin", "")
            )
        )
    end
    
    if !isempty(person.bluesky)
        push!(social_links, 
            node("a", href="https://bsky.app/profile/$(person.bluesky)", target="_blank", class="social-link",
                node("i", class="fa-brands fa-bluesky", "")
            )
        )
    end
    
    return social_links
end

"""
    hfun_list_people()::String

Generate HTML for displaying all people in card format on the about page.
"""
function hfun_list_people()
    people = get_people()
    
    return string(
        node("div", class="cards-row",
            (
                node("div", class="card-column",
                    node("div", class="card-body", 
                        node("img", src=person.portrait),
                        node("div", class="card-container", 
                            node("h2", node("a", href=person.href, person.name)),
                            node("div", class="card-title", person.title),
                            node("div", class="card-social", create_social_media_links(person)...),
                            node("div", class="card-content", person.content)
                            # Details button commented out for now
                            # node("p", node("a", href=person.href,
                            #     node("button", class="card-button", "Details")
                            # ))
                        )
                    )
                ) for person in people
            )...
        )
    )
end

"""
    hfun_person_header()::String

Generate the header section for individual person pages.
"""
function hfun_person_header()
    person = person_info(get_rpath()) 
    
    return string(
        node("div", class="franklin-content", 
            node("div", class="profile-header",
                node("div", class="profile-info",
                    node("h1", class="profile-name", person.name),
                    node("div", class="profile-title", person.title),
                ),
                node("div", class="profile-image-container",
                    node("img", class="profile-image", src=person.portrait, alt="$(person.name)")
                )
            )
        )
    )
end

# ===============================================
# RSS/FEED UTILITY FUNCTIONS
# ===============================================

"""
    hfun_pub_date(date_string)::String

Format a date for RSS feed publication. 
Converts date to RFC 2822 format required by RSS feeds.
"""
function hfun_pub_date(date_string)
    @warn date_string  # Keep for debugging RSS issues
    date = Date(date_string)
    dt = DateTime(date, Time(10, 0, 0))
    return Dates.format(dt, "e, d u yyyy HH:MM:SS -0500")
end
