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
    expect_raises(Marten::Template::Errors::InvalidSyntax, /expected the stream name as the first argument/) do
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

  it "binds the signature to a scope when scope: is provided" do
    template = Marten::Template::Template.new(%({% turbo_stream_from "messages" scope: scope_value %}))
    context = Marten::Template::Context.from({"scope_value" => "user-42"})
    rendered = template.render(context)

    match = rendered.match!(/signed-stream-name="([^"]+)"/)
    signed = match[1]

    # Verifies only under the same scope; cross-scope and unscoped verify must fail.
    MartenTurbo::Verifier.verify(signed, scope: "user-42").should eq("messages")
    MartenTurbo::Verifier.verify(signed, scope: "user-43").should be_nil
    MartenTurbo::Verifier.verify(signed).should be_nil
  end

  it "raises on unknown kwargs" do
    expect_raises(Marten::Template::Errors::InvalidSyntax, /unknown kwarg/) do
      Marten::Template::Template.new(%({% turbo_stream_from "messages" foo: "bar" %}))
    end
  end
end
