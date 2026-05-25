module MartenTurbo
  # `Identifiable#dom_id` is the canonical helper for computing turbo-frame
  # identifiers. The optional `prefix` arg matches Rails'
  # `ActionView::RecordIdentifier.dom_id(record, prefix)` and is exercised
  # by the `{% dom_id record "edit" %}` template tag form
  # (see `Template::Tag::DomId#render` and its spec at
  # `spec/marten-turbo/template/tag/dom_id_spec.cr`).
  module Identifiable
    @[Deprecated("Use `#dom_id` instead. Will be removed in v0.5.0.")]
    def create_dom_id(value, prefix : String | Symbol? = nil)
      dom_id(value, prefix)
    end

    def dom_id(value, prefix : String | Symbol? = nil)
      dom_id = value.to_s
      prefix ? "#{prefix}_#{dom_id}" : dom_id
    end

    @[Deprecated("Use `#dom_id` instead. Will be removed in v0.5.0.")]
    def create_dom_id(value : Marten::Model, prefix : String | Symbol? = nil)
      dom_id(value, prefix)
    end

    def dom_id(value : Marten::Model, prefix : String | Symbol? = nil)
      generate_id_for_model(value, prefix)
    end

    private def formatted_prefix(prefix)
      prefix ? "#{prefix}_" : ""
    end

    # Phase 2 M1+M2: snake_case the class name so `ChatRoom` produces
    # `chat_room_42` rather than the old `chatroom_42`. Aligns with the
    # `broadcasts_to` macro defaults (which already `underscore`'d the
    # member name) and with `MartenTurbo::Broadcastable#cable_stream_name`.
    # See `MartenTurbo.dom_class_name` for the central transform.
    private def generate_id_for_model(model, prefix)
      identifier = ::MartenTurbo.dom_class_name(model.class)
      if model.new_record?
        "#{formatted_prefix(prefix)}new_#{identifier}"
      else
        "#{formatted_prefix(prefix)}#{identifier}_#{model.pk}"
      end
    end
  end
end
