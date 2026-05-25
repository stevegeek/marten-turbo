require "html"

module MartenTurbo
  # Raised when an action that is not part of `MartenTurbo::TurboStream::ACTIONS`
  # is passed to `TurboStream#action`. The whitelist exists to keep arbitrary
  # strings out of the `action="…"` attribute — an unknown action with a `"` in
  # it would otherwise inject HTML into the rendered `<turbo-stream>` element.
  class InvalidActionError < ArgumentError
  end

  class TurboStream
    include Identifiable

    # The canonical set of Turbo Stream actions shipped with this shard.
    #
    # `broadcasts.cr` iterates this constant at *macro-expansion* time to
    # generate the `broadcast_<action>_to` convenience helpers — that's a
    # compile-time loop and cannot see host-registered actions.
    # `TurboStream#action` (and therefore the `{% turbo_stream %}` template
    # tag) consults the runtime `action_allowed?` predicate instead, so
    # host-registered actions can be invoked through the generic
    # `MartenTurbo::TurboStream.action(name, target, content)` entry point.
    ACTIONS = %w[append prepend replace update remove before after refresh]

    # TR3: runtime extension point. `register_action` lets a host opt in to a
    # custom Turbo Stream action name (Turbo morph extensions, third-party
    # custom elements, etc.) without monkey-patching the constant. The
    # whitelist still applies — `action_allowed?` is the single source of
    # truth consulted by `#action`.
    @@registered_actions : Set(String) = ACTIONS.to_set

    # Registers an additional Turbo Stream action name so that
    # `MartenTurbo::TurboStream.action(name, …)` (and the `{% turbo_stream %}`
    # template tag) will accept it. Idempotent — re-registering an existing
    # name is a no-op.
    #
    # Example:
    #
    # ```
    # # config/initializers/marten_turbo.cr
    # MartenTurbo::TurboStream.register_action("morph")
    # ```
    #
    # Note: only the generic entry points respect host-registered actions.
    # The macro-generated `broadcast_<action>_to` and `TurboStream#<action>`
    # convenience methods iterate the compile-time `ACTIONS` constant and
    # therefore can't be extended at runtime. Hosts invoke their custom
    # actions through `MartenTurbo::TurboStream.action("morph", target,
    # content)` or via `MartenTurbo.broadcast_action_to(stream, "morph", …)`
    # (if you add a host-side wrapper).
    def self.register_action(name : String) : Nil
      @@registered_actions.add(name)
      nil
    end

    # Returns the current set of registered actions (built-in + host-added).
    def self.actions : Set(String)
      @@registered_actions
    end

    # Predicate consulted by `#action` and the template-tag runtime to gate
    # action names.
    def self.action_allowed?(name : String) : Bool
      @@registered_actions.includes?(name)
    end

    # Test-only helper: resets the registered-actions set back to the eight
    # built-ins. Hosts must not call this in production code — it's intended
    # for spec isolation when one spec registers an action and a later one
    # depends on the default-only behaviour.
    def self.reset_actions_for_spec!
      @@registered_actions = ACTIONS.to_set
      nil
    end

    def initialize
      @streams = [] of String
    end

    def self.new(&)
      with new yield
    end

    # Creates a new TurboStream instance and adds a single action.
    #
    # ```
    # stream = MartenTurbo::TurboStream.action("append", "messages", "<div>New Message</div>")
    # ```
    def self.action(action, target_id, content)
      new.action(action, target_id, content)
    end

    # Creates a new TurboStream instance and adds a single action.
    #
    # ```
    # stream = MartenTurbo::TurboStream.new
    # stream.action("append", "messages", "<div>New Message</div>")
    # ```
    #
    # The `"refresh"` action is special-cased: it produces a `<turbo-stream
    # action="refresh"></turbo-stream>` element with no `target` attribute and
    # no `<template>` body, regardless of the values passed for `target` and
    # `content`.
    #
    # Raises `MartenTurbo::InvalidActionError` if `action` is not one of the
    # well-known Turbo Stream actions in `ACTIONS`.
    def action(action, target : String | Marten::Model, content)
      action_str = action.to_s

      # TR3: consult the runtime whitelist (includes host-registered actions
      # via `register_action`) rather than the compile-time `ACTIONS`
      # constant.
      unless MartenTurbo::TurboStream.action_allowed?(action_str)
        raise MartenTurbo::InvalidActionError.new(
          "Unknown Turbo Stream action: #{action_str.inspect}. " \
          "Expected one of: #{MartenTurbo::TurboStream.actions.to_a.join(", ")}."
        )
      end

      # L2: refresh is special-cased — no target, no body — so delegate to
      # `#refresh` which holds the single source of truth for the rendered
      # markup. `target` and `content` are intentionally ignored for this
      # action (matches turbo-rails).
      return refresh if action_str == "refresh"

      target_id = target.is_a?(String) ? target : dom_id(target.as(Marten::Model))
      # H4: HTML-escape the target id before interpolating it into the
      # `target="…"` attribute. `action_str` itself is whitelisted via
      # `ACTIONS` above, so it does not need escaping (the whitelist is the
      # stronger guarantee — none of the allowed actions contain HTML-
      # significant characters).
      escaped_target = HTML.escape(target_id)

      # Phase 2 M5: build the element via `String.build` instead of an
      # indented heredoc, so leading whitespace doesn't leak into the
      # `<template>` body — visible if the partial includes `<pre>` content.
      # Matches turbo-rails' single-line emission.
      @streams << String.build do |io|
        io << %(<turbo-stream action=") << action_str
        io << %(" target=") << escaped_target << %(">)
        template = render_template_tag(content)
        io << template unless template.empty?
        io << "</turbo-stream>"
      end

      self
    end

    # Creates a new TurboStream instance and adds a single action.
    #
    # ```
    # stream = MartenTurbo::TurboStream.new
    # stream.replace("append", Message.get!(pk: 1), "<div>Updated Message</div>")
    # ```
    def action(action, target : Marten::Model, content)
      action(action, dom_id(target), content)
    end

    {% for action in ACTIONS %}
      {% if action != "refresh" %}
        # Adds a turbo stream {{ action.id }} action to the streams array.
        def {{ action.id }}(target, content : String? = nil)
          action("{{ action.id }}", target, content)

          self
        end

        # Creates a a turbo stream instance with a {{ action.id }} action
        # already in its array.
        def self.{{ action.id }}(target, content : String? = nil)
          self.new.action("{{ action.id }}", target, content)
        end
      {% end %}
    {% end %}

    # Adds a turbo stream `refresh` action to the streams array.
    #
    # The `refresh` action (introduced in Turbo 8) takes no target and no
    # content: it instructs the client to re-fetch the current page so that
    # the response can be morphed into the existing DOM.
    def refresh
      @streams << %(<turbo-stream action="refresh"></turbo-stream>)

      self
    end

    # Creates a new TurboStream instance with a single `refresh` action.
    def self.refresh
      new.refresh
    end

    # L3: both forms join streams with `\n` and emit *no* trailing newline.
    # Previously `to_s(io)` emitted `<stream>\n` per element (trailing newline)
    # while `to_s` joined without — diffing IO output against the string form
    # disagreed by exactly one `\n`. Aligned to the no-trailing-newline form,
    # which matches turbo-rails' wire output and the existing spec
    # expectations.
    def to_s
      @streams.join("\n")
    end

    def to_s(io : IO)
      @streams.join(io, "\n")
    end

    # Phase 2 M5: emit `<template>…</template>` without leading indentation
    # so that a partial containing `<pre>` content (where whitespace is
    # visible) does not accumulate the heredoc's indentation. Matches
    # turbo-rails' compact single-element emission.
    private def render_template_tag(content)
      return "" unless content

      "<template>#{content}</template>"
    end
  end
end
