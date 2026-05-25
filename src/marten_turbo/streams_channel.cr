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
    # L10: how many characters of the offending signed-stream-name to include
    # in rejection log lines. Enough for ops to spot repeated probing
    # patterns (random prefixes will not repeat) but well under the full
    # signed payload — preserves token confidentiality if logs leak.
    LOG_NAME_PREVIEW_SIZE = 32

    def subscribed
      raw = params["signed_stream_name"]?
      signed = raw.is_a?(String) ? raw : nil
      scope = connection.identifier

      # An empty connection identifier means the connection has no per-user
      # identity (`identified_by` was not called, or the value is unset). In
      # that case the signature is unscoped, and verifying it would let any
      # Cable client replay a signed stream name. Refuse — the host app must
      # set an identifier (e.g. `self.identifier = current_user.pk.to_s`)
      # before per-connection streams will work.
      if scope.empty?
        ::Cable::Logger.warn do
          "MartenTurbo::StreamsChannel rejected: connection identifier is empty " \
          "(name_preview=#{signed_name_preview(signed)})"
        end
        reject
        return
      end

      stream_name = Verifier.verify(signed, scope: scope)

      if stream_name.nil?
        ::Cable::Logger.warn do
          "MartenTurbo::StreamsChannel rejected: invalid or missing signed_stream_name " \
          "(name_preview=#{signed_name_preview(signed)})"
        end
        reject
        return
      end

      stream_from stream_name
    end

    # L10: returns a short preview of the offending signed-stream-name so
    # operators can detect probing patterns from logs without leaking the
    # full signed payload. nil/empty values render as `"<none>"`.
    private def signed_name_preview(signed : String?) : String
      return "<none>" if signed.nil? || signed.empty?

      preview = signed[0, LOG_NAME_PREVIEW_SIZE]
      preview.size < signed.size ? "#{preview}…" : preview
    end
  end
end
