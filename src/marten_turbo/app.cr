require "./concerns/**"
require "./turbo_stream"
require "./ext/**"
require "./handlers/**"
require "./template/**"

module MartenTurbo
  class App < Marten::App
    label "marten_turbo"

    def setup
      Marten::Template::Tag.register "dom_id", Template::Tag::DomId
      Marten::Template::Tag.register "turbo_stream", Template::Tag::TurboStream
      Marten::Template::Tag.register "turbo_frame", Template::Tag::TurboFrame
      Marten::Template::Tag.register "turbo_refreshes_with", Template::Tag::TurboRefreshesWith
      Marten::Template::Tag.register "turbo_stream_from", Template::Tag::TurboStreamFrom
      Marten::Template::Tag.register "turbo_page_requires_reload", Template::Tag::TurboPageRequiresReload
      Marten::Template::Tag.register "turbo_exempts_page_from_cache", Template::Tag::TurboExemptsPageFromCache
      Marten::Template::Tag.register "turbo_exempts_page_from_preview", Template::Tag::TurboExemptsPageFromPreview
    end
  end
end
