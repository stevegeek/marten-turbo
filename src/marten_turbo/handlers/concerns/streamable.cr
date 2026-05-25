module MartenTurbo
  module Handlers
    module Concerns
      module Streamable
        def turbo_stream(
          template_name : String,
          context : Hash | NamedTuple | Marten::Template::Context? = nil,
          status : ::HTTP::Status | Int32 = 200,
        )
          render(template_name, context, TURBO_CONTENT_TYPE, status)
        end

        def turbo_stream(
          stream : MartenTurbo::TurboStream,
          status : ::HTTP::Status | Int32 = 200,
        )
          respond(stream.to_s, TURBO_CONTENT_TYPE, status)
        end

        def turbo_stream(status : ::HTTP::Status | Int32 = 200, &)
          stream = TurboStream.new

          with stream yield

          turbo_stream(stream, status)
        end

        # Renders *partial* and responds with a `<turbo-stream action="replace">`
        # targeting *frame_id*.
        #
        # Mirrors Rails' `turbo_stream.replace(frame_id, partial:, locals:)` from
        # turbo-rails. The partial is rendered with *locals* merged into a fresh
        # template context (with the handler set so tags like `{% csrf_input %}`
        # resolve correctly), wrapped in a single replace turbo-stream, and sent
        # back with the `text/vnd.turbo-stream.html` content type.
        #
        # ```
        # turbo_frame_replace(
        #   "book_publication_#{book.id}",
        #   partial: "books/publications/_publication.html",
        #   locals: {book: book, editable: true},
        # )
        # ```
        def turbo_frame_replace(
          frame_id : String,
          partial : String,
          locals : Hash | NamedTuple = NamedTuple.new,
          status : ::HTTP::Status | Int32 = 200,
        )
          ctx = Marten::Template::Context.from(locals, request)
          ctx.handler = self
          ctx[:request] = request

          rendered = Marten.templates.get_template(partial).render(ctx)
          stream_html = MartenTurbo::TurboStream.action("replace", frame_id, rendered).to_s

          respond(stream_html, content_type: TURBO_CONTENT_TYPE, status: status)
        end
      end
    end
  end
end
