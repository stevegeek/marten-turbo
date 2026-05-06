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

  {% for action in %w[append prepend replace update remove before after] %}
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
      ::Cable.server.publish(stream, markup)
    end
  {% end %}

  # Send a `refresh` action to all subscribers — instructs the page
  # to re-fetch and morph itself. No target / no body.
  def self.broadcast_refresh_to(stream : String)
    markup = MartenTurbo::TurboStream.refresh.to_s
    ::Cable.server.publish(stream, markup)
  end

  private def self.render_partial(name : String, locals : Hash | NamedTuple | Nil) : String
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
