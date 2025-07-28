@reexport using Dates
import Hyperscript as HS

node = HS.m



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

# ===============================================
# Logic to retrieve posts in episodes/ and display
# them as a list sorted by anti-chronological
# order.
#
# Assumes that 'date' and 'title' are defined for
# all posts.
# ===============================================

function hfun_list_episodes(tag::String, basepath::String="episodes")
  return string(
    node("div", class = "podcast-grid",
      Iterators.flatten(
        (
         node("div", class="date", Dates.format(p.date, "U d, yyyy")),
         node("div", class="title",
              node("a", href=p.href, string("Episode $(p.episode) - ", p.title))
             )
        )
        for p in get_episodes(tag, basepath) if !p.draft
      )...
    )
  )
end

hfun_list_episodes() = hfun_list_episodes("", "episodes")


function get_episodes(tag::String, basepath::String)
    # find all valid "episodes/xxx.md" files, exclude the index which is where
    # the post-list gets placed
    paths = String[]
    for (root, dirs, files) in walkdir(basepath)
        filter!(p -> endswith(p, ".md") && p != "index.md", files)
        append!(paths, joinpath.(root, files))
    end
    # for each of those posts, retrieve date and title, both are expected
    # to be there
    posts = [
        (;
            date    = getvarfrom(:date, rp),
            title   = getvarfrom(:title, rp),
            href    = "/$(splitext(rp)[1])",
            draft   = getvarfrom(:draft, rp, false),
            tags    = get_page_tags(rp),
            episode = getvarfrom(:episode, rp, "X"),
            season  = getvarfrom(:episode, rp, "Y"),
        )
        for rp in paths
    ]
    sort!(posts, by=x -> x.date, rev=true)
    if !isempty(tag)
        filter!(posts) do p
            t in values(p.tags) &&
            !isnothing(p.draft) &&
            !p.draft
        end
    end
    return posts
end
#---

function hfun_list_people()
    return string(
        node("div", class="cards-row",
        (
        node("div", class="card-column",
            node("div", class="card-body", 
                node("img", src=p.portrait),
                node("div", class="card-container", 
                    node("h2", node("a", href=p.href, p.name)),
                    node("div", class="card-title", p.title),
                    node("div", class="card-content", p.content),
                    node("p", node("a", href=p.href,
                            node("button", class="card-button", "Details")
                           )
                    )
                )
            )
           ) for p in get_people()
        )...
        )
    )
end

function person_info(rp)
    # Read the markdown file and extract content after frontmatter
    content = ""
    if isfile(rp)
        file_content = read(rp, String)
        # Split by frontmatter delimiters (+++...+++)
        parts = split(file_content, "+++")
        if length(parts) >= 3
            # Content is after the second +++
            content = strip(parts[3])
        end
    end
    
    return (;
    name=getvarfrom(:name, rp),
    title=getvarfrom(:title, rp),
    portrait=getvarfrom(:portrait, rp, "/assets/portrait_placeholder.png"),
    href="/$(splitext(rp)[1])",
    tags=get_page_tags(rp),
    content=content
    )
end

function get_people(basepath::String="about")
    # find all valid "people/xxx.md" files, exclude the index which is where
    # the people list gets placed
    paths = String[]
    for (root, dirs, files) in walkdir(basepath)
        filter!(p -> endswith(p, ".md") && p != "index.md", files)
        append!(paths, joinpath.(root, files))
    end
    # for each of those people, get their info
    posts = [person_info(rp) for rp in paths]
    return posts
end

function hfun_person_header()
    person = person_info(get_rpath())
    return string(node("div", class="franklin-content", 

        node("div", class="profile-header",
            node("div", class="profile-info",
                node("h1", class="profile-name", person.name),
                node("div", class="profile-title", person.title),
            ),
            node("div", class="profile-image-container",
                 node("img", class="profile-image", src=person.portrait, alt="$(person.name)")
            )
        ),

    ))
end



#---

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

function hfun_pub_date(d)
    @warn d
    date = Date(d)
    dt = DateTime(date, Time(10,0,0))
    return Dates.format(dt, "e, d u yyyy HH:MM:SS -0500")
end

function hfun_episode_title()
    title = getlvar(:title)
    epnum = getlvar(:episode)
    return """
    <h1>Episode $epnum - $title</h1>
    """
end

