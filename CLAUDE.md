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