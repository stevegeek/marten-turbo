require "../../spec_helper"

describe MartenTurbo::Template::Tag::TurboFrame do
  describe "::new" do
    it "raises if the turbo_frame tag does not define an identifier" do
      parser = Marten::Template::Parser.new(
        "<p>Test</p>{% end_turbo_frame %}"
      )

      expect_raises(
        Marten::Template::Errors::InvalidSyntax,
        "Malformed turbo_frame tag: you must define an identifier"
      ) do
        MartenTurbo::Template::Tag::TurboFrame.new(parser, "turbo_frame")
      end
    end
  end

  describe "#render" do
    it "properly renders a turbo-frame tag with the correct identifier and body" do
      parser = Marten::Template::Parser.new("<p>Test</p>{% end_turbo_frame %}")
      tag = MartenTurbo::Template::Tag::TurboFrame.new(parser, "turbo_frame 'tasks'")

      tag.render(Marten::Template::Context.new).should contain %(<turbo-frame id="tasks">)
    end

    it "properly renders a turbo-frame tag with additional attributes" do
      parser = Marten::Template::Parser.new("<p>Test</p>{% end_turbo_frame %}")
      tag = MartenTurbo::Template::Tag::TurboFrame.new(
        parser,
        "turbo_frame 'tasks' src: 'some/path', loading: 'lazy'"
      )

      content = tag.render(Marten::Template::Context.new)

      content.should contain %(<turbo-frame id="tasks" src="some/path" loading="lazy">)
    end

    it "properly renders a turbo-frame tag with a dynamic identifier when given a Marten::Model" do
      tag_model = Tag.create!(name: "Marten Turbo")

      parser = Marten::Template::Parser.new("<p>Test</p>{% end_turbo_frame %}")
      template_tag = MartenTurbo::Template::Tag::TurboFrame.new(
        parser,
        "turbo_frame tag src: 'some/path', loading: 'lazy'"
      )

      context = Marten::Template::Context{"tag" => tag_model}

      content = template_tag.render(context)

      content.should contain %(<turbo-frame id="tag_#{tag_model.pk!}" src="some/path" loading="lazy">)
    end

    it "properly returns the body content within the turbo-frame tag" do
      parser = Marten::Template::Parser.new("<div>Body Content</div>{% end_turbo_frame %}")
      tag = MartenTurbo::Template::Tag::TurboFrame.new(parser, "turbo_frame 'body_test'")

      content = tag.render(Marten::Template::Context.new)

      content.should contain "<div>Body Content</div>"
    end

    # H3 regression: kwarg values were raw-interpolated into double-quoted HTML
    # attributes. A value containing `"` (or `"><script>…`) broke out of the
    # attribute and let user-influenced context strings inject HTML / JS.
    it "HTML-escapes the value of a src kwarg" do
      parser = Marten::Template::Parser.new("<p>x</p>{% end_turbo_frame %}")
      tag = MartenTurbo::Template::Tag::TurboFrame.new(parser, "turbo_frame 'tasks' src: src")

      context = Marten::Template::Context{"src" => %(" onload="alert(1))}
      content = tag.render(context)

      content.should contain "&quot;"
      content.should_not contain %(onload=")
      content.should_not contain %(src="" onload)
    end

    it "HTML-escapes the value of a data-turbo-action kwarg" do
      parser = Marten::Template::Parser.new("<p>x</p>{% end_turbo_frame %}")
      tag = MartenTurbo::Template::Tag::TurboFrame.new(
        parser,
        "turbo_frame 'tasks' data-turbo-action: action_value"
      )

      context = Marten::Template::Context{"action_value" => %(advance"><script>alert(1)</script>)}
      content = tag.render(context)

      content.should contain "&quot;"
      content.should contain "&lt;script&gt;"
      content.should_not contain "<script>alert(1)</script>"
    end

    it "HTML-escapes the value of a custom data attribute" do
      parser = Marten::Template::Parser.new("<p>x</p>{% end_turbo_frame %}")
      tag = MartenTurbo::Template::Tag::TurboFrame.new(
        parser,
        "turbo_frame 'tasks' data-controller: controller_name"
      )

      context = Marten::Template::Context{"controller_name" => %(c" onmouseover="x())}
      content = tag.render(context)

      content.should contain "&quot;"
      content.should_not contain %(onmouseover=")
    end

    it "HTML-escapes the dom_id when the identifier resolves to a string with quotes" do
      parser = Marten::Template::Parser.new("<p>x</p>{% end_turbo_frame %}")
      tag = MartenTurbo::Template::Tag::TurboFrame.new(parser, "turbo_frame ident")

      context = Marten::Template::Context{"ident" => %(foo" onload="alert(1))}
      content = tag.render(context)

      content.should contain "&quot;"
      content.should_not contain %(id="foo" onload=")
    end
  end
end
