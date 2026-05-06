require "../spec_helper"

describe "{% turbo_stream_from %}" do
  it "renders a <turbo-cable-stream-source> element with a signed stream name" do
    template = Marten::Template::Template.new(%({% turbo_stream_from "messages" %}))
    rendered = template.render(Marten::Template::Context.new)

    rendered.should contain(%(<turbo-cable-stream-source ))
    rendered.should contain(%(channel="MartenTurbo::StreamsChannel"))
    rendered.should contain(%(signed-stream-name="))
    rendered.should contain(%(</turbo-cable-stream-source>))
  end

  it "the emitted signed-stream-name verifies back to the original" do
    template = Marten::Template::Template.new(%({% turbo_stream_from "lobby_room" %}))
    rendered = template.render(Marten::Template::Context.new)

    match = rendered.match!(/signed-stream-name="([^"]+)"/)
    signed = match[1]
    MartenTurbo::Verifier.verify(signed).should eq("lobby_room")
  end

  it "raises on missing argument" do
    expect_raises(Marten::Template::Errors::InvalidSyntax, /expected exactly one argument/) do
      Marten::Template::Template.new(%({% turbo_stream_from %}))
    end
  end

  it "accepts a variable as the stream name" do
    template = Marten::Template::Template.new(%({% turbo_stream_from name %}))
    context = Marten::Template::Context.from({"name" => "from_var"})
    rendered = template.render(context)

    match = rendered.match!(/signed-stream-name="([^"]+)"/)
    MartenTurbo::Verifier.verify(match[1]).should eq("from_var")
  end
end
