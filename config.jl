author = "Audiommunity.org"
mintoclevel = 2

# uncomment and adjust the following line if the expected base URL of your website is something like [www.thebase.com/yourproject/]
# please do read the docs on deployment to avoid common issues: https://franklinjl.org/workflow/deploy/#deploying_your_website
# prepath = "yourproject"

# Add here files or directories that should be ignored by Franklin, otherwise
# these files might be copied and, if markdown, processed by Franklin which
# you might not want. Indicate directories by ending the name with a `/`.
# Base files such as LICENSE.md and README.md are ignored by default.
ignore = ["node_modules/", ]


website_title = "Audiommunity.org"
website_descr = "A podcast about our bodies' never-ending fight with the outside world"
website_url   = "http://audiommunity.org"


# RSS (the website_{title, descr, url} must be defined to get RSS)
generate_rss = true
rss_website_url = website_url
rss_website_title = website_title
rss_website_descr = website_descr
rss_link        = "/feed"

