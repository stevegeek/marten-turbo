require "marten_cable"

require "./marten_turbo/verifier"
require "./marten_turbo/streams_channel"
require "./marten_turbo/stream_name"
# `broadcasts.cr` iterates over `MartenTurbo::TurboStream::ACTIONS` at macro-
# expansion time (Phase 3 L13), so `turbo_stream.cr` (which itself depends
# on `concerns/dom_identifier.cr` for `Identifiable`) must be loaded first.
require "./marten_turbo/concerns/**"
require "./marten_turbo/turbo_stream"
require "./marten_turbo/broadcasts"
require "./marten_turbo/broadcastable"

require "./marten_turbo/app"

module MartenTurbo
  VERSION            = "0.3.0"
  TURBO_CONTENT_TYPE = "text/vnd.turbo-stream.html"

  # Returns the canonical snake_case identifier for a Marten model class. Used
  # by `dom_id`, `cable_stream_name`, and the `broadcasts_to` macro defaults so
  # all three agree on the same shape:
  #
  #   ChatRoom              → "chat_room"
  #   My::Models::ChatRoom  → "my_models_chat_room"
  #   Tag                   → "tag"
  #
  # Phase 2 M1+M2: previously `dom_id` returned `chatroom_42` (a plain
  # `downcase` of the class name) while `broadcasts_to`'s `member:` default
  # was `chat_room_42` (because `String#underscore` *is* applied there).
  # Templates calling `{% turbo_stream 'remove' chat_room %}` therefore
  # targeted `chatroom_42` but auto-broadcasts published to `chat_room_42`
  # and never reached the rendered element. Centralising the transform fixes
  # that.
  def self.dom_class_name(klass : Marten::Model.class) : String
    klass.name.gsub("::", "_").underscore
  end

  # Convenience: returns the per-instance dom id for a Marten model — the
  # snake_case class name joined with the primary key, matching the targets
  # auto-broadcast by `MartenTurbo::Broadcastable#broadcasts_to`.
  def self.dom_id(record : Marten::Model) : String
    if record.new_record?
      "new_#{dom_class_name(record.class)}"
    else
      "#{dom_class_name(record.class)}_#{record.pk}"
    end
  end
end
