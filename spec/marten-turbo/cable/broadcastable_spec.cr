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
    it "defaults to <classname_underscored>_<pk>" do
      tag = BroadcastedTag.create!(name: "first")
      tag.cable_stream_name.should eq("broadcastedtag_#{tag.id}")
    end
  end
end
