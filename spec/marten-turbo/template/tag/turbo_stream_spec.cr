require "../../spec_helper"

describe MartenTurbo::Template::Tag::TurboStream do
  describe "::new" do
    # Phase 2 (dot-syntax follow-up): the undocumented
    # `{% turbo_stream.append "tags" %}` form silently mis-parsed before
    # Phase 1 (it treated `"tags"` as the *action* and ignored `.append`).
    # Phase 1's ACTIONS whitelist would have caught it at render time as
    # "Unknown Turbo Stream action: tags", but the parser-level rejection
    # is clearer.
    it "rejects the deprecated dot-syntax with a migration message" do
      parser = Marten::Template::Parser.new("")

      expect_raises(
        Marten::Template::Errors::InvalidSyntax,
        /Dot-syntax .* is not supported.*Use `\{% turbo_stream/
      ) do
        MartenTurbo::Template::Tag::TurboStream.new(parser, "turbo_stream.append \"tags\"")
      end
    end

    it "raises if turbo_stream does not define an action" do
      parser = Marten::Template::Parser.new("")

      expect_raises(
        Marten::Template::Errors::InvalidSyntax,
        "Malformed turbo_stream tag: you must define an action"
      ) do
        MartenTurbo::Template::Tag::TurboStream.new(parser, "turbo_stream")
      end
    end

    it "raises at render time if a non-refresh action is used without a target_id" do
      parser = Marten::Template::Parser.new("{% turbo_stream 'append' %}")
      tag = MartenTurbo::Template::Tag::TurboStream.new(parser, "turbo_stream 'append'")

      expect_raises(
        Marten::Template::Errors::InvalidSyntax,
        "Malformed turbo_stream tag: you must define an action and a target id"
      ) do
        tag.render(Marten::Template::Context.new)
      end
    end

    it "raises if turbo_stream block is not closed when 'do' is present at the end" do
      parser = Marten::Template::Parser.new(
        <<-TEMPLATE
          <p>some content</p>
          TEMPLATE
      )

      expect_raises(
        Marten::Template::Errors::InvalidSyntax,
        "Unclosed tags, expected: end_turbo_stream"
      ) do
        MartenTurbo::Template::Tag::TurboStream.new(parser, "turbo_stream 'append' 'tags' do")
      end
    end
  end

  describe "#render" do
    it "properly renders a turbo-stream tag with the correct action and target" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboStream.new(parser, "turbo_stream 'remove' 'my-id'")

      content = tag.render(Marten::Template::Context.new)
      content.should contain "<turbo-stream action=\"remove\" target=\"my-id\">"
      content.should_not contain "<template>"
    end

    it "properly renders a turbo-stream tag with the correct action and target when given a Marten::Model" do
      tag_model = Tag.create!(name: "Marten Turbo")

      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboStream.new(parser, "turbo_stream 'remove' tag")

      context = Marten::Template::Context{"tag" => tag_model}

      tag.render(context).should contain "<turbo-stream action=\"remove\" target=\"tag_#{tag_model.pk!}\">"
    end

    it "properly renders a turbo-stream tag with correct specified template" do
      # Updated for H4: the old `turbo_stream.append "tags" template: …` dot-syntax
      # form passed `"tags"` as the action (and silently produced
      # `<turbo-stream action="tags" target="">`); ACTIONS validation now catches
      # that. The supported form is `turbo_stream "<action>" "<target>" …`,
      # matching the README and the other specs in this file.
      tag_model = Tag.create!(name: "Marten Turbo")

      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboStream.new(
        parser,
        "turbo_stream \"append\" \"tags\" template: \"tags/tag.html\""
      )

      context = Marten::Template::Context{"tag" => tag_model}

      content = tag.render(context)
      content.should contain "<div class=\"tag_#{tag_model.pk}\">"
      content.should contain "Marten Turbo"
    end

    it "raises if the specified template could not be found" do
      tag_model = Tag.create!(name: "Marten Turbo")

      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboStream.new(
        parser,
        "turbo_stream \"append\" \"tags\" template: \"tags/not_existing_tag.html\""
      )

      context = Marten::Template::Context{"tag" => tag_model}

      expect_raises(
        Marten::Template::Errors::TemplateNotFound,
        "Template tags/not_existing_tag.html could not be found"
      ) do
        tag.render(context)
      end
    end

    it "raises if the specified template value is not a string" do
      tag_model = Tag.create!(name: "Marten Turbo")

      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboStream.new(
        parser,
        "turbo_stream \"append\" \"tags\" template: 1"
      )

      context = Marten::Template::Context{"tag" => tag_model}

      expect_raises(
        Marten::Template::Errors::UnsupportedValue,
        "Template name must resolve to a string, got a Int32 instead."
      ) do
        tag.render(context)
      end
    end

    it "properly renders a turbo_stream block if 'do' is present as last argument" do
      parser = Marten::Template::Parser.new(
        <<-TEMPLATE
          <p>some content</p>
          {% end_turbo_stream %}
          TEMPLATE
      )
      tag = MartenTurbo::Template::Tag::TurboStream.new(parser, "turbo_stream 'append' 'tags' do")

      tag.render(Marten::Template::Context.new).should contain "<p>some content</p>"
    end

    it "properly renders a refresh action without a target" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboStream.new(parser, "turbo_stream 'refresh'")

      tag.render(Marten::Template::Context.new).should eq %(<turbo-stream action="refresh"></turbo-stream>)
    end

    it "properly renders a refresh action when the action expression resolves to 'refresh' at render time" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboStream.new(parser, "turbo_stream stream_action")

      context = Marten::Template::Context{"stream_action" => "refresh"}

      tag.render(context).should eq %(<turbo-stream action="refresh"></turbo-stream>)
    end

    it "renders a partial through the partial: kwarg as an alias for template:" do
      tag_model = Tag.create!(name: "Marten Turbo")

      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboStream.new(
        parser,
        "turbo_stream \"replace\" \"tags\" partial: \"tags/tag.html\""
      )

      context = Marten::Template::Context{"tag" => tag_model}

      content = tag.render(context)
      content.should contain "<turbo-stream action=\"replace\" target=\"tags\">"
      content.should contain "<div class=\"tag_#{tag_model.pk}\">"
      content.should contain "Marten Turbo"
    end

    it "exposes locals: variables to the rendered partial" do
      other_tag = Tag.create!(name: "Other Tag")

      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboStream.new(
        parser,
        "turbo_stream \"replace\" \"tags\" partial: \"tags/tag.html\" locals: {tag: other_tag}"
      )

      context = Marten::Template::Context{"other_tag" => other_tag}

      content = tag.render(context)
      content.should contain "<div class=\"tag_#{other_tag.pk}\">"
      content.should contain "Other Tag"
    end

    # H4 regression: an unknown action used to flow straight through to the
    # `action="…"` attribute, letting `{% turbo_stream 'evil"><script>' x %}`
    # inject HTML.
    it "raises InvalidActionError when the template tag is rendered with an unknown action" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboStream.new(parser, "turbo_stream 'evil' 'tag'")

      expect_raises(MartenTurbo::InvalidActionError, /Unknown Turbo Stream action/) do
        tag.render(Marten::Template::Context.new)
      end
    end

    it "HTML-escapes a target value rendered through the template tag" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboStream.new(parser, "turbo_stream 'append' target_value")

      context = Marten::Template::Context{"target_value" => %(tag" onclick="alert(1))}
      content = tag.render(context)

      content.should contain "&quot;"
      content.should_not contain %(onclick="alert(1)")
    end

    # Phase 2 M7: the original `LOCALS_RE` regex (`[^{}]*`) silently
    # mis-parsed *any* nested `{}` — `locals: {tag: other_tag, body: "}"}`
    # captured only up to the first `}` inside the string and treated the
    # remainder as outer-kwargs source. The replacement scanner walks
    # brace depth while ignoring `{` / `}` inside `"…"` / `'…'`, so a value
    # containing a literal `}` round-trips. (Hash-literal values themselves
    # are still rejected by Marten's `FilterExpression` parser — that's a
    # template-engine constraint, not a parser-scanner bug.)
    it "tolerates a string `locals:` value containing a `}` (M7 brace-scanner)" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboStream.new(
        parser,
        %(turbo_stream "replace" "tags" partial: "tags/tag.html" locals: {tag: other_tag, json: "}"})
      )

      other_tag = Tag.create!(name: "Closer")
      context = Marten::Template::Context{"other_tag" => other_tag}

      content = tag.render(context)
      content.should contain "<div class=\"tag_#{other_tag.pk}\">"
      content.should contain "Closer"
    end

    it "raises a clear error when the `locals:` hash literal is unterminated" do
      parser = Marten::Template::Parser.new("")

      expect_raises(
        Marten::Template::Errors::InvalidSyntax,
        /unterminated `locals:.*hash literal/i
      ) do
        MartenTurbo::Template::Tag::TurboStream.new(
          parser,
          %(turbo_stream "replace" "tags" partial: "tags/tag.html" locals: {tag: other_tag, extra: 1)
        )
      end
    end

    it "preserves the last kwarg's value when do-block + kwargs combine" do
      # Regression: a previous `parts[2...-2]` exclusive-range slice
      # silently dropped the value of the last kwarg in the do-block
      # branch (`partial: "tags/tag.html" do %}...` saw `partial:` with
      # no value, leading to no rendered partial).
      other_tag = Tag.create!(name: "Combo Tag")

      source = String.build do |io|
        io << %({% turbo_stream "replace" "tags" )
        io << %(partial: "tags/tag.html" locals: {tag: other_tag} do %})
        io << %(IGNORED)
        io << %({% end_turbo_stream %})
      end
      template = Marten::Template::Template.new(source)

      context = Marten::Template::Context{"other_tag" => other_tag}

      content = template.render(context)
      content.should contain %(<turbo-stream action="replace" target="tags">)
      content.should contain %(<div class="tag_#{other_tag.pk}">)
      content.should contain "Combo Tag"
    end
  end
end
