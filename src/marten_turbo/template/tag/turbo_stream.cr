module MartenTurbo
  module Template
    module Tag
      class TurboStream < Marten::Template::Tag::Base
        include Marten::Template::Tag::CanSplitSmartly
        include Marten::Template::Tag::CanExtractKwargs
        include Identifiable

        @turbo_stream_nodes : Marten::Template::NodeSet?
        @action_filter : Marten::Template::FilterExpression
        @target_id : Marten::Template::Variable?
        @locals : Hash(String, Marten::Template::FilterExpression)

        def initialize(parser : Marten::Template::Parser, source : String)
          parts = split_smartly(source)

          if parts.size < 2
            raise Marten::Template::Errors::InvalidSyntax.new(
              "Malformed turbo_stream tag: you must define an action"
            )
          end

          @action_filter = Marten::Template::FilterExpression.new(parts[1])

          # When only the action is supplied (e.g. `{% turbo_stream "refresh" %}`)
          # we leave the target unresolved and validate later, at render time:
          # `refresh` is the only Turbo Stream action that has no target, so
          # any other action will raise then.
          if parts.size == 2
            @target_id = nil
          else
            @target_id = Marten::Template::Variable.new(parts[2])
          end

          if parts[-1] == "do"
            @turbo_stream_nodes = parser.parse(up_to: {"end_turbo_stream"})
            parser.shift_token
            kwargs_source_parts = parts[2...-2]
          else
            kwargs_source_parts = parts[2..]
          end

          # Extract a `locals: {...}` hash literal (which may itself contain
          # commas, breaking the standard kwarg regex) and parse the inner
          # `key: value` pairs as filter expressions to be pushed into the
          # rendered partial's context.
          @locals = {} of String => Marten::Template::FilterExpression
          kwargs_source = kwargs_source_parts.join(' ')
          kwargs_source = extract_locals(kwargs_source)

          @kwargs = {} of String => Marten::Template::FilterExpression
          extract_kwargs(kwargs_source).each do |key, value|
            @kwargs[key] = Marten::Template::FilterExpression.new(value)
          end
        end

        def render(context : Marten::Template::Context) : String
          action = @action_filter.resolve(context).to_s
          content = if turbo_stream_nodes = @turbo_stream_nodes
                      turbo_stream_nodes.render(context)
                    end

          template = nil

          @kwargs.each do |param_name, param_expression|
            # `template:` and its alias `partial:` accept a template name to
            # render as the stream's content. `partial:` is the preferred form
            # (matching turbo-rails), but `template:` is kept for backwards
            # compatibility.
            if param_name == "template" || param_name == "partial"
              raw_param_value = param_expression.resolve(context).raw

              unless raw_param_value.is_a?(String)
                raise Marten::Template::Errors::UnsupportedValue.new(
                  "Template name must resolve to a string, git a #{raw_param_value.class} instead."
                )
              end

              template = Marten.templates.get_template(raw_param_value)
              next
            end

            raw_param_value = param_expression.resolve(context).raw

            # Ensure that the raw param value can be used as an URL parameter.
            unless raw_param_value.is_a?(Marten::Routing::Parameter::Types)
              raise Marten::Template::Errors::UnsupportedType.new(
                "#{raw_param_value.class} objects cannot be used as URL parameters"
              )
            end
          end

          if template
            # Render the resolved template inside a stacked context so that
            # any variables provided via `locals: {...}` are exposed to it
            # without polluting the outer context.
            context.stack do |partial_context|
              @locals.each do |name, expression|
                partial_context[name] = expression.resolve(context)
              end

              content = template.render(partial_context)
            end
          end

          if action == "refresh"
            return MartenTurbo::TurboStream.refresh.to_s
          end

          target = @target_id
          if target.nil?
            raise Marten::Template::Errors::InvalidSyntax.new(
              "Malformed turbo_stream tag: you must define an action and a target id"
            )
          end

          target_value = target.resolve(context)
          MartenTurbo::TurboStream.action(action, dom_id(target_value.raw), content).to_s
        end

        # Extracts a `locals: {...}` hash literal from `source`, populating
        # `@locals` with the inner `key: value` pairs and returning `source`
        # with the `locals:` portion removed (so it does not interfere with
        # the standard kwargs extraction, which can't cope with the hash's
        # inner commas).
        private def extract_locals(source : String) : String
          match = source.match(LOCALS_RE)
          return source unless match

          inner = match["body"]
          inner.scan(LOCAL_PAIR_RE) do |m|
            name = m["name"]
            value = m["value"].strip.chomp(',').strip
            @locals[name] = Marten::Template::FilterExpression.new(value)
          end

          # Strip the `locals: {...}` segment from the source so that it does
          # not get fed into `extract_kwargs`.
          source.sub(match[0], "").strip
        end

        private LOCALS_RE = /locals\s*:\s*\{(?<body>[^{}]*)\}/

        private LOCAL_PAIR_RE = /
          (?<name>\w+)\s*:\s*(?<value>
            (?:
              [^\s'",]*
              (?:
                (?:"(?:[^"\\]|\\.)*" | '(?:[^'\\]|\\.)*')
                [^\s'",]*
              )+
            )
            | [^,]+
          )\s*,?
        /x
      end
    end
  end
end
