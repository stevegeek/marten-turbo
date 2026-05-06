module MartenTurbo
  # The single Cable channel that backs every `{% turbo_stream_from %}`
  # subscription. Browser side is `<turbo-cable-stream-source>`, which
  # is bundled with Turbo's JS — it sends a normal Action Cable
  # subscribe message naming this channel and a signed stream name.
  #
  # We verify the signature here, then `stream_from` the unsigned
  # name. After that, anything published to that stream by
  # `MartenTurbo.broadcast_*` reaches every subscriber for free.
  class StreamsChannel < ::Cable::Channel
    def subscribed
      signed = params["signed_stream_name"]?.try(&.as_s?)
      stream_name = Verifier.verify(signed)

      if stream_name.nil?
        ::Cable::Logger.warn { "MartenTurbo::StreamsChannel rejected: invalid or missing signed_stream_name" }
        reject
        return
      end

      stream_from stream_name
    end
  end
end
