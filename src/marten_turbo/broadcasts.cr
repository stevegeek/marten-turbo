module MartenTurbo
  # Module-level helpers for pushing turbo-stream actions over the Cable
  # transport. Mirrors turbo-rails' `Turbo::StreamsChannel.broadcast_*`
  # API.
  #
  # Usage:
  #
  #     MartenTurbo.broadcast_append_to "messages",
  #       target:  "messages",
  #       partial: "messages/_message.html",
  #       locals:  {"message" => message}
  #
  # Subscribers (via `{% turbo_stream_from "messages" %}` in a template)
  # receive the rendered `<turbo-stream action="append" target="messages">`
  # over their open WebSocket and Turbo's JS applies it to the DOM.

  # L13: iterate `TurboStream::ACTIONS` directly (minus `"refresh"`, whose
  # no-target shape is special-cased below) so the action set stays in
  # lockstep with the runtime whitelist. Adding a new action to
  # `TurboStream::ACTIONS` immediately exposes a matching
  # `broadcast_<action>_to` helper without a manual edit here.
  {% for action in MartenTurbo::TurboStream::ACTIONS.reject { |action_name| action_name == "refresh" } %}
    def self.broadcast_{{ action.id }}_to(
      stream : String,
      target : String | Marten::Model | Nil = nil,
      partial : String? = nil,
      locals : Hash | NamedTuple | Nil = nil,
      content : String? = nil,
    )
      if target.nil?
        raise ArgumentError.new("broadcast_{{ action.id }}_to requires a target")
      end

      body = if partial
               render_partial(partial, locals)
             else
               content
             end

      markup = MartenTurbo::TurboStream.action({{ action }}, target, body).to_s
      safe_publish(stream, markup, action_name: {{ action }})
    end
  {% end %}

  # Send a `refresh` action to all subscribers — instructs the page
  # to re-fetch and morph itself. No target / no body.
  def self.broadcast_refresh_to(stream : String)
    markup = MartenTurbo::TurboStream.refresh.to_s
    safe_publish(stream, markup, action_name: "refresh")
  end

  # L7: `Cable.server.publish` runs synchronously inside `after_*_commit`,
  # so a backend hiccup (Redis timeout, dropped connection, …) used to
  # propagate as an exception from the host's `create!`/`save!`. The cable
  # backend abstract `publish_message`
  # (`lib/cable/src/cable/backend_core.cr:17`) has no documented exception
  # contract — Redis-backed implementations raise `IO::Error` /
  # `Socket::ConnectError` / generic `Exception` — so this catches the
  # broad `Exception` class, logs once via `Marten::Log.error`, and
  # continues. The host's create must not fail because a broadcast
  # subscriber transport blipped; subscribers will just miss this
  # message.
  private def self.safe_publish(stream : String, markup : String, action_name : String) : Nil
    ::Cable.server.publish(stream, markup)
  rescue ex : Exception
    ::Marten::Log.error(exception: ex) do
      "MartenTurbo broadcast failed (action=#{action_name} stream=#{stream.inspect}): #{ex.message}"
    end
    nil
  end

  private def self.render_partial(name : String, locals : Hash | NamedTuple?) : String
    template = Marten.templates.get_template(name)
    values = {} of String => Marten::Template::Value

    case locals
    when Hash
      locals.each { |k, v| values[k.to_s] = Marten::Template::Value.from(v) }
    when NamedTuple
      locals.each { |k, v| values[k.to_s] = Marten::Template::Value.from(v) }
    end

    context = Marten::Template::Context.new(values)
    template.render(context)
  end
end
