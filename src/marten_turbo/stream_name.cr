module MartenTurbo
  # Coerces a value to a stable WebSocket stream identifier.
  #
  # - String stays as itself ({% turbo_stream_from "messages" %})
  # - Marten::Model returns its `cable_stream_name` (Broadcastable-defined)
  #   so {% turbo_stream_from room %} matches `broadcasts_to :room` on
  #   Message
  # - Anything else falls back to its `.to_s`
  # Phase 2 M1+M2: snake_cases the class name via `MartenTurbo.dom_class_name`,
  # so a model that doesn't `include Broadcastable` still produces the same
  # stream name shape as `Broadcastable#cable_stream_name` and `dom_id` (e.g.
  # `chat_room_42`, not `chatroom_42`).
  def self.stream_name(value : Marten::Model) : String
    if value.responds_to?(:cable_stream_name)
      value.cable_stream_name
    else
      "#{::MartenTurbo.dom_class_name(value.class)}_#{value.pk}"
    end
  end

  def self.stream_name(value : String) : String
    value
  end

  def self.stream_name(value) : String
    value.to_s
  end
end
