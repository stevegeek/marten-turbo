require "../spec_helper"
require "cable"
require "../../../lib/cable/src/backend/dev/backend"

# Use cable-cr's DevBackend (records publishes for assertions). It's the
# right backend for spec — no real WebSocket needed; we just verify what
# Cable.server.publish was called with.
Cable.configure do |s|
  s.url = "test://"
  s.backend_class = Cable::DevBackend
  s.route = "/cable"
end

# L7: stub a publish-raising backend so we can assert MartenTurbo's
# `safe_publish` swallows the failure rather than propagating into the
# host's commit hook. Inherits the rest of `DevBackend`'s no-op surface.
class RaisingPublishBackend < Cable::DevBackend
  class StubBackendError < Exception
  end

  def publish_message(stream_identifier : String, message : String)
    raise StubBackendError.new("simulated Redis hiccup")
  end
end

describe "MartenTurbo broadcast helpers" do
  before_each do
    Cable::DevBackend.reset
  end

  it "broadcast_append_to publishes <turbo-stream action=\"append\">" do
    MartenTurbo.broadcast_append_to(
      "messages",
      target: "messages",
      content: "<div id=\"message_1\">hi</div>",
    )

    Cable::DevBackend.published_messages.size.should eq(1)
    stream, payload = Cable::DevBackend.published_messages.first
    stream.should eq("messages")
    payload.should contain(%(<turbo-stream action="append" target="messages">))
    payload.should contain("hi")
  end

  it "broadcast_replace_to publishes <turbo-stream action=\"replace\">" do
    MartenTurbo.broadcast_replace_to(
      "messages",
      target: "message_1",
      content: "<div id=\"message_1\">edited</div>",
    )
    _, payload = Cable::DevBackend.published_messages.first
    payload.should contain(%(<turbo-stream action="replace" target="message_1">))
  end

  it "broadcast_remove_to publishes <turbo-stream action=\"remove\">" do
    MartenTurbo.broadcast_remove_to(
      "messages",
      target: "message_1",
    )
    _, payload = Cable::DevBackend.published_messages.first
    payload.should contain(%(<turbo-stream action="remove" target="message_1">))
  end

  it "broadcast_refresh_to publishes a <turbo-stream action=\"refresh\">" do
    MartenTurbo.broadcast_refresh_to("messages")
    _, payload = Cable::DevBackend.published_messages.first
    payload.should contain(%(<turbo-stream action="refresh"></turbo-stream>))
  end

  it "raises when target is missing" do
    expect_raises(ArgumentError, /requires a target/) do
      MartenTurbo.broadcast_append_to("messages", content: "x")
    end
  end

  # L7: a backend exception inside `Cable.server.publish` used to propagate
  # straight out of `safe_publish` and — since the call site lives inside
  # the model's `after_*_commit` callback — out of the host's `create!` /
  # `save!`. A Redis hiccup or transient network failure would therefore
  # masquerade as "create failed for unrelated reason". `safe_publish` now
  # logs via `Marten::Log.error` and swallows the exception.
  describe "publish exception handling (L7)" do
    before_each do
      Cable.settings.backend_class = RaisingPublishBackend
      Cable.reset_server
    end

    after_each do
      Cable.settings.backend_class = Cable::DevBackend
      Cable.reset_server
    end

    it "swallows publish exceptions in broadcast_append_to" do
      MartenTurbo.broadcast_append_to("messages", target: "messages", content: "<div>x</div>")
    end

    it "swallows publish exceptions in broadcast_refresh_to" do
      MartenTurbo.broadcast_refresh_to("messages")
    end

    it "lets the host's save! succeed even when publish raises" do
      tag = BroadcastedTag.new(name: "ok")
      tag.save!
      tag.persisted?.should be_true
    end
  end
end
