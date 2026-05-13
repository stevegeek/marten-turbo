module MartenTurbo
  module Template
    module Tag
      # Mirrors turbo-rails `Turbo::DriveHelper`. Each tag emits a single
      # `<meta>` element controlling Turbo Drive's per-page behavior.
      # No arguments — drop the tag in a layout's `{% block head %}` block
      # (or any view rendered into the head) to apply.
      #
      # - `{% turbo_page_requires_reload %}`
      #     → `<meta name="turbo-visit-control" content="reload">`
      #     Force a full page reload when Turbo would otherwise drive the
      #     visit. Useful on sign-in pages where the cached signed-out
      #     view would otherwise stick around after sign-out.
      # - `{% turbo_exempts_page_from_cache %}`
      #     → `<meta name="turbo-cache-control" content="no-cache">`
      #     Skip Turbo's page cache for this page (visual-jitter avoidance
      #     when a cache miss is more likely than not).
      # - `{% turbo_exempts_page_from_preview %}`
      #     → `<meta name="turbo-cache-control" content="no-preview">`
      #     Allow caching but suppress the preview frame during navigation.
      #
      # Compared with turbo-rails, these don't ship a `provide :head`
      # variant — Marten templates use explicit `{% block head %}`
      # extension rather than Rails' `provide`/`yield` content_for.
      # Drop the tag inside the head block directly.
      abstract class DriveMeta < Marten::Template::Tag::Base
        def initialize(parser : Marten::Template::Parser, source : String)
          # No-arg tag; reject anything after the tag name to flag typos.
          # `source` looks like `tag_name` exactly when no args are passed.
          remainder = source.strip
          tokens = remainder.split(/\s+/, 2)
          if tokens.size > 1
            raise Marten::Template::Errors::InvalidSyntax.new(
              "Malformed #{tokens[0]} tag: no arguments expected, got #{tokens[1].inspect}"
            )
          end
        end

        abstract def meta_name : String
        abstract def meta_content : String

        def render(context : Marten::Template::Context) : String
          %(<meta name="#{meta_name}" content="#{meta_content}">)
        end
      end

      class TurboPageRequiresReload < DriveMeta
        def meta_name : String
          "turbo-visit-control"
        end

        def meta_content : String
          "reload"
        end
      end

      class TurboExemptsPageFromCache < DriveMeta
        def meta_name : String
          "turbo-cache-control"
        end

        def meta_content : String
          "no-cache"
        end
      end

      class TurboExemptsPageFromPreview < DriveMeta
        def meta_name : String
          "turbo-cache-control"
        end

        def meta_content : String
          "no-preview"
        end
      end
    end
  end
end
