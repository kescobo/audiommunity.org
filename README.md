# Audiommunity

This is the code for generating the website audiommunity.org,
and for hosting **Audiommunity**,
a podcast about our bodies' never-ending fight with the outside world.

It uses Xranklin.jl as a static-site generator,
but most of the pages are just written in markdown.
If you have a suggestion for the site or notice any typos,
please feel free to open an issue.

## About

Need to fill this in a bit more at some point.

## Contributing

TODO - info on how to make suggestions

- baserow form
- github issues
- patreon posts

## Website details (mostly for Kevin)

### Xranklin modifications

- Started from the basic template: https://tlienart.github.io/FranklinTemplates.jl/templates/basic/index.html
- Changed a few variables in xml feeds, used https://podba.se/validate/ to test
  - mostly hard-coded stuff - the fd2rss functions are mostly not needed now
  - [in `head.xml`](https://github.com/kescobo/audiommunity.org/compare/b968b9b..dd2b1c2#diff-2f366e7e770907053622bb6f80e88ecd11f3fe32f5c412aad4c3c2da0c823831),
    added some namespaces, and some itunes and podcast-specific tags
  - [in `item.xml`](https://github.com/kescobo/audiommunity.org/compare/b968b9b..dd2b1c2#diff-441b1ff7c85b808fd8b2b346d50f73045586ebe58a35b4a6a1bfe60522dd7884),
    updated the `enclosure` to add a type and length (hard-coded for now - need to fix that)

### Podcast GUIDs

#### `<podcast:guid>`

[See here](https://github.com/Podcast-Standards-Project/PSP-1-Podcast-RSS-Specification?tab=readme-ov-file#podcastguid)

```julia-repl
julia> u4 = UUID("ead4c236-bf58-58c6-a2c6-a6b28d128cb6"); # "podcast" namespace

julia> audommunity_guid = uuid5(u4, "audiommunity.org/feed")
UUID("389e74b1-be77-567e-b7b8-98eacec29284")
```

#### Episode-specific `guid`

Eg. `<guid isPermaLink="false">episodes/episode034/index.html</guid>`

### Other issues

Keeping track at https://github.com/kescobo/audiommunity.org/issues

## Parsing old episodes

```sh
curl \
-X GET \
-H "Authorization: Token $BASEROW_TOAKEN" \
"https://api.baserow.io/api/database/rows/table/422731/?user_field_names=true" > repo.json
```

```julia
using JSON3
using Dates

resp = JSON3.read("resp.json")[:results]

for ep in resp
    num = ep[Symbol("Episode number")]
    parse(Int, num) in 1:32 || continue
    ep[:Type][:value] == "Main episode" || continue
    date = get(ep, Symbol("Release date"), "2000-01-01")

    content = """
    +++
    using Dates
    title = "$(ep[:Title])"
    season = 1
    episode = $num
    date = Date("$date")
    tags = ["archive"]
    rss_descr = ""
    rss_title = title
    rss_enclosure = ""
    rss_pubdate = date
    episode_length = ""
    itunes_duration = ""
    +++

    """ * ep[:Description]

    content = replace(content,
        r"\[(.+?)\]\(http://static1.+?\)"=> s"\1"
    )

    open(io-> println(io, content), "episodes/episode$(lpad(num, 3, "0")).md", "w")
end
```

## Filling in enclodures, episode length, and itunes duration for season 1

```julia
for ep in readdir("episodes"; join=true)
    lines = readlines(ep)
    encl_ln = findfirst(line -> startswith(line, "rss_enclosure"), lines)
    eplen_ln = findfirst(line -> startswith(line, "episode_length"), lines)
    itdur_ln = findfirst(line -> startswith(line, "itunes_duration"), lines)
    epnum_ln = findfirst(line -> startswith(line, "episode"), lines)
    epnum = parse(Int, match(r"episode ?= ?(\d+)", lines[epnum_ln])[1])
    epfile = joinpath("/home/kevin/Audio/Season 1/disclaimers/", "audiommunity_ep$(lpad(epnum, 3, '0'))_disclaimer.mp3")

    @info "Checking episode $epnum"
    if !isfile(epfile)
        @warn "disclaimer file not found, skipping"
        continue
    end

    if lines[encl_ln] == "rss_enclosure = \"\""
        lines[encl_ln] = "rss_enclosure = \"https://archive.org/download/audiommunity_season1/$(basename(epfile))\""
    else
        @warn "enclusure line already exists: `$(lines[encl_ln])`"
    end

    if lines[eplen_ln] == "episode_length = \"\""
        lines[eplen_ln] = "episode_length = \"$(filesize(epfile))\""
    else
        @warn "episode_length already exists: $(lines[eplen_ln])"
    end

    if lines[itdur_ln] == "itunes_duration = \"\""
        dur = let io = IOBuffer()
            run(pipeline(`soxi -D $epfile`; stdout=io))
            seek(io, 0)
            round(Int, parse(Float64, first(readlines(io))))
        end
        lines[itdur_ln] = "itunes_duration = \"$(dur)\""
    else
        @warn "itunes_duration already exists: `$(lines[itdur_ln])`"
    end

    open(ep, "w") do io
        println.(io, lines)
    end
end
```
