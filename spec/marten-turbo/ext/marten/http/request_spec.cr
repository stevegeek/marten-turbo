require "./spec_helper"

describe Marten::HTTP::Request do
  describe "#turbo?" do
    it "correctly returns true if the request is a turbo request" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/test/xyz",
        headers: HTTP::Headers{"Accept" => "text/vnd.turbo-stream.html"},
      )

      request.turbo?.should be_true
    end

    it "correctly returns true when the Turbo Stream MIME is one of several Accept entries" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/test/xyz",
        headers: HTTP::Headers{"Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"},
      )

      request.turbo?.should be_true
    end

    it "correctly returns false if the request is not a turbo request" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/test/xyz",
        headers: HTTP::Headers{"Accept" => "text/html"},
      )

      request.turbo?.should be_false
    end

    # Regression: prior implementation called `accepts?("text/vnd.turbo-stream.html")`,
    # which treats `*/*` as a wildcard match. Every browser sends a Accept header that
    # ends with `*/*;q=0.8`, so `turbo?` used to return true for every browser request
    # — causing the generic record handlers to render `<turbo-stream>` markup on plain
    # form POSTs instead of redirecting. The replacement reads the Accept header
    # directly and requires the exact Turbo Stream MIME to appear as a substring.
    it "returns false for a realistic browser Accept that ends in */*" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/test/xyz",
        headers: HTTP::Headers{
          "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        },
      )

      request.turbo?.should be_false
    end

    it "returns false when no Accept header is sent at all" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/test/xyz",
        headers: HTTP::Headers.new,
      )

      request.turbo?.should be_false
    end

    it "returns true when an explicit Turbo-Frame header is present even without the Turbo Accept MIME" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/test/xyz",
        headers: HTTP::Headers{
          "Accept"      => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          "Turbo-Frame" => "form",
        },
      )

      request.turbo?.should be_true
    end

    # TR1: the Turbo-Frame header is a useful signal for frame *fetches* (always
    # GET) but NOT for form submissions that originate inside a frame. A POST
    # carrying `Turbo-Frame: form` expects an HTML response — Turbo extracts the
    # matching `<turbo-frame>` from it. Routing those POSTs through the
    # turbo-stream branch produced `<turbo-stream>` markup that the frame
    # couldn't consume. The fallback is now GET-only; explicit Turbo MIME still
    # wins on any method.
    it "returns true for a frame-form GET (Turbo-Frame header + text/html)" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/test/xyz",
        headers: HTTP::Headers{
          "Accept"      => "text/html",
          "Turbo-Frame" => "foo",
        },
      )

      request.turbo?.should be_true
    end

    it "returns false for a frame-form POST (Turbo-Frame header + text/html, no Turbo MIME)" do
      request = Marten::HTTP::Request.new(
        method: "POST",
        resource: "/test/xyz",
        headers: HTTP::Headers{
          "Accept"      => "text/html",
          "Turbo-Frame" => "foo",
        },
      )

      request.turbo?.should be_false
    end

    it "returns true for a POST carrying the explicit Turbo Stream MIME even with Turbo-Frame" do
      request = Marten::HTTP::Request.new(
        method: "POST",
        resource: "/test/xyz",
        headers: HTTP::Headers{
          "Accept"      => "text/vnd.turbo-stream.html",
          "Turbo-Frame" => "foo",
        },
      )

      request.turbo?.should be_true
    end

    it "returns true for a GET frame-fetch with `*/*` Accept" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/test/xyz",
        headers: HTTP::Headers{
          "Accept"      => "*/*",
          "Turbo-Frame" => "foo",
        },
      )

      request.turbo?.should be_true
    end
  end

  describe "#turbo_native_app?" do
    it "correctly returns false if the request is not a turbo native request" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/test/xyz",
        headers: HTTP::Headers{"Accept" => "text/html", "User-Agent" => "Custom-Agent"},
      )

      request.turbo_native_app?.should be_false
    end

    it "correctly returns true if the request is a turbo native request" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/test/xyz",
        headers: HTTP::Headers{"Accept" => "text/html", "User-Agent" => "Custom Turbo Native Agent"},
      )

      request.turbo_native_app?.should be_true
    end

    it "correctly returns false if the request headers do not contain a user agent" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/test/xyz",
        headers: HTTP::Headers{"Accept" => "text/html"},
      )

      request.turbo_native_app?.should be_false
    end

    it "correctly returns true if the request contains a turbo-frame header" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/test/xyz",
        headers: HTTP::Headers{"Accept" => "text/vnd.turbo-stream.html", "turbo-frame" => "form"},
      )

      request.turbo_frame?.should be_true
    end

    it "correctly returns false if the request doesn't contains a turbo-frame header" do
      request = Marten::HTTP::Request.new(
        method: "GET",
        resource: "/test/xyz",
        headers: HTTP::Headers{"Accept" => "text/vnd.turbo-stream.html"},
      )

      request.turbo_frame?.should be_false
    end
  end
end
