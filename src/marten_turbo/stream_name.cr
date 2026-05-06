module MartenTurbo
  # Coerces a value to a stable WebSocket stream identifier.
  #
  # - String stays as itself ({% turbo_stream_from "messages" %})
  # - Marten::Model returns its `cable_stream_name` (Broadcastable-defined)
  #   so {% turbo_stream_from room %} matches `broadcasts_to :room` on
  #   Message
  # - Anything else falls back to its `.to_s`
  def self.stream_name(value : Marten::Model) : String
    if value.responds_to?(:cable_stream_name)
      value.cable_stream_name
    else
      "#{value.class.name.gsub("::", "_").downcase}_#{value.pk}"
    end
  end

  def self.stream_name(value : String) : String
    value
  end

  def self.stream_name(value) : String
    value.to_s
  end
end
