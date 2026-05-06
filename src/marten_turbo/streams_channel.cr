module MartenTurbo
  # The single Cable channel that backs every `{% turbo_stream_from %}`
  # subscription. The browser sends a normal Action Cable subscribe
  # message naming this channel plus a signed stream name; we verify
  # the signature, then `stream_from` the unsigned name. Anything
  # published to that stream via `MartenTurbo.broadcast_*` then reaches
  # every subscriber.
  #
  # On the JS side, `<turbo-cable-stream-source>` is what does the
  # subscribing — it's part of `@hotwired/turbo-rails`'s npm package
  # and not `@hotwired/turbo` itself, so plain Turbo apps need to
  # define an equivalent custom element (≈ 20 lines using `@rails/actioncable`
  # and `Turbo.connectStreamSource`).
  class StreamsChannel < ::Cable::Channel
    def subscribed
      raw = params["signed_stream_name"]?
      signed = raw.is_a?(String) ? raw : nil
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
