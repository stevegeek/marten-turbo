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
      class TurboStreamFrom < Marten::Template::Tag::Base
        include Marten::Template::Tag::CanSplitSmartly

        @stream_filter : Marten::Template::FilterExpression

        def initialize(parser : Marten::Template::Parser, source : String)
          parts = split_smartly(source)
          if parts.size != 2
            raise Marten::Template::Errors::InvalidSyntax.new(
              "Malformed turbo_stream_from tag: expected exactly one argument (the stream name)"
            )
          end
          @stream_filter = Marten::Template::FilterExpression.new(parts[1])
        end

        def render(context : Marten::Template::Context) : String
          raw = @stream_filter.resolve(context).raw
          stream_name = MartenTurbo.stream_name(raw)
          signed = MartenTurbo::Verifier.sign(stream_name)
          %(<turbo-cable-stream-source channel="MartenTurbo::StreamsChannel" ) +
            %(signed-stream-name="#{signed}"></turbo-cable-stream-source>)
        end
      end
    end
  end
end
