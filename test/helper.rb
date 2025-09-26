$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
# in general, load without rails:
require "searls/auth"

# but add this stuff so we can onesy-twosy still test stuff that uses blank? etc
require "active_support"
require "active_support/core_ext"

require "tldr"
