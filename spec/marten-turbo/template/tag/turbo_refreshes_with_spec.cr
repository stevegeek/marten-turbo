require "../../spec_helper"

describe MartenTurbo::Template::Tag::TurboRefreshesWith do
  describe "#render" do
    it "emits an empty string when no kwargs are provided" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboRefreshesWith.new(parser, "turbo_refreshes_with")

      tag.render(Marten::Template::Context.new).should eq ""
    end

    it "emits an empty string when both kwargs explicitly use default values" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboRefreshesWith.new(
        parser,
        %(turbo_refreshes_with method: "replace", scroll: "reset")
      )

      tag.render(Marten::Template::Context.new).should eq ""
    end

    it "emits both meta tags when only method: is set to morph" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboRefreshesWith.new(
        parser,
        %(turbo_refreshes_with method: "morph")
      )

      content = tag.render(Marten::Template::Context.new)
      content.should contain %(<meta name="turbo-refresh-method" content="morph">)
      content.should contain %(<meta name="turbo-refresh-scroll" content="reset">)
    end

    it "emits both meta tags when only scroll: is set to preserve" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboRefreshesWith.new(
        parser,
        %(turbo_refreshes_with scroll: "preserve")
      )

      content = tag.render(Marten::Template::Context.new)
      content.should contain %(<meta name="turbo-refresh-method" content="replace">)
      content.should contain %(<meta name="turbo-refresh-scroll" content="preserve">)
    end

    it "emits both meta tags when method: and scroll: are both set" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboRefreshesWith.new(
        parser,
        %(turbo_refreshes_with method: "morph", scroll: "preserve")
      )

      content = tag.render(Marten::Template::Context.new)
      content.should eq(
        %(<meta name="turbo-refresh-method" content="morph">\n) +
        %(<meta name="turbo-refresh-scroll" content="preserve">)
      )
    end

    it "raises an UnsupportedValue error when method: is not 'morph' or 'replace'" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboRefreshesWith.new(
        parser,
        %(turbo_refreshes_with method: "bogus")
      )

      expect_raises(
        Marten::Template::Errors::UnsupportedValue,
        %(Invalid value "bogus" for turbo_refreshes_with method)
      ) do
        tag.render(Marten::Template::Context.new)
      end
    end

    it "raises an UnsupportedValue error when scroll: is not 'preserve' or 'reset'" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboRefreshesWith.new(
        parser,
        %(turbo_refreshes_with scroll: "bogus")
      )

      expect_raises(
        Marten::Template::Errors::UnsupportedValue,
        %(Invalid value "bogus" for turbo_refreshes_with scroll)
      ) do
        tag.render(Marten::Template::Context.new)
      end
    end

    it "raises an InvalidSyntax error when an unknown kwarg is provided" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboRefreshesWith.new(
        parser,
        %(turbo_refreshes_with foo: "bar")
      )

      expect_raises(
        Marten::Template::Errors::InvalidSyntax,
        %(Unknown keyword argument "foo" for turbo_refreshes_with tag)
      ) do
        tag.render(Marten::Template::Context.new)
      end
    end

    it "is registered as a template tag" do
      template = Marten::Template::Template.new(
        %({% turbo_refreshes_with method: "morph", scroll: "preserve" %})
      )

      content = template.render(Marten::Template::Context.new)
      content.should contain %(<meta name="turbo-refresh-method" content="morph">)
      content.should contain %(<meta name="turbo-refresh-scroll" content="preserve">)
    end

    it "renders nothing through the template engine when called with no kwargs" do
      template = Marten::Template::Template.new(%({% turbo_refreshes_with %}))

      template.render(Marten::Template::Context.new).should eq ""
    end
  end
end
