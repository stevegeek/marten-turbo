require "./streamable"

module MartenTurbo
  module Handlers
    module Concerns
      # Provides the ability to generate turbo stream responses with the content of rendered templates.
      module Rendering
        include Concerns::Streamable

        macro included
          # Returns the configured turbo stream template name.
          class_getter turbo_stream_name : String?

          # Phase 2 M3: optional separate template for the *invalid-schema*
          # turbo-stream response. Defaults to `turbo_stream_name` so most
          # handlers don't need to set it — but hosts that want a different
          # template (e.g. one that targets the form-frame for in-place
          # replacement) can override it.
          class_getter invalid_turbo_stream_name : String?

          extend MartenTurbo::Handlers::Concerns::Rendering::ClassMethods
        end

        module ClassMethods
          # Allows to configure the turbo stream template that should be rendered by the handler.
          def turbo_stream_name(turbo_stream_name : String?)
            @@turbo_stream_name = turbo_stream_name
          end

          # Allows to configure the turbo stream template rendered when schema
          # validation fails on a Turbo request. Defaults to `turbo_stream_name`
          # when unset; see `MartenTurbo::Handlers::Concerns::Rendering#invalid_turbo_stream_name`.
          def invalid_turbo_stream_name(name : String?)
            @@invalid_turbo_stream_name = name
          end
        end

        def render_turbo_stream(
          context : Hash | NamedTuple | Marten::Template::Context? = nil,
          status : ::HTTP::Status | Int32 = 200,
        )
          if stream_obj = turbo_stream
            turbo_stream(stream_obj, status)
          elsif name = turbo_stream_name
            turbo_stream(name, context: context, status: status)
          else
            # Callers gate on `turbo_streamable?` (true iff `turbo_stream` or
            # `turbo_stream_name` is non-nil), so this branch is unreachable —
            # the explicit raise just keeps the compiler happy without `.not_nil!`.
            raise "render_turbo_stream called without a configured stream"
          end
        end

        def render(
          turbo_stream : TurboStream,
          context,
        )
        end

        def turbo_stream : MartenTurbo::TurboStream?
          nil
        end

        def turbo_streamable?
          !!(turbo_stream || turbo_stream_name)
        end

        def turbo_stream_name : String?
          self.class.turbo_stream_name
        end

        # Phase 2 M3: returns the template name to render when schema
        # validation fails on a Turbo request. Defaults to `turbo_stream_name`
        # so a single template can double as the success + failure response;
        # override on the host handler to use a separate template (e.g. one
        # that targets the form frame for in-place replacement).
        def invalid_turbo_stream_name : String?
          self.class.invalid_turbo_stream_name || turbo_stream_name
        end
      end
    end
  end
end
