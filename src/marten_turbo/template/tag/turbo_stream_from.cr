module MartenTurbo
  module Template
    module Tag
      # `{% turbo_stream_from name %}` — emits a `<turbo-cable-stream-source>`
      # custom element which (on the client) subscribes to
      # MartenTurbo::StreamsChannel over the open Cable WebSocket so
      # broadcasts to the named stream reach the page.
      #
      # `name` may be a String literal/variable or a Marten::Model
      # instance — models are resolved through `MartenTurbo.stream_name`
      # to their `cable_stream_name`, so `{% turbo_stream_from @room %}`
      # matches `broadcasts_to :room` on a Message model automatically.
      #
      # The stream name is HMAC-signed at render time; the channel
      # verifies on subscribe so clients can't subscribe to arbitrary
      # streams just by guessing names.
      #
      # `scope:` binds the signature to a particular Cable connection identity
      # (matching `connection.identifier`). With `scope:` set, a leaked
      # `signed-stream-name` from one user can't be replayed by a different
      # Cable-authenticated client. **Recommended for any per-user stream** —
      # pass the same string the host app sets via
      # `identified_by` / `self.identifier =` in its `Cable::Connection`. Omitting
      # `scope:` is a backward-compat *transition state* and is insecure for
      # per-user streams.
      #
      # ```html
      # {% turbo_stream_from @room scope: current_user_identifier %}
      # ```
      class TurboStreamFrom < Marten::Template::Tag::Base
        include Marten::Template::Tag::CanSplitSmartly
        include Marten::Template::Tag::CanExtractKwargs

        @stream_filter : Marten::Template::FilterExpression
        @scope_filter : Marten::Template::FilterExpression?

        def initialize(parser : Marten::Template::Parser, source : String)
          parts = split_smartly(source)
          if parts.size < 2
            raise Marten::Template::Errors::InvalidSyntax.new(
              "Malformed turbo_stream_from tag: expected the stream name as the first argument"
            )
          end
          @stream_filter = Marten::Template::FilterExpression.new(parts[1])

          @scope_filter = nil
          if parts.size > 2
            extract_kwargs(parts[2..].join(' ')).each do |key, value|
              case key
              when "scope"
                @scope_filter = Marten::Template::FilterExpression.new(value)
              else
                raise Marten::Template::Errors::InvalidSyntax.new(
                  "Malformed turbo_stream_from tag: unknown kwarg #{key.inspect}"
                )
              end
            end
          end
        end

        def render(context : Marten::Template::Context) : String
          raw = @stream_filter.resolve(context).raw
          stream_name = MartenTurbo.stream_name(raw)
          scope = @scope_filter.try(&.resolve(context).to_s) || ""
          signed = MartenTurbo::Verifier.sign(stream_name, scope: scope)
          %(<turbo-cable-stream-source channel="MartenTurbo::StreamsChannel" ) +
            %(signed-stream-name="#{signed}"></turbo-cable-stream-source>)
        end
      end
    end
  end
end
