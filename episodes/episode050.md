+++
using Dates
title = "Kevin has learned a tautology"
season = 2
episode = 50
date = DateTime(2025, 12, 10, 12, 0, 0)
tags = [
    "neuroinflammation",
    "alzheimers",
    "prions",
    "APOE",
    "microglia",
    "protein folding",
    "statistics"
]
rss_descr = """
In this episode, Matt and Kevin stick with the brain,
this time looking at the immunological implications of
a variant of a gene called Apolipoprotein E
that has been linked to Alzheimer's and other neurodegenerative diseases.

It's a long one, and we get snarky in this one folks!
Buckle up!
"""
rss_title = title
rss_pubdate = date
youtube = "https://youtu.be/FSEVhQByxyg"
rss_enclosure = "https://archive.org/download/audiommunity_episode050/audiommunity_episode050.mp3"
episode_length = "160600563"
itunes_duration = "7496"
+++

In this episode, Matt and Kevin stick with the brain,
this time looking at the immunological implications of
a variant of a gene called Apolipoprotein E
that has been linked to Alzheimer's and other neurodegenerative diseases.

It's a long one, and we get snarky in this one folks!
Buckle up!

### Creating random vectors

In this episode, we spend a fair amount of time
talking about the statistical implications of these methods,
and Kevin says things like

> if I generated a bunch of random vectors,
> we would still see the same thing.

But is that really true? Kevin wrote some code to find out!
You can find the link to the actual code below if that's your jam,
but to give a brief summary, Kevin

1. Generated a dataset with approximately the same proportion
   of APOE genotypes and neurodegeneration pattern as the authors have in table S1
2. Generated a bunch of random values drawn from a normal distribution
   to match the number of proteins found in the SomaScan screen
3. Performed a mutual information screen and PCA as described in the paper
4. Generated a couple of random lists of proteins to test the GSEA
   analysis described in the paper.

Here's what he saw:

![]("/assets/pcas.png")

So it's not *literally* true that completely random data
will segregate based on this analysis - mea culpa.
But if you add even a tiny bit of underlying correlation structure
(some directional noise on 1% of samples),
we see the following:

![]("/assets/pcas_add.png")

Which is much closer to what it looks like in the paper.
We discuss these results and the code
at around minute 68, and the link to the code is below.

## Links

- [The Paper - APOE ε4 carriers share immune-related proteomic changes across neurodegenerative diseases](https://doi.org/10.1038/s41591-025-03835-z)
- [Wikipedia on prion disease](https://en.wikipedia.org/wiki/Prion)
- [Code to replicate Kevin's random number generation](https://github.com/kescobo/audiommunity.org/tree/main/apoe)


