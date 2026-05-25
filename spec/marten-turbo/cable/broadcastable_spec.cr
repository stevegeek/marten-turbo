require "../spec_helper"
require "../../../lib/cable/src/backend/dev/backend"

# Use cable-cr's DevBackend to capture publishes.
Cable.configure do |s|
  s.url = "test://"
  s.backend_class = Cable::DevBackend
  s.route = "/cable"
end

describe MartenTurbo::Broadcastable do
  before_each do
    Cable::DevBackend.reset
  end

  describe "broadcasts_to" do
    it "broadcasts an append on create" do
      tag = BroadcastedTag.create!(name: "first")

      Cable::DevBackend.published_messages.size.should eq(1)
      stream, payload = Cable::DevBackend.published_messages.first
      stream.should eq("broadcasted_tags")
      payload.should contain(%(<turbo-stream action="append" target="broadcasted_tags">))
      payload.should contain(%(<div id="broadcasted_tag_#{tag.id}">))
      payload.should contain("first")
    end

    it "broadcasts a replace on update" do
      tag = BroadcastedTag.create!(name: "first")
      Cable::DevBackend.reset

      tag.name = "edited"
      tag.save!

      Cable::DevBackend.published_messages.size.should eq(1)
      _, payload = Cable::DevBackend.published_messages.first
      payload.should contain(%(<turbo-stream action="replace" target="broadcasted_tag_#{tag.id}">))
      payload.should contain("edited")
    end

    it "broadcasts a remove on delete" do
      tag = BroadcastedTag.create!(name: "first")
      pk = tag.id
      Cable::DevBackend.reset

      tag.delete

      Cable::DevBackend.published_messages.size.should eq(1)
      _, payload = Cable::DevBackend.published_messages.first
      payload.should contain(%(<turbo-stream action="remove" target="broadcasted_tag_#{pk}">))
    end
  end

  describe "#cable_stream_name" do
    # Phase 2 M1+M2: previously this spec locked in the *broken* behaviour
    # `broadcastedtag_<id>` (plain `downcase`), which disagreed with
    # `broadcasts_to`'s `member:` default (`broadcasted_tag_<id>` — already
    # `underscore`'d) and with what `dom_id` should produce. All three now
    # go through `MartenTurbo.dom_class_name`, so this returns the proper
    # snake_case form.
    it "defaults to <classname_snake_case>_<pk>" do
      tag = BroadcastedTag.create!(name: "first")
      tag.cable_stream_name.should eq("broadcasted_tag_#{tag.id}")
    end
  end

  # Phase 2 M6: `_broadcast_update` / `_broadcast_delete` interpolate `pk!`
  # (not the nilable `pk`) so an unpersisted record raises a clear
  # `NilAssertionError` instead of silently publishing a target of
  # `"broadcasted_tag_"` (which no element on the page can possibly match).
  describe "broadcast target safety (pk!)" do
    it "raises NilAssertionError when _broadcast_update is invoked on an unpersisted record" do
      expect_raises(NilAssertionError) do
        BroadcastedTag.new(name: "ghost").spec_invoke_broadcast_update
      end
    end

    it "raises NilAssertionError when _broadcast_delete is invoked on an unpersisted record" do
      expect_raises(NilAssertionError) do
        BroadcastedTag.new(name: "ghost").spec_invoke_broadcast_delete
      end
    end
  end
end
