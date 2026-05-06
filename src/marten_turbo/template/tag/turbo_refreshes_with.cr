module MartenTurbo
  module Template
    module Tag
      class TurboRefreshesWith < Marten::Template::Tag::Base
        include Marten::Template::Tag::CanSplitSmartly
        include Marten::Template::Tag::CanExtractKwargs

        VALID_METHODS = {"morph", "replace"}
        VALID_SCROLLS = {"preserve", "reset"}

        DEFAULT_METHOD = "replace"
        DEFAULT_SCROLL = "reset"

        @kwargs : Hash(String, Marten::Template::FilterExpression)

        def initialize(parser : Marten::Template::Parser, source : String)
          parts = split_smartly(source)

          kwargs_parts = parts[1..]
          @kwargs = {} of String => Marten::Template::FilterExpression
          extract_kwargs(kwargs_parts.join(' ')).each do |key, value|
            @kwargs[key] = Marten::Template::FilterExpression.new(value)
          end
        end

        def render(context : Marten::Template::Context) : String
          method = DEFAULT_METHOD
          scroll = DEFAULT_SCROLL

          @kwargs.each do |key, expression|
            value = expression.resolve(context).to_s

            case key
            when "method"
              unless VALID_METHODS.includes?(value)
                raise Marten::Template::Errors::UnsupportedValue.new(
                  "Invalid value #{value.inspect} for turbo_refreshes_with method: " \
                  "expected one of #{VALID_METHODS.map(&.inspect).join(", ")}"
                )
              end
              method = value
            when "scroll"
              unless VALID_SCROLLS.includes?(value)
                raise Marten::Template::Errors::UnsupportedValue.new(
                  "Invalid value #{value.inspect} for turbo_refreshes_with scroll: " \
                  "expected one of #{VALID_SCROLLS.map(&.inspect).join(", ")}"
                )
              end
              scroll = value
            else
              raise Marten::Template::Errors::InvalidSyntax.new(
                "Unknown keyword argument #{key.inspect} for turbo_refreshes_with tag"
              )
            end
          end

          return "" if method == DEFAULT_METHOD && scroll == DEFAULT_SCROLL

          String.build do |io|
            io << %(<meta name="turbo-refresh-method" content=") << method << %(">)
            io << '\n'
            io << %(<meta name="turbo-refresh-scroll" content=") << scroll << %(">)
          end
        end
      end
    end
  end
end
