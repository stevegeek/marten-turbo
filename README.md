<h1>
  <img src="https://raw.githubusercontent.com/treagod/marten-turbo/e317fa4c759ebb61a335d22872a39caf39cfe5cc/docs/_media/logo.svg" height="32" width="32" alt="Marten Turbo Logo">
  <span>Marten Turbo</span>
</h1>

[![Marten Turbo Specs](https://github.com/stevegeek/marten-turbo/actions/workflows/specs.yml/badge.svg)](https://github.com/stevegeek/marten-turbo/actions/workflows/specs.yml)
[![QA](https://github.com/stevegeek/marten-turbo/actions/workflows/qa.yml/badge.svg)](https://github.com/stevegeek/marten-turbo/actions/workflows/qa.yml)

Marten Turbo provides helpers to interact with [Turbo](https://turbo.hotwired.dev/) applications using the [Marten Framework](https://martenframework.com/).

This is a fork of [treagod/marten-turbo](https://github.com/treagod/marten-turbo) with the following additions:

- **Turbo 8 `refresh` action** — `{% turbo_stream "refresh" %}` and `MartenTurbo::TurboStream.refresh`.
- **`{% turbo_refreshes_with %}`** template tag for the page-morph + scroll meta tags.
- **`partial:`** (alias for `template:`) and **`locals: {…}`** kwargs on the `{% turbo_stream %}` tag.
- **Real-time over WebSockets** — `{% turbo_stream_from %}`, `MartenTurbo::Broadcastable` model concern, and `MartenTurbo.broadcast_*_to` helpers backed by the [`marten-cable`](https://github.com/stevegeek/marten-cable) shard. Mirrors `turbo-rails`'s `Turbo::Broadcastable` + `turbo_stream_from`.

## Installation

Add the following entries to your project's `shard.yml`:

```yaml
dependencies:
  marten_turbo:
    github: stevegeek/marten-turbo
```

And run `shards install` afterward.

`marten_turbo` depends on [`marten-cable`](https://github.com/stevegeek/marten-cable) (which itself wraps [`cable-cr/cable`](https://github.com/cable-cr/cable)) — the WebSocket transport is pulled in transitively.

Add the following requirement to your project's `src/project.cr` file:

```crystal
require "marten_turbo"
```

Afterwards you can use the template helpers and the turbo handlers.

## Tags

### `dom_id`

Generates Turbo-frame-style ids for Marten models.

```html
{% for article in articles %}
  <div id="{% dom_id article %}"> <!-- article_1, article_2, etc. -->
    <!-- some content -->
  </div>
{% endfor %}

<form id="{% dom_id article %}" method="POST" action="/articles">
  <!-- new instance => new_article ; persisted => article_1 etc. -->
</form>
```

Identifiers respect the model's namespace — an `Article` model under the `blogging` app gives `blogging_article_1`.

### `turbo_stream`

Build `<turbo-stream>` markup inline.

```html
{% turbo_stream 'append' "articles" do %}
  <div class="{% dom_id article %}">
    {{ article.name }}
  </div>
{% end_turbo_stream %}

<!--
  <turbo-stream action="append" target="articles">
    <template>
      <div class="article_1">My First Article</div>
    </template>
  </turbo-stream>
-->
```

Inline forms with `partial:` and `locals:`:

```html
{% turbo_stream 'replace' "articles" partial: "articles/_article.html" locals: {article: article} %}
```

`partial:` is an alias for `template:` matching turbo-rails' helper. `locals:` injects values into the partial's render context (without polluting the outer template context).

`dom_id` is auto-applied when the target is a model:

```html
{% turbo_stream 'remove' article %}
<!-- <turbo-stream action="remove" target="article_1"></turbo-stream> -->
```

### `turbo_stream "refresh"`  *(Turbo 8)*

The action-only no-target form. Tells the page to re-fetch and morph itself.

```html
{% turbo_stream "refresh" %}
<!-- <turbo-stream action="refresh"></turbo-stream> -->
```

### `turbo_refreshes_with`  *(Turbo 8)*

Emits the `<meta name="turbo-refresh-method">` and `<meta name="turbo-refresh-scroll">` pair in your layout.

```html
{% turbo_refreshes_with method: "morph", scroll: "preserve" %}
```

Empty output when both args resolve to defaults so it doesn't litter pages.

### `turbo_stream_from`

Subscribe a page to a real-time broadcast stream. Pairs with `MartenTurbo.broadcast_*_to` (below) and the `MartenTurbo::Broadcastable` model concern.

```html
{% turbo_stream_from "articles" %}     <!-- string stream name -->
{% turbo_stream_from @room %}          <!-- Marten::Model — uses @room.cable_stream_name -->
```

Renders a `<turbo-cable-stream-source>` custom element with an HMAC-signed stream name. The signature is verified server-side on subscribe so a hostile client can't subscribe to arbitrary streams just by guessing names.

> **Note**: `<turbo-cable-stream-source>` is shipped with `@hotwired/turbo-rails`'s npm package, *not* with `@hotwired/turbo` itself. If your app uses just `@hotwired/turbo`, define an equivalent custom element (≈ 20 lines using `@rails/actioncable` + `Turbo.connectStreamSource`).

## Real-time broadcasts

Once a page subscribes via `{% turbo_stream_from %}`, broadcasts to that stream from server code reach all subscribers over the open Cable WebSocket. The wire format is plain `<turbo-stream>` markup, so Turbo's bundled JS applies the action directly to the DOM.

### Module-level helpers

```crystal
MartenTurbo.broadcast_append_to "articles",
  target:  "articles",
  partial: "articles/_article.html",
  locals:  {"article" => article}

MartenTurbo.broadcast_replace_to "articles",
  target:  "article_42",
  partial: "articles/_article.html",
  locals:  {"article" => article}

MartenTurbo.broadcast_remove_to "articles", target: "article_42"
MartenTurbo.broadcast_refresh_to "articles"
```

The full set: `broadcast_{append,prepend,replace,update,remove,before,after,refresh}_to`. Each renders the partial through Marten's template engine, wraps it in a `<turbo-stream action="…">` element, and publishes via Cable.

### `MartenTurbo::Broadcastable` mixin

Wires after-commit callbacks on a Marten model so that record changes auto-broadcast. Mirrors `Turbo::Broadcastable` from turbo-rails.

```crystal
class Message < Marten::Model
  include MartenTurbo::Broadcastable

  field :id, :big_int, primary_key: true, auto: true
  field :body, :text
  field :room, :many_to_one, to: Room, related: :messages

  broadcasts_to :room
end
```

That single `broadcasts_to :room` line wires three callbacks:

| Callback | Stream output |
|---|---|
| `after_create_commit` | `<turbo-stream action="append" target="messages">` |
| `after_update_commit` | `<turbo-stream action="replace" target="message_<pk>">` |
| `after_delete_commit` | `<turbo-stream action="remove" target="message_<pk>">` |

Defaults derived from the model class name (`Message` → `messages` container, `message_<pk>` element id, `messages/_message.html` partial, `message` locals key). Override per-call:

```crystal
broadcasts_to :room,
  partial:   "rooms/_chat_message.html",
  container: "chat_log",
  member:    "chat_message"
```

For a static stream name, just pass a string:

```crystal
broadcasts_to "messages"
```

> **Note vs Rails**: turbo-rails auto-includes `Broadcastable` into every `ActiveRecord::Base` via `ActiveSupport.on_load`. Crystal has no equivalent hook, so each Marten model has to `include MartenTurbo::Broadcastable` explicitly.

### Setup

You need to mount the Cable transport in your Marten app — see [marten-cable](https://github.com/stevegeek/marten-cable) for details. Briefly:

```crystal
# src/channels/application_cable/connection.cr
module ApplicationCable
  class Connection < Cable::Connection
    identified_by :identifier

    def connect
      self.identifier = "anon"   # or read from session — see marten-cable docs
    end
  end
end

# src/project.cr  (after model + channel files load)
MartenCable.use(ApplicationCable::Connection)
```

## Handlers

Marten Turbo provides extensions to the generic Marten handlers:

**Record creation:**

```crystal
class ArticleCreateHandler < MartenTurbo::Handlers::RecordCreate
  model Article
  schema ArticleSchema
  template_name "articles/create.html"
  turbo_stream_name "articles/create.turbo_stream.html"
  success_route_name "articles"
end
```

The `#turbo_stream_name` class method picks a turbo-stream template that is rendered instead of the normal template when the request is a Turbo request.

**Record update:**

```crystal
class ArticleUpdateHandler < MartenTurbo::Handlers::RecordUpdate
  model Article
  schema ArticleSchema
  template_name "articles/update.html"
  turbo_stream_name "articles/update.turbo_stream.html"
  success_route_name "articles"
end
```

**Record deletion** — define a `turbo_stream` method that returns the markup:

```crystal
class ArticleDeleteHandler < MartenTurbo::Handlers::RecordDelete
  model Article
  template_name "articles/delete.html"
  success_route_name "articles"

  def turbo_stream
    MartenTurbo::TurboStream.remove(record)
  end
end
```

## Turbo Native

Marten Turbo lets you check if a request is from a Turbo Native application via `request.turbo_native_app?`.

A context producer also adds a `turbo_native?` variable to your templates so you can adjust your HTML accordingly. To enable it, add `MartenTurbo::Template::ContextProducer::TurboNative` to [your context producer array](https://martenframework.com/docs/templates/introduction#using-context-producers).

```html
<body {% if turbo_native? %}class="turbo-native"{% endif %}>
  …
</body>
```
