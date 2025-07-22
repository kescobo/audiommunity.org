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
