require "./spec_helper"
require "../../lib/cable/src/backend/dev/backend"

# Phase 2 M1+M2: the snake_case fix centralises class-name → identifier
# transformation in `MartenTurbo.dom_class_name`, so `dom_id`,
# `cable_stream_name`, and the `broadcasts_to` macro defaults all produce
# the same shape (and round-trip with each other).

# Reuse cable-cr's DevBackend so the broadcasts spec at the bottom can
# inspect publishes without a real WebSocket.
Cable.configure do |s|
  s.url = "test://"
  s.backend_class = Cable::DevBackend
  s.route = "/cable"
end

describe MartenTurbo do
  describe ".dom_class_name" do
    it "snake_cases a single-word class" do
      MartenTurbo.dom_class_name(Tag).should eq("tag")
    end

    it "snake_cases a multi-word class (broken pre-Phase-2: was 'broadcastedtag')" do
      MartenTurbo.dom_class_name(BroadcastedTag).should eq("broadcasted_tag")
    end

    it "flattens a namespaced class to underscores" do
      MartenTurbo.dom_class_name(Namespaced::Tag).should eq("namespaced_tag")
    end
  end

  describe ".dom_id" do
    it "joins the snake_case class name with the pk for persisted records" do
      tag = Tag.create!(name: "Marten Turbo")
      MartenTurbo.dom_id(tag).should eq("tag_#{tag.pk}")
    end

    it "uses a `new_<class>` shape for unpersisted records" do
      MartenTurbo.dom_id(Tag.new).should eq("new_tag")
    end

    it "snake_cases multi-word classes (was 'broadcastedtag_<id>' pre-Phase-2)" do
      tag = BroadcastedTag.create!(name: "first")
      MartenTurbo.dom_id(tag).should eq("broadcasted_tag_#{tag.id}")
    end

    it "flattens namespaces into underscores" do
      tag = Namespaced::Tag.create!(name: "ns")
      MartenTurbo.dom_id(tag).should eq("namespaced_tag_#{tag.pk}")
    end
  end

  # Phase 2 M2 round-trip: the *target* the auto-broadcast publishes for an
  # update must match the *dom_id* the same record would render on the page.
  # Before the centralisation, `broadcasts_to`'s `_broadcast_update` used the
  # macro's `member_value.id` (snake_cased) while `dom_id` produced a
  # plain-`downcase` form — the auto-broadcast missed the rendered element.
  describe "broadcasts_to ↔ dom_id round-trip" do
    before_each do
      Cable::DevBackend.reset
    end

    it "publishes a replace targeting the same id `dom_id` would render" do
      tag = BroadcastedTag.create!(name: "first")
      expected_target = MartenTurbo.dom_id(tag) # "broadcasted_tag_<id>"

      Cable::DevBackend.reset
      tag.name = "edited"
      tag.save!

      _, payload = Cable::DevBackend.published_messages.first
      payload.should contain(%(target="#{expected_target}"))
    end
  end
end
