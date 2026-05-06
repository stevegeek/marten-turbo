module MartenTurbo
  module Template
    module Tag
      # `{% turbo_stream_from "stream_name" %}` — emits the
      # `<turbo-cable-stream-source>` custom element shipped with Turbo's
      # JS. The element subscribes to MartenTurbo::StreamsChannel over
      # the open Cable WebSocket, naming the (signed) stream so
      # broadcasts reach the page.
      #
      # The stream name is signed at render time; the channel verifies
      # it on subscribe so a hostile client can't subscribe to arbitrary
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
          stream_name = @stream_filter.resolve(context).to_s
          signed = MartenTurbo::Verifier.sign(stream_name)
          %(<turbo-cable-stream-source channel="MartenTurbo::StreamsChannel" ) +
            %(signed-stream-name="#{signed}"></turbo-cable-stream-source>)
        end
      end
    end
  end
end
