module MartenTurbo
  # Per-record real-time broadcasts.
  #
  # Mirrors `Turbo::Broadcastable` from turbo-rails. Include into a Marten
  # model and call `broadcasts_to` to wire after-commit callbacks that
  # publish turbo-stream actions to a per-association (or named) channel:
  #
  #     class Message < Marten::Model
  #       include MartenTurbo::Broadcastable
  #
  #       belongs_to :room, Room, related: :messages
  #
  #       broadcasts_to :room
  #     end
  #
  #     # In a template:
  #     {% turbo_stream_from room %}      # subscribes to room.cable_stream_name
  #     <div id="messages">
  #       {% for message in messages %}
  #         {% include "messages/_message.html" %}
  #       {% endfor %}
  #     </div>
  #
  # Defaults derived from the model name (`Message` →):
  #   - target container for append: "messages"
  #   - target id for replace/remove: "message_<pk>"
  #   - partial: "messages/_message.html"
  #   - locals key: "message"
  #
  # Override per-call:
  #
  #     broadcasts_to :room,
  #       partial:    "rooms/_chat_message.html",
  #       container:  "chat_log",
  #       member:     "chat_message"
  #
  # Or, for a static stream name:
  #
  #     broadcasts_to "messages"
  #
  # Note (vs Rails): turbo-rails auto-includes Broadcastable into every
  # ActiveRecord model. Crystal has no on_load hook, so each model has
  # to `include MartenTurbo::Broadcastable` explicitly.
  module Broadcastable
    # Default per-record stream identifier used by `{% turbo_stream_from
    # record %}`. Override in your model if you want something other than
    # `<class_underscore>_<pk>`.
    #
    # Phase 2 M1+M2: snake_cases the class name via the central
    # `MartenTurbo.dom_class_name` helper, so this stays in sync with
    # `dom_id` and the `broadcasts_to` macro defaults.
    def cable_stream_name : String
      "#{::MartenTurbo.dom_class_name(self.class)}_#{pk!}"
    end

    macro broadcasts_to(target, partial = nil, container = nil, member = nil)
      {% klass_name = @type.name.stringify.split("::").last %}
      {% member_default = klass_name.underscore %}
      {% container_default = "#{member_default.id}s" %}
      {% partial_default = "#{container_default.id}/_#{member_default.id}.html" %}

      {% partial_value = partial || partial_default %}
      {% container_value = container || container_default %}
      {% member_value = member || member_default %}

      after_create_commit :_broadcast_create
      after_update_commit :_broadcast_update
      after_delete_commit :_broadcast_delete

      private def _broadcast_stream_name : String
        {% if target.is_a?(SymbolLiteral) %}
          related = self.{{ target.id }}
          if related.nil?
            raise {{ "broadcasts_to(#{target}): #{@type.name}##{target.id} returned nil; can't compute stream name" }}
          end
          ::MartenTurbo.stream_name(related)
        {% else %}
          {{ target }}.to_s
        {% end %}
      end

      private def _broadcast_create
        ::MartenTurbo.broadcast_append_to(
          _broadcast_stream_name,
          target:  {{ container_value }},
          partial: {{ partial_value }},
          locals:  { {{ member_value }} => self },
        )
      end

      # Phase 2 M6: `pk!` (not `pk`) so an unpersisted record (or one whose
      # PK is unexpectedly nil at callback time) raises `NilAssertionError`
      # with a clear cause instead of silently broadcasting a target like
      # `"chat_room_"` that no element can possibly match.
      private def _broadcast_update
        ::MartenTurbo.broadcast_replace_to(
          _broadcast_stream_name,
          target:  "{{ member_value.id }}_#{pk!}",
          partial: {{ partial_value }},
          locals:  { {{ member_value }} => self },
        )
      end

      private def _broadcast_delete
        ::MartenTurbo.broadcast_remove_to(
          _broadcast_stream_name,
          target: "{{ member_value.id }}_#{pk!}",
        )
      end
    end
  end
end
