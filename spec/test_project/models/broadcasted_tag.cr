# Broadcastable model for spec coverage of `broadcasts_to`. Static stream
# name so we don't need to set up an association in this tiny test app.
class BroadcastedTag < Marten::Model
  include Marten::Template::CanDefineTemplateAttributes
  include MartenTurbo::Broadcastable

  field :id, :big_int, primary_key: true, auto: true
  field :name, :string, max_size: 255

  template_attributes :id, :name

  broadcasts_to "broadcasted_tags"

  # Phase 2 M6 hook: exposes the private after-commit broadcasts to specs so
  # we can prove `pk!` raises a clear `NilAssertionError` when the record's
  # pk is unexpectedly nil at broadcast time, instead of silently publishing
  # a target like `"broadcasted_tag_"` that matches no element.
  def spec_invoke_broadcast_update
    _broadcast_update
  end

  def spec_invoke_broadcast_delete
    _broadcast_delete
  end
end
