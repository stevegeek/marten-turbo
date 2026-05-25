require "../spec_helper"
require "../../../lib/cable/src/backend/dev/backend"

# Use cable-cr's DevBackend so no real WebSocket is needed.
Cable.configure do |s|
  s.url = "test://"
  s.backend_class = Cable::DevBackend
  s.route = "/cable"
end

# Minimal stub mirroring `lib/cable/spec/support/dummy_socket.cr` so we can
# instantiate a `Cable::Connection` without an actual WebSocket upgrade.
private class StreamsChannelSpecDummySocket < HTTP::WebSocket
  getter messages : Array(String) = Array(String).new

  def send(message)
    return if closed?
    @messages << message
  end
end

private class StreamsChannelSpecScopedConnection < Cable::Connection
  identified_by :identifier

  def connect
    self.identifier = (token || "")
  end
end

private def build_request(token : String?) : HTTP::Request
  headers = HTTP::Headers{
    "Upgrade"                => "websocket",
    "Connection"             => "Upgrade",
    "Sec-WebSocket-Key"      => "OqColdEJm3i9e/EqMxnxZw==",
    "Sec-WebSocket-Protocol" => "actioncable-v1-json, actioncable-unsupported",
    "Sec-WebSocket-Version"  => "13",
  }
  if token
    HTTP::Request.new("GET", "#{Cable.settings.route}?#{Cable.settings.token}=#{token}", headers)
  else
    HTTP::Request.new("GET", Cable.settings.route, headers)
  end
end

private def build_connection(identifier : String) : Cable::Connection
  socket = StreamsChannelSpecDummySocket.new(IO::Memory.new)
  StreamsChannelSpecScopedConnection.new(build_request(identifier), socket)
end

private def build_streams_channel(connection : Cable::Connection, signed_stream_name : String?)
  params = Hash(String, Cable::Payload::RESULT).new
  params["signed_stream_name"] = signed_stream_name if signed_stream_name
  MartenTurbo::StreamsChannel.new(
    connection: connection,
    identifier: %({"channel":"MartenTurbo::StreamsChannel"}),
    params: params,
  )
end

describe MartenTurbo::StreamsChannel do
  describe "#subscribed" do
    it "subscribes a stream signed for the current connection identity" do
      connection = build_connection("user-42")
      signed = MartenTurbo::Verifier.sign("messages", scope: "user-42")
      channel = build_streams_channel(connection, signed)

      channel.subscribed

      channel.subscription_rejected?.should be_false
      channel.stream_identifier.should eq("messages")
    ensure
      connection.try(&.close)
    end

    it "rejects a signed name minted for a different connection (replay attempt)" do
      # H2 regression: a leaked signed-stream-name from user A must not be
      # subscribable by user B. The signature is bound to the Cable connection
      # identifier, so verifying under a different scope fails.
      connection_b = build_connection("user-43")
      signed_for_a = MartenTurbo::Verifier.sign("messages", scope: "user-42")
      channel = build_streams_channel(connection_b, signed_for_a)

      channel.subscribed

      channel.subscription_rejected?.should be_true
      channel.stream_identifier.should be_nil
    ensure
      connection_b.try(&.close)
    end

    it "rejects when no signed_stream_name is provided" do
      connection = build_connection("user-42")
      channel = build_streams_channel(connection, nil)

      channel.subscribed

      channel.subscription_rejected?.should be_true
    ensure
      connection.try(&.close)
    end

    it "rejects when the connection identifier is empty" do
      # An empty identifier means the host app has not bound a per-user identity
      # to the Cable connection. Allowing it would let any client subscribe to
      # any signed stream produced with an empty scope.
      connection = build_connection("")
      signed = MartenTurbo::Verifier.sign("messages", scope: "")
      channel = build_streams_channel(connection, signed)

      channel.subscribed

      channel.subscription_rejected?.should be_true
    ensure
      connection.try(&.close)
    end

    it "rejects a tampered signature" do
      connection = build_connection("user-42")
      signed = MartenTurbo::Verifier.sign("messages", scope: "user-42")
      msg, _, sig = signed.partition("--")
      tampered = "#{msg}--#{sig.reverse}"
      channel = build_streams_channel(connection, tampered)

      channel.subscribed

      channel.subscription_rejected?.should be_true
    ensure
      connection.try(&.close)
    end
  end

  # Phase 2 M8: simulate a page-navigation lifecycle. The browser sends a
  # subscribe, then sometime later the WebSocket is dropped (the page
  # navigated, the user closed the tab, …). `Cable::Channel#close` must
  # auto-unbind from the server-side stream registry so that subsequent
  # `send_to_channels(stream)` calls don't try to write to the dead socket.
  # `Cable.server.send_to_channels` calls `channel.connection.socket.send`
  # under the hood; verifying it doesn't dispatch to a closed channel is
  # the load-bearing assertion.
  describe "unsubscribe lifecycle" do
    it "stops receiving broadcasts after the channel is closed" do
      connection = build_connection("user-42")
      signed = MartenTurbo::Verifier.sign("messages", scope: "user-42")
      channel = build_streams_channel(connection, signed)

      channel.subscribed
      channel.subscription_rejected?.should be_false
      stream_id = channel.stream_identifier.not_nil!

      # Manually register the channel with the server (the connection's
      # message loop normally does this — but in this spec we never run
      # the loop, only the in-process channel methods).
      Cable.server.subscribe_channel(channel: channel, identifier: stream_id)

      # Baseline: a broadcast reaches a live subscriber. The DevBackend
      # records the publish; the more direct check is that
      # `send_to_channels` finds the registered channel.
      Cable.server.send_to_channels(stream_id, "hello")
      socket = connection.socket.as(StreamsChannelSpecDummySocket)
      live_count = socket.messages.size
      live_count.should be > 0

      # Drop the page: closing the channel triggers `unsubscribe_channel`
      # internally (see `Cable::Channel#close` in cable-cr).
      channel.close

      Cable.server.send_to_channels(stream_id, "after-close")
      socket.messages.size.should eq(live_count)
    ensure
      connection.try(&.close)
    end
  end
end