function hfun_episode_metadata()
    date = getlvar(:date)
    duration = getlvar(:itunes_duration, "")
    
    # Format date
    formatted_date = Dates.format(date, "U d, yyyy")
    
    # Format duration (convert seconds to hh:mm:ss)
    if !isempty(duration) && occursin(r"^\d+$", duration)
        total_seconds = parse(Int, duration)
        hours = total_seconds ÷ 3600
        minutes = (total_seconds % 3600) ÷ 60
        seconds = total_seconds % 60
        formatted_duration = "$(hours):$(lpad(minutes, 2, '0')):$(lpad(seconds, 2, '0'))"
    else
        formatted_duration = ""
    end
    
    metadata_items = [
        node("div", class="metadata-item",
            node("span", class="metadata-label", "Published: "),
            node("span", class="metadata-value", formatted_date)
        )
    ]
    
    if !isempty(formatted_duration)
        push!(metadata_items, 
            node("div", class="metadata-item",
                node("span", class="metadata-label", "Duration: "),
                node("span", class="metadata-value", formatted_duration)
            )
        )
    end
    
    # Add tags - reconstruct using node() instead of raw HTML
    tags = get_page_tags()
    if !isempty(tags)
        base = globvar(:tags_prefix)
        tag_nodes = [
            node("span", class="tag",
                node("a", href="/$base/$id/", name)
            )
            for (id, name) in tags
        ]
        
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

function hfun_tag_episodes_table()
    # Get the current tag name from the page context (try different methods)
    tag = getlvar(:tag, nothing)
    if tag === nothing
        tag = getlvar(:fd_tag, nothing) 
    end
    if tag === nothing
        # Try getting from the URL path
        rpath = getlvar(:fd_rpath, "")
        if !isempty(rpath)
            path_parts = split(rpath, "/")
            if length(path_parts) >= 2 && path_parts[end-1] != ""
                tag = path_parts[end-1] # assumes /tags/tagname/index pattern
            end
        end
    end
    
    # Get all episodes first, then filter by tag
    all_posts = get_episodes("", "episodes")
    
    # Try to get tag_name like the template does
    if tag === nothing
        tag = getlvar(:tag_name, nothing)
    end

    # Filter posts that have the specific tag (check both keys and values)
    filtered_posts = filter(all_posts) do p
        !p.draft && (haskey(p.tags, tag) || tag in values(p.tags))
    end
 
    if isempty(filtered_posts)
        return "<p>No episodes found for this topic.</p>"
    end
 
    # Create episode blocks
    episode_blocks = [
        node("div", class="episode-block",
            node("div", class="episode-header",
                node("span", class="episode-date", Dates.format(p.date, "U d, yyyy")),
                node("span", class="episode-title",
                    node("a", href=p.href, 
                        "Episode $(p.episode) - $(p.title)"
                    )
                )
            ),
            node("div", class="episode-description", 
                # Try to get the rss_descr from the episode file
                begin
                    episode_file = "episodes/episode$(lpad(p.episode, 3, "0")).md"
                    getvarfrom(:rss_descr, episode_file, "")
                end
            )
        )
        for p in filtered_posts
    ]
 
    return string(
        node("div", class="tag-episodes-container", episode_blocks...)
    )
end

function hfun_latest_episode()
    # Get all episodes and find the latest one
    all_posts = get_episodes("", "episodes")
    
    if isempty(all_posts)
        return "<p>No episodes found.</p>"
    end
    
    # The posts are already sorted by date (newest first)
    latest = first(all_posts)
    
    # Get episode description
    episode_file = "episodes/episode$(lpad(latest.episode, 3, "0")).md"
    description = getvarfrom(:rss_descr, episode_file, "")
    
    # Format duration from the episode file
    duration = getvarfrom(:itunes_duration, episode_file, "")
    formatted_duration = ""
    if !isempty(duration) && occursin(r"^\d+$", duration)
        total_seconds = parse(Int, duration)
        hours = total_seconds ÷ 3600
        minutes = (total_seconds % 3600) ÷ 60
        seconds = total_seconds % 60
        formatted_duration = "$(hours):$(lpad(minutes, 2, '0')):$(lpad(seconds, 2, '0'))"
    end
    
    # Get the audio file URL for the player
    audio_file = getvarfrom(:rss_enclosure, episode_file, "")
    
    # Create the latest episode box
    return string(
        node("div", class="latest-episode-box",
            node("div", class="latest-episode-header",
                node("h3", "Latest Episode"),
                node("span", class="episode-date", Dates.format(latest.date, "U d, yyyy"))
            ),
            node("div", class="latest-episode-content",
                node("h4", class="episode-title",
                    node("a", href=latest.href,
                        "Episode $(latest.episode) - $(latest.title)"
                    )
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
                node("div", class="episode-actions",
                    node("a", href=latest.href, class="btn-listen", "Episode Page"),
                    node("a", href="/episodes/", class="btn-all-episodes", "All Episodes")
                )
            )
        )
    )
end
