# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Audiommunity.org is a podcast website built with Xranklin.jl, a Julia-based static site generator. The site hosts "Audiommunity", a podcast about our bodies' never-ending fight with the outside world, focusing on immunology, neuroscience, and related topics.

## Architecture

The site follows Xranklin.jl conventions:

- **Content**: Episodes are markdown files in `episodes/` with YAML frontmatter containing metadata like episode number, date, tags, RSS info
- **Templates**: HTML layouts in `_layout/` handle page structure (header, footer, etc.)
- **Assets**: Static files in `_assets/` (CSS, images, audio files)
- **Utilities**: Julia functions in `utils.jl` for custom HTML generation and episode listing
- **Configuration**: Site settings in `config.jl`
- **Generated site**: Output in `__site/` (do not edit directly)

### Key Files

- `utils.jl`: Contains helper functions for episode listing, audio embedding, and tag display
- `config.jl`: Website configuration including RSS settings
- `episodes/`: Individual episode markdown files with metadata
- `_layout/`: HTML templates for page structure
- `_css/`: Stylesheets for site appearance

## Development Commands

### Build and Serve Site
```julia
using Xranklin
serve()  # Start development server with live reload
```

### Static Site Generation
```julia
using Xranklin
optimize()  # Generate optimized static site in __site/
```

### Julia Package Management
```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'  # Install dependencies
```

## Content Management

### Adding New Episodes

1. Create new markdown file: `episodes/episodeXXX.md`
2. Include required frontmatter:
```yaml
+++
using Dates
title = "Episode Title"
season = 1
episode = XXX
date = Date("YYYY-MM-DD")
tags = ["tag1", "tag2"]
rss_descr = "Episode description"
rss_title = title
rss_enclosure = "https://archive.org/download/path/to/audio.mp3"
rss_pubdate = date
episode_length = "file_size_in_bytes"
itunes_duration = "duration_in_seconds"
+++
```

### Episode Structure

Episodes use a consistent format with:
- Frontmatter metadata for RSS feed generation
- Audio embedding via `{{embed_audio}}` function
- Automatic episode listing on main page

### Tags and Organization

The site uses a tagging system for categorizing episodes by topic (immunology, neuroscience, careers, etc.). Tags generate automatic index pages.

## RSS Feed

The site generates podcast RSS feeds automatically using episode metadata. Important RSS fields:
- `rss_enclosure`: Direct link to audio file
- `episode_length`: File size in bytes
- `itunes_duration`: Duration in seconds
- Podcast GUID: `389e74b1-be77-567e-b7b8-98eacec29284`

## File Organization

- Never edit files in `__site/` or `__cache/` (auto-generated)
- Audio files hosted externally (Archive.org)
- Episode content in markdown with Julia function calls for dynamic content
- CSS customizations in `_css/` directory

## Julia Development Guidelines

### HTML Generation in utils.jl

Always use the `node()` function (from Hyperscript.jl) for generating HTML in Julia functions:

```julia
# Correct approach using node()
function hfun_example()
    return string(
        node("div", class="container",
            node("h3", "Title"),
            node("p", "Description")
        )
    )
end

# Avoid raw HTML strings
function hfun_example()
    return """
    <div class="container">
        <h3>Title</h3>
        <p>Description</p>
    </div>
    """
end
```

### Error Handling

Do not use try/catch blocks in Julia code for this project. Instead, use defensive programming with conditional checks and default values:

```julia
# Correct approach
function hfun_example()
    duration = getlvar(:itunes_duration, "")
    if !isempty(duration) && occursin(r"^\d+$", duration)
        # Process duration
    else
        # Handle missing/invalid duration
    end
end

# Avoid try/catch
function hfun_example()
    try
        duration = parse(Int, getlvar(:itunes_duration))
    catch
        duration = 0
    end
end
```

### Code Organization and Reusability

The `utils.jl` file is organized into logical sections to maintain clean, reusable code:

- **Shared Utility Functions**: Core helpers used across multiple functions
- **Tag System Functions**: Tag display and management
- **Episode Management Functions**: All episode-related functionality  
- **Media Embedding Functions**: Audio and YouTube embedding
- **People/About Page Functions**: Profile and about page features
- **RSS/Feed Utility Functions**: Feed generation helpers

#### Avoiding Code Duplication

**ALWAYS** check for existing utility functions before creating new ones. Common patterns that should be reused:

- **Date formatting**: Use `format_date_display(date)` instead of inline `Dates.format()`
- **Duration formatting**: Use `format_duration_from_seconds(duration_str)` for time display
- **YouTube processing**: Use `extract_youtube_video_id()` and `create_youtube_embed_node()`
- **File operations**: Use `collect_markdown_files()` and `extract_markdown_content()`
- **Episode paths**: Use `get_episode_file_path(number)` for consistent file naming

#### Before Adding New Functions

1. Check if similar functionality already exists in utility functions
2. If adding episode or people-related functionality, use existing `get_episodes()` or `get_people()` functions
3. Extract reusable logic into shared utility functions rather than duplicating code
4. Add comprehensive docstrings with proper Julia type annotations (`::Type` not `-> Type`)

### Code Formatting

- Do not add spaces on blank lines within functions
- Keep function structure clean and consistent
- Use meaningful variable names that match the domain (episodes, tags, metadata)

### Common Patterns

- Use `getlvar()` and `getvarfrom()` for accessing page/episode metadata
- Use `get_episodes()` function for retrieving episode lists
- Format dates with `format_date_display(date)` helper function
- Use CSS classes that match existing patterns in `_css/basic.css`