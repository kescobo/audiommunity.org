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
    node("ul",
      (
        node("li",
            node("span", class="date", string(Dates.format(p.date, "U d, yyyy"), " | ")),
            node("a", class="title", href=p.href, string("Episode $(p.episode) - ", p.title))
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
    title = getlvar(:title)
    return """
    
    <p>
    <audio controls>
        <source src="$file" type="audio/mpeg">
        Your browser does not support the audio element.
    </audio>
    </p>
    """
end

function hfun_pub_date()
    d = getlvar(:date)
    dt = DateTime(d, Time(10,0,0))
    return Dates.format(dt, "e, d u yyyy HH:MM:SS -0500")
end
