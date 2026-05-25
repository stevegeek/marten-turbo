require "./spec_helper"

describe MartenTurbo::TurboStream do
  describe "::new" do
    it "initializes with an empty streams array" do
      stream = MartenTurbo::TurboStream.new
      stream.to_s.should eq ""
    end

    it "accepts a block to initialize the stream" do
      stream = MartenTurbo::TurboStream.new do
        append("messages", "<div>Message 1</div>")
      end

      stream.to_s.should contain "<turbo-stream action=\"append\" target=\"messages\">"
      stream.to_s.should contain "<div>Message 1</div>"
      stream.to_s.should contain "</turbo-stream>"
    end
  end

  describe "#append" do
    it "adds an append action to the streams" do
      stream = MartenTurbo::TurboStream.new
      stream.append("messages", "<div>Message 1</div>")
      stream.to_s.should contain "<turbo-stream action=\"append\" target=\"messages\">"
      stream.to_s.should contain "<div>Message 1</div>"
      stream.to_s.should contain "</turbo-stream>"
    end
  end

  describe "#prepend" do
    it "adds a prepend action to the streams" do
      stream = MartenTurbo::TurboStream.new
      stream.prepend("messages", "<div>Message 2</div>")

      stream.to_s.should contain "<turbo-stream action=\"prepend\" target=\"messages\">"
      stream.to_s.should contain "<div>Message 2</div>"
      stream.to_s.should contain "</turbo-stream>"
    end
  end

  describe "#replace" do
    it "adds a replace action to the streams" do
      stream = MartenTurbo::TurboStream.new
      stream.replace("message_1", "<div>Updated Message 1</div>")

      stream.to_s.should contain "<turbo-stream action=\"replace\" target=\"message_1\">"
      stream.to_s.should contain "<div>Updated Message 1</div>"
      stream.to_s.should contain "</turbo-stream>"
    end
  end

  describe "#remove" do
    it "adds a remove action to the streams" do
      stream = MartenTurbo::TurboStream.new
      stream.remove("message_2")

      stream.to_s.should contain "<turbo-stream action=\"remove\" target=\"message_2\">"
      stream.to_s.should_not contain "<template>"
      stream.to_s.should contain "</turbo-stream>"
    end

    it "adds a remove action to the streams using a record" do
      tag = Tag.create!(name: "Tag 1")
      stream = MartenTurbo::TurboStream.new
      stream.remove(tag)

      stream.to_s.should contain "<turbo-stream action=\"remove\" target=\"tag_#{tag.pk!}\">"
      stream.to_s.should_not contain "<template>"
      stream.to_s.should contain "</turbo-stream>"
    end
  end

  describe "#refresh" do
    it "adds a refresh action to the streams with no target and no template body" do
      stream = MartenTurbo::TurboStream.new
      stream.refresh

      stream.to_s.should eq %(<turbo-stream action="refresh"></turbo-stream>)
    end
  end

  describe "Class methods" do
    it "::append returns a new TurboStream with the append action" do
      stream = MartenTurbo::TurboStream.append("messages", "<div>Message 3</div>")

      stream.to_s.should contain "<turbo-stream action=\"append\" target=\"messages\">"
      stream.to_s.should contain "<div>Message 3</div>"
      stream.to_s.should contain "</turbo-stream>"
    end

    it "::remove returns a new TurboStream with the remove action" do
      stream = MartenTurbo::TurboStream.remove("message_2")

      stream.to_s.should contain "<turbo-stream action=\"remove\" target=\"message_2\">"
      stream.to_s.should_not contain "<template>"
      stream.to_s.should contain "</turbo-stream>"
    end

    it "::remove accepts a model returns a new TurboStream with the remove action" do
      tag = Tag.create!(name: "Tag 1")
      stream = MartenTurbo::TurboStream.remove(tag)

      stream.to_s.should contain "<turbo-stream action=\"remove\" target=\"tag_#{tag.pk!}\">"
      stream.to_s.should_not contain "<template>"
      stream.to_s.should contain "</turbo-stream>"
    end

    it "::refresh returns a new TurboStream with a refresh action and no target" do
      stream = MartenTurbo::TurboStream.refresh

      stream.to_s.should eq %(<turbo-stream action="refresh"></turbo-stream>)
    end
  end

  # H4 regressions: the `ACTIONS` whitelist used to be unused at runtime, so
  # arbitrary `action=` values flowed straight into the `<turbo-stream
  # action="…">` attribute. `target_id` was likewise interpolated unescaped.
  describe "action validation and target_id escaping" do
    it "raises InvalidActionError for an unknown action" do
      expect_raises(
        MartenTurbo::InvalidActionError,
        /Unknown Turbo Stream action/
      ) do
        MartenTurbo::TurboStream.action("evil", "tag", "")
      end
    end

    it "raises InvalidActionError for an injection-shaped action string" do
      expect_raises(MartenTurbo::InvalidActionError) do
        MartenTurbo::TurboStream.action(%(evil"><script>alert(1)</script>), "tag", "")
      end
    end

    it "HTML-escapes a target_id containing a double-quote" do
      stream = MartenTurbo::TurboStream.action("append", %(tag" onclick="alert(1)), "x")

      content = stream.to_s
      content.should contain "&quot;"
      # The whole target value is wrapped in escaped quotes, so the dangerous
      # `target="..." onclick="alert(1)"` second-attribute sequence can't be
      # produced.
      content.should_not contain %(onclick="alert(1)")
    end

    it "still produces the expected element for a benign target id" do
      stream = MartenTurbo::TurboStream.action("append", "messages", "<div>hi</div>")
      stream.to_s.should contain %(<turbo-stream action="append" target="messages">)
    end
  end

  # L3: previously `to_s(io)` emitted a trailing `\n` per stream element while
  # the bare `to_s` joined streams with `\n` (no trailing). Anyone diffing the
  # two forms (e.g. wire-level assertions vs `String.build`) saw an off-by-one
  # newline. Both paths now agree.
  describe "to_s / to_s(io) consistency (L3)" do
    it "produces identical output for a single stream" do
      stream = MartenTurbo::TurboStream.append("messages", "<div>hi</div>")

      io_form = String.build { |io| stream.to_s(io) }
      io_form.should eq(stream.to_s)
    end

    it "produces identical output for multiple streams" do
      stream = MartenTurbo::TurboStream.new
        .append("messages", "<div>a</div>")
        .replace("message_1", "<div>b</div>")
        .remove("message_2")

      io_form = String.build { |io| stream.to_s(io) }
      io_form.should eq(stream.to_s)
    end

    it "produces identical output for an empty stream" do
      stream = MartenTurbo::TurboStream.new

      io_form = String.build { |io| stream.to_s(io) }
      io_form.should eq(stream.to_s)
      io_form.should eq("")
    end
  end

  # Phase 2 M5: the previous heredoc emission folded the heredoc's leading
  # indentation into `<template>` content, which would show up as visible
  # whitespace inside a `<pre>` partial. The new emission inlines the
  # `<template>` open/close around the content with no padding.
  describe "template whitespace (M5)" do
    it "does not introduce padding around <pre> content" do
      pre = "<pre>line1\nline2</pre>"
      stream = MartenTurbo::TurboStream.action("append", "messages", pre)
      stream.to_s.should contain "<template>#{pre}</template>"
    end

    it "emits a tight `<template>content</template>` wrapper" do
      stream = MartenTurbo::TurboStream.action("append", "messages", "<div>hi</div>")
      stream.to_s.should contain "<template><div>hi</div></template>"
    end
  end

  # TR3: runtime extension hook. Host apps can register custom Turbo Stream
  # action names (e.g. `morph`) without monkey-patching the ACTIONS constant.
  describe ".register_action (TR3)" do
    before_each do
      MartenTurbo::TurboStream.reset_actions_for_spec!
    end

    after_each do
      MartenTurbo::TurboStream.reset_actions_for_spec!
    end

    it "permits a registered custom action to render valid markup" do
      MartenTurbo::TurboStream.register_action("morph")

      stream = MartenTurbo::TurboStream.action("morph", "foo", "<div/>")
      stream.to_s.should contain %(<turbo-stream action="morph" target="foo">)
      stream.to_s.should contain "<template><div/></template>"
      stream.to_s.should contain "</turbo-stream>"
    end

    it "still raises InvalidActionError for an unregistered action" do
      expect_raises(MartenTurbo::InvalidActionError, /Unknown Turbo Stream action/) do
        MartenTurbo::TurboStream.action("unregistered_action", "foo", "<div/>")
      end
    end

    it "is idempotent — re-registering an existing action does not raise" do
      MartenTurbo::TurboStream.register_action("append")
      MartenTurbo::TurboStream.register_action("morph")
      MartenTurbo::TurboStream.register_action("morph")

      MartenTurbo::TurboStream.actions.should contain "morph"
      MartenTurbo::TurboStream.actions.should contain "append"
    end

    it "exposes the current action set via .actions" do
      MartenTurbo::TurboStream.actions.size.should eq MartenTurbo::TurboStream::ACTIONS.size

      MartenTurbo::TurboStream.register_action("morph")
      MartenTurbo::TurboStream.actions.should contain "morph"
    end

    it "reset_actions_for_spec! returns the set to the built-in 8" do
      MartenTurbo::TurboStream.register_action("morph")
      MartenTurbo::TurboStream.actions.should contain "morph"

      MartenTurbo::TurboStream.reset_actions_for_spec!
      MartenTurbo::TurboStream.actions.should_not contain "morph"
      MartenTurbo::TurboStream.actions.size.should eq MartenTurbo::TurboStream::ACTIONS.size
    end
  end
end
