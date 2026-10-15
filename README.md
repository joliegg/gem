# joliegg

Jolie's Ruby toolkit. 

## Installation

```ruby
# Until the gem is published, point Bundler at a checkout:
gem "joliegg", git: "https://github.com/joliegg/gem.git"
# or a local path:
gem "joliegg", path: "../joliegg"
```

## Usage

Every check accepts a full URL, a bare domain, or an email address — the input
is reduced to its host, then **every domain suffix** is matched, so a listed
`example.com` also blocks `sub.example.com` and `user@example.com`:

```ruby
require "joliegg"

Jolie::Moderation::UrlBlocklist.blocked?("https://spam.0-mail.com/signup") # => true
Jolie::Moderation::UrlBlocklist.blocked?("someone@mailinator.com")         # => true
Jolie::Moderation::UrlBlocklist.blocked?("example.com")                    # => false
Jolie::Moderation::UrlBlocklist.match("someone@mailinator.com")            # => "mailinator.com"

Jolie::Moderation::UrlBlocklist.shortener?("bit.ly")        # => true
Jolie::Moderation::UrlBlocklist.shortener?("links.bit.ly")  # => true (suffix-matched)

Jolie::Moderation.moderate_link("https://mailinator.com").categories # => ["BLACK_LIST"]
Jolie::Moderation.moderate_link("https://bit.ly/x").categories       # => ["URL_SHORTENER"]
Jolie::Moderation.link_blocked?("https://bit.ly/x", allow_shorteners: true) # => false
```

## Syncing the data

The JSON files are copied verbatim from the TypeScript package. To refresh them
from a local checkout of that repo:

```bash
rake "data:sync[/path/to/moderation]"
```

## Development

```bash
bundle install
bundle exec rake spec      # tests
bundle exec standardrb     # lint
```

## License

Hippocratic License HL3-CL — see [LICENSE.md](LICENSE.md). Same license as the
TypeScript package whose data this gem distributes.
