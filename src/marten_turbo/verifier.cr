require "openssl/hmac"
require "base64"

module MartenTurbo
  # Sign / verify stream names so a hostile client can't subscribe
  # to arbitrary streams. Mirrors what turbo-rails does via Rails'
  # MessageVerifier — HMAC-SHA256 over Marten.settings.secret_key,
  # message and signature concatenated with "--".
  module Verifier
    extend self

    PURPOSE = "turbo-stream-name"

    # Returns "<base64 message>--<base64 hmac>". Stable for a given
    # (name, secret_key) pair so identical streams produce identical
    # signed names — useful for caching and for matching subscriber
    # joins against a known-good signature.
    def sign(stream_name : String) : String
      message = Base64.urlsafe_encode(stream_name, padding: false)
      digest = compute_digest(message)
      "#{message}--#{digest}"
    end

    # Returns the unsigned stream name if `signed` was produced by
    # `sign` with the current secret_key, otherwise nil.
    def verify(signed : String?) : String?
      return nil if signed.nil? || signed.empty?

      message, _, signature = signed.partition("--")
      return nil if message.empty? || signature.empty?

      expected = compute_digest(message)
      return nil unless secure_compare(expected, signature)

      Base64.decode_string(message)
    rescue Base64::Error
      nil
    end

    private def compute_digest(message : String) : String
      Base64.urlsafe_encode(
        OpenSSL::HMAC.digest(:sha256, secret_key + PURPOSE, message),
        padding: false
      )
    end

    # Byte-by-byte comparison that doesn't short-circuit on the first
    # mismatch — avoids timing oracles on the signature.
    private def secure_compare(a : String, b : String) : Bool
      return false if a.bytesize != b.bytesize
      result = 0_u8
      a.to_slice.each_with_index do |byte, i|
        result |= byte ^ b.to_slice[i]
      end
      result == 0_u8
    end

    private def secret_key : String
      Marten.settings.secret_key
    end
  end
end
