require "log"
require "./memcached/*"

module Memcached
  Log = ::Log.for(self)

  class UnsuccessfulOperationException < Exception
  end

  class BadVersionException < UnsuccessfulOperationException
  end
end
