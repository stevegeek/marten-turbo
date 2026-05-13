require "../../spec_helper"

describe MartenTurbo::Template::Tag::TurboPageRequiresReload do
  describe "#render" do
    it "emits the visit-control reload meta tag" do
      parser = Marten::Template::Parser.new("")
      tag = MartenTurbo::Template::Tag::TurboPageRequiresReload.new(parser, "turbo_page_requires_reload")

      tag.render(Marten::Template::Context.new).should eq(
        %(<meta name="turbo-visit-control" content="reload">)
      )
    end

    it "rejects any argument" do
      parser = Marten::Template::Parser.new("")
      expect_raises(
        Marten::Template::Errors::InvalidSyntax,
        /no arguments expected/
      ) do
        MartenTurbo::Template::Tag::TurboPageRequiresReload.new(parser, %(turbo_page_requires_reload "extra"))
      end
    end
  end

  describe "rendered via {% turbo_page_requires_reload %}" do
    it "round-trips through the template engine" do
      template = Marten::Template::Template.new("{% turbo_page_requires_reload %}")
      template.render(Marten::Template::Context.new).should eq(
        %(<meta name="turbo-visit-control" content="reload">)
      )
    end
  end
end

describe MartenTurbo::Template::Tag::TurboExemptsPageFromCache do
  it "emits the cache-control no-cache meta tag" do
    parser = Marten::Template::Parser.new("")
    tag = MartenTurbo::Template::Tag::TurboExemptsPageFromCache.new(parser, "turbo_exempts_page_from_cache")

    tag.render(Marten::Template::Context.new).should eq(
      %(<meta name="turbo-cache-control" content="no-cache">)
    )
  end

  it "round-trips through the template engine" do
    template = Marten::Template::Template.new("{% turbo_exempts_page_from_cache %}")
    template.render(Marten::Template::Context.new).should eq(
      %(<meta name="turbo-cache-control" content="no-cache">)
    )
  end
end

describe MartenTurbo::Template::Tag::TurboExemptsPageFromPreview do
  it "emits the cache-control no-preview meta tag" do
    parser = Marten::Template::Parser.new("")
    tag = MartenTurbo::Template::Tag::TurboExemptsPageFromPreview.new(parser, "turbo_exempts_page_from_preview")

    tag.render(Marten::Template::Context.new).should eq(
      %(<meta name="turbo-cache-control" content="no-preview">)
    )
  end

  it "round-trips through the template engine" do
    template = Marten::Template::Template.new("{% turbo_exempts_page_from_preview %}")
    template.render(Marten::Template::Context.new).should eq(
      %(<meta name="turbo-cache-control" content="no-preview">)
    )
  end
end
