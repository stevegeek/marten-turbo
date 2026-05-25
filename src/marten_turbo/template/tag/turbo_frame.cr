require "html"

module MartenTurbo
  module Template
    module Tag
      class TurboFrame < Marten::Template::Tag::Base
        include Marten::Template::Tag::CanSplitSmartly
        include Marten::Template::Tag::CanExtractKwargs
        include Identifiable

        @nodes : Marten::Template::NodeSet
        @identifier_filter : Marten::Template::FilterExpression

        def initialize(parser : Marten::Template::Parser, source : String)
          parts = split_smartly(source)

          if parts.size < 2
            raise Marten::Template::Errors::InvalidSyntax.new(
              "Malformed turbo_frame tag: you must define an identifier"
            )
          end

          @identifier_filter = Marten::Template::FilterExpression.new(parts[1])

          @nodes = parser.parse(up_to: {"end_turbo_frame"})
          parser.shift_token

          kwargs_parts = parts[2..]
          @kwargs = {} of String => Marten::Template::FilterExpression
          extract_kwargs(kwargs_parts.join(' ')).each do |key, value|
            @kwargs[key] = Marten::Template::FilterExpression.new(value)
          end
        end

        def render(context : Marten::Template::Context) : String
          builder = String::Builder.new
          builder << "<turbo-frame id=\""
          # H3: HTML-escape the dom_id before interpolating into a double-quoted
          # attribute. The dom_id source value may originate from user input
          # (e.g. an unsaved model with a string PK pulled from params), so a
          # `"` in the value would otherwise break out of the attribute.
          builder << HTML.escape(dom_id(@identifier_filter.resolve(context).raw))
          builder << "\""

          @kwargs.each do |key, expression|
            value = expression.resolve(context).to_s

            unless expression.resolve(context).raw.is_a?(Marten::Routing::Parameter::Types)
              raise Marten::Template::Errors::UnsupportedType.new(
                "#{value.class} objects cannot be used as URL parameters"
              )
            end

            builder << ' '
            builder << key
            builder << "=\""
            # H3: HTML-escape every kwarg value. Without this, a `src:` value
            # containing `"` (or `"><script>…`) would break out of the
            # attribute and inject arbitrary HTML / script into the page.
            builder << HTML.escape(value)
            builder << "\""
          end

          builder << ">"
          builder << @nodes.render(context)
          builder << "</turbo-frame>"

          builder.to_s
        end
      end
    end
  end
end
