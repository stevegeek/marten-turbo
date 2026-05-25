class Marten::HTTP::Request
  # Returns `true` when the request looks like a Turbo client (Turbo Drive/Frames/Streams).
  #
  # We *cannot* delegate to `Marten::HTTP::Request#accepts?` because that treats `*/*`
  # as a match for anything — and every browser sends `Accept: text/html,…,*/*;q=0.8`,
  # which would make `turbo?` true for *every* request. Instead we inspect the raw
  # Accept header for the exact Turbo Stream MIME, or — for GET-only frame fetches —
  # fall back to recognising an explicit `Turbo-Frame` request header.
  #
  # TR1: the `Turbo-Frame` fallback is restricted to GET. A form POST originating
  # from inside a `<turbo-frame>` carries `Turbo-Frame: <id>` but expects an HTML
  # response (Turbo extracts the matching frame from it); routing it through the
  # turbo-stream branch would render `<turbo-stream>` markup that the frame can't
  # consume. Explicit `Accept: text/vnd.turbo-stream.html` always wins regardless
  # of method.
  def turbo?
    accept_header = @request.headers["Accept"]?
    return true if accept_header.try(&.includes?("text/vnd.turbo-stream.html"))
    return true if @request.method == "GET" && @request.headers.has_key?("Turbo-Frame")
    false
  end

  def turbo_frame?
    @request.headers.has_key? "Turbo-Frame"
  end

  def turbo_native_app?
    user_agent = @request.headers["User-Agent"]?

    user_agent ? user_agent.includes?("Turbo Native") : false
  end
end
