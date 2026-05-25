# spec/marten_turbo/handlers/concerns/streamable_spec.cr
require "../spec_helper"

describe MartenTurbo::Handlers::Concerns::Streamable do
  describe "#turbo_stream" do
    it "can render a template" do
      request = Marten::HTTP::Request.new(
        ::HTTP::Request.new(
          method: "POST",
          resource: "",
          headers: HTTP::Headers{
            "Host"         => "example.com",
            "Content-Type" => "application/x-www-form-urlencoded",
            "Accept"       => "text/vnd.turbo-stream.html",
          },
          body: "name=new-turbo-tag"
        )
      )
      handler = MartenTurbo::Handlers::Concerns::StreamableSpec::TurboTemplateHandler.new(request)

      response = handler.post

      response.content_type.should eq "text/vnd.turbo-stream.html"
      response.content.strip.should contain %(<turbo-stream action="append" target="tags">)
    end

    it "can render a MartenTurbo::TurboStream" do
      request = Marten::HTTP::Request.new(
        ::HTTP::Request.new(
          method: "POST",
          resource: "",
          headers: HTTP::Headers{
            "Host"         => "example.com",
            "Content-Type" => "application/x-www-form-urlencoded",
            "Accept"       => "text/vnd.turbo-stream.html",
          },
          body: "name=new-turbo-tag"
        )
      )
      handler = MartenTurbo::Handlers::Concerns::StreamableSpec::TurboStreamHandler.new(request)

      response = handler.post

      response.content_type.should eq "text/vnd.turbo-stream.html"
      response.content.strip.should contain %(<turbo-stream action="remove" target="tag_1">)
    end

    it "accepts a block to create the turbo stream" do
      request = Marten::HTTP::Request.new(
        ::HTTP::Request.new(
          method: "POST",
          resource: "",
          headers: HTTP::Headers{
            "Host"         => "example.com",
            "Content-Type" => "application/x-www-form-urlencoded",
            "Accept"       => "text/vnd.turbo-stream.html",
          },
          body: "name=new-turbo-tag"
        )
      )
      handler = MartenTurbo::Handlers::Concerns::StreamableSpec::TurboStreamYieldHandler.new(request)

      response = handler.post

      response.content_type.should eq "text/vnd.turbo-stream.html"
      response.content.strip.should contain %(<turbo-stream action="remove" target="tag_1">)
    end

    it "can set a custom status" do
      request = Marten::HTTP::Request.new(
        ::HTTP::Request.new(
          method: "POST",
          resource: "",
          headers: HTTP::Headers{
            "Host"         => "example.com",
            "Content-Type" => "application/x-www-form-urlencoded",
            "Accept"       => "text/vnd.turbo-stream.html",
          },
          body: "name=new-turbo-tag"
        )
      )
      handler = MartenTurbo::Handlers::Concerns::StreamableSpec::TurboStreamStatusCodeHandler.new(request)

      response = handler.post

      response.content_type.should eq "text/vnd.turbo-stream.html"
      response.content.strip.should contain %(<turbo-stream action="remove" target="tag_1">)
      response.status.should eq 418
    end
  end

  describe "#turbo_frame_replace" do
    it "renders the partial wrapped in a replace turbo-stream" do
      request = Marten::HTTP::Request.new(
        ::HTTP::Request.new(
          method: "POST",
          resource: "",
          headers: HTTP::Headers{
            "Host"         => "example.com",
            "Content-Type" => "application/x-www-form-urlencoded",
            "Accept"       => "text/vnd.turbo-stream.html",
          },
          body: "name=new-turbo-tag"
        )
      )
      handler = MartenTurbo::Handlers::Concerns::StreamableSpec::TurboFrameReplaceHandler.new(request)

      response = handler.post

      response.status.should eq 200
      response.content_type.should eq "text/vnd.turbo-stream.html"
      response.content.should contain %(<turbo-stream action="replace" target="tag_42">)
      response.content.should contain %(<template>)
      response.content.should contain %(id="tag_42-body")
      response.content.should contain "hello-from-locals"
    end

    it "exposes the handler to the rendered partial so {% csrf_input %} works" do
      request = Marten::HTTP::Request.new(
        ::HTTP::Request.new(
          method: "POST",
          resource: "",
          headers: HTTP::Headers{
            "Host"         => "example.com",
            "Content-Type" => "application/x-www-form-urlencoded",
            "Accept"       => "text/vnd.turbo-stream.html",
          },
          body: "name=new-turbo-tag"
        )
      )
      handler = MartenTurbo::Handlers::Concerns::StreamableSpec::TurboFrameReplaceHandler.new(request)

      response = handler.post

      response.content.should contain %(name="csrftoken")
    end

    it "supports a custom status" do
      request = Marten::HTTP::Request.new(
        ::HTTP::Request.new(
          method: "POST",
          resource: "",
          headers: HTTP::Headers{
            "Host"         => "example.com",
            "Content-Type" => "application/x-www-form-urlencoded",
            "Accept"       => "text/vnd.turbo-stream.html",
          },
          body: "name=new-turbo-tag"
        )
      )
      handler = MartenTurbo::Handlers::Concerns::StreamableSpec::TurboFrameReplaceStatusHandler.new(request)

      response = handler.post

      response.status.should eq 422
      response.content_type.should eq "text/vnd.turbo-stream.html"
      response.content.should contain %(<turbo-stream action="replace" target="tag_42">)
    end
  end
end

module MartenTurbo::Handlers::Concerns::StreamableSpec
  class TurboTemplateHandler < Marten::Handler
    include MartenTurbo::Handlers::Concerns::Streamable

    def post
      turbo_stream("tags/create.turbo_stream.html")
    end
  end

  class TurboStreamHandler < Marten::Handler
    include MartenTurbo::Handlers::Concerns::Streamable

    def post
      turbo_stream(TurboStream.remove("tag_1"))
    end
  end

  class TurboStreamStatusCodeHandler < Marten::Handler
    include MartenTurbo::Handlers::Concerns::Streamable

    def post
      turbo_stream(TurboStream.remove("tag_1"), 418)
    end
  end

  class TurboStreamYieldHandler < Marten::Handler
    include MartenTurbo::Handlers::Concerns::Streamable

    def post
      turbo_stream do
        remove("tag_1")
      end
    end
  end

  class TurboFrameReplaceHandler < Marten::Handler
    include MartenTurbo::Handlers::Concerns::Streamable

    def post
      turbo_frame_replace(
        "tag_42",
        partial: "tags/_tag_frame.html",
        locals: {tag_id: "tag_42", tag_name: "hello-from-locals"},
      )
    end
  end

  class TurboFrameReplaceStatusHandler < Marten::Handler
    include MartenTurbo::Handlers::Concerns::Streamable

    def post
      turbo_frame_replace(
        "tag_42",
        partial: "tags/_tag_frame.html",
        locals: {tag_id: "tag_42", tag_name: "x"},
        status: 422,
      )
    end
  end
end
