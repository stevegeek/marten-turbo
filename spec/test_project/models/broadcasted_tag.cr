# Broadcastable model for spec coverage of `broadcasts_to`. Static stream
# name so we don't need to set up an association in this tiny test app.
class BroadcastedTag < Marten::Model
  include Marten::Template::CanDefineTemplateAttributes
  include MartenTurbo::Broadcastable

  field :id, :big_int, primary_key: true, auto: true
  field :name, :string, max_size: 255

  template_attributes :id, :name

  broadcasts_to "broadcasted_tags"
end
