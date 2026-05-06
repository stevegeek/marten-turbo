require "marten_cable"

require "./marten_turbo/verifier"
require "./marten_turbo/streams_channel"
require "./marten_turbo/broadcasts"

require "./marten_turbo/app"

module MartenTurbo
  VERSION            = "0.3.0"
  TURBO_CONTENT_TYPE = "text/vnd.turbo-stream.html"
end
