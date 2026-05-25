require "openssl/hmac"
require "base64"
require "crypto/subtle"

module MartenTurbo
  # Sign / verify stream names so a hostile client can't subscribe
  # to arbitrary streams. Mirrors what turbo-rails does via Rails'
  # MessageVerifier — HMAC-SHA256 over Marten.settings.secret_key,
  # message and signature concatenated with "--".
  #
  # A `scope` argument binds a signature to a particular subject (typically the
  # current Cable connection's `identifier`). With a non-empty scope, the HMAC
  # purpose becomes `"turbo-stream-name:<scope>"` — a signature minted for
  # `scope: "user-42"` will not verify under `scope: "user-43"`, nor under no
  # scope at all. This prevents replay of a leaked `signed-stream-name` by a
  # different Cable-authenticated client (see `StreamsChannel#subscribed`).
  module Verifier
    extend self

    PURPOSE = "turbo-stream-name"

    # Returns "<base64 message>--<base64 hmac>". Stable for a given
    # (name, scope, secret_key) triple so identical streams produce identical
    # signed names — useful for caching and for matching subscriber joins
    # against a known-good signature.
    #
    # When `scope` is non-empty, the signature is only valid when `verify` is
    # called with the same scope.
    def sign(stream_name : String, scope : String = "") : String
      message = Base64.urlsafe_encode(stream_name, padding: false)
      digest = compute_digest(message, scope)
      "#{message}--#{digest}"
    end

    # Returns the unsigned stream name if `signed` was produced by `sign` with
    # the current secret_key *and* the same scope, otherwise nil.
    def verify(signed : String?, scope : String = "") : String?
      return if signed.nil? || signed.empty?

      message, _, signature = signed.partition("--")
      return if message.empty? || signature.empty?

      expected = compute_digest(message, scope)
      return unless secure_compare(expected, signature)

      Base64.decode_string(message)
    rescue Base64::Error
      nil
    end

    private def compute_digest(message : String, scope : String) : String
      purpose = scope.empty? ? PURPOSE : "#{PURPOSE}:#{scope}"
      Base64.urlsafe_encode(
        OpenSSL::HMAC.digest(:sha256, secret_key + purpose, message),
        padding: false
      )
    end

    # L11: delegate to Crystal's stdlib constant-time compare
    # (`Crypto::Subtle.constant_time_compare`, available since 1.10) instead
    # of carrying a hand-rolled copy. Same length-then-XOR semantics; one
    # fewer place to audit.
    private def secure_compare(a : String, b : String) : Bool
      Crypto::Subtle.constant_time_compare(a, b)
    end

    private def secret_key : String
      Marten.settings.secret_key
    end
  end
end
