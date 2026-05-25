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

          # Phase 2 (dot-syntax follow-up): formally deprecate the undocumented
          # `{% turbo_stream.append "tags" … %}` form. Prior to Phase 1's
          # H4 ACTIONS-whitelist enforcement, this form silently mis-parsed —
          # `"tags"` was treated as the *action*, the action method (`.append`)
          # was ignored, and the resulting `<turbo-stream action="tags">` was
          # invalid markup. Reject explicitly with a clear migration message
          # so users don't think the dot-syntax is supported.
          if parts.first?.try(&.includes?('.'))
            raise Marten::Template::Errors::InvalidSyntax.new(
              "Dot-syntax `turbo_stream.<action>` is not supported (and was silently " \
              "broken in earlier versions). Use `{% turbo_stream \"<action>\" \"<target>\" %}` " \
              "instead — for example `{% turbo_stream \"append\" \"tags\" %}`."
            )
          end

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
            # Drop only the trailing "do"; everything from the target onward
            # is kwarg source. (Earlier `parts[2...-2]` used an exclusive
            # range and silently dropped the last kwarg's value.)
            kwargs_source_parts = parts[2..-2]
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
                  "Template name must resolve to a string, got a #{raw_param_value.class} instead."
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
        # with the `locals:` segment removed (so it does not interfere with
        # the standard kwargs extraction, which can't cope with the hash's
        # inner commas).
        #
        # Phase 2 M7: was a single regex (`/locals\s*:\s*\{(?<body>[^{}]*)\}/`)
        # that silently mis-parsed *any* nested `{}` — `locals: {meta: {extra: 1}}`
        # captured only `meta: ` and treated the rest as outer-kwargs source,
        # producing nonsense. The replacement is a small brace- and quote-
        # aware scanner: find the `locals:` keyword, walk from the opening
        # `{` until the matching close brace (incrementing/decrementing depth
        # outside of `"..."`/`'...'`), and split the inner body on commas
        # *also* outside of quotes/braces. The result handles nested hashes
        # and string values containing `}`.
        private def extract_locals(source : String) : String
          start_index = locate_locals_keyword(source)
          return source unless start_index

          # Skip "locals", colon, optional whitespace, opening brace.
          cursor = start_index + "locals".size
          while cursor < source.size && source[cursor].ascii_whitespace?
            cursor += 1
          end
          return source unless cursor < source.size && source[cursor] == ':'
          cursor += 1
          while cursor < source.size && source[cursor].ascii_whitespace?
            cursor += 1
          end
          return source unless cursor < source.size && source[cursor] == '{'

          open_brace = cursor
          close_brace = matching_close_brace(source, open_brace)
          if close_brace.nil?
            raise Marten::Template::Errors::InvalidSyntax.new(
              "Malformed turbo_stream tag: unterminated `locals: { ... }` hash literal."
            )
          end

          inner = source[(open_brace + 1)...close_brace]
          parse_locals_pairs(inner)

          # Strip the entire `locals: {...}` slice from the source so that it
          # does not get fed into `extract_kwargs`.
          before = source[0...start_index]
          after = source[(close_brace + 1)..]
          "#{before}#{after}".strip
        end

        # Returns the byte index of the start of a top-level `locals` keyword
        # (the one outside any string literal or hash) in `source`, or nil.
        private def locate_locals_keyword(source : String) : Int32?
          in_double = false
          in_single = false
          depth = 0
          i = 0
          while i < source.size
            c = source[i]
            if in_double
              in_double = false if c == '"' && (i == 0 || source[i - 1] != '\\')
            elsif in_single
              in_single = false if c == '\'' && (i == 0 || source[i - 1] != '\\')
            else
              case c
              when '"'  then in_double = true
              when '\'' then in_single = true
              when '{'  then depth += 1
              when '}'  then depth -= 1
              else
                if depth == 0 && c == 'l' && source[i, 6]? == "locals" &&
                   (i == 0 || !source[i - 1].ascii_alphanumeric?)
                  return i
                end
              end
            end
            i += 1
          end
          nil
        end

        # Given a `{` at `open_brace`, returns the matching close-`}` index or
        # nil if unbalanced. Tracks nesting and ignores braces inside `"…"` /
        # `'…'` string literals.
        private def matching_close_brace(source : String, open_brace : Int32) : Int32?
          depth = 0
          in_double = false
          in_single = false
          i = open_brace
          while i < source.size
            c = source[i]
            if in_double
              in_double = false if c == '"' && source[i - 1] != '\\'
            elsif in_single
              in_single = false if c == '\'' && source[i - 1] != '\\'
            else
              case c
              when '"'
                in_double = true
              when '\''
                in_single = true
              when '{'
                depth += 1
              when '}'
                depth -= 1
                return i if depth == 0
              end
            end
            i += 1
          end
          nil
        end

        # Splits `inner` (the body between the outer `{` and `}`) on commas
        # at brace/quote depth 0, then for each `key: value` pair registers a
        # `FilterExpression` against `@locals`. Nested `{}` and quoted commas
        # are left intact in the value.
        private def parse_locals_pairs(inner : String) : Nil
          pairs = [] of String
          buf = String::Builder.new
          depth = 0
          in_double = false
          in_single = false
          i = 0
          while i < inner.size
            c = inner[i]
            if in_double
              buf << c
              in_double = false if c == '"' && inner[i - 1] != '\\'
            elsif in_single
              buf << c
              in_single = false if c == '\'' && inner[i - 1] != '\\'
            else
              case c
              when '"'
                in_double = true
                buf << c
              when '\''
                in_single = true
                buf << c
              when '{'
                depth += 1
                buf << c
              when '}'
                depth -= 1
                buf << c
              when ','
                if depth == 0
                  pairs << buf.to_s
                  buf = String::Builder.new
                else
                  buf << c
                end
              else
                buf << c
              end
            end
            i += 1
          end
          last = buf.to_s
          pairs << last unless last.strip.empty?

          pairs.each do |pair|
            name, sep, value = pair.partition(':')
            next if sep.empty?
            key = name.strip
            next if key.empty?
            @locals[key] = Marten::Template::FilterExpression.new(value.strip)
          end
        end
      end
    end
  end
end
