require "logger"
require "./memcached/*"

module Memcached

  class UnsuccessfulOperationException < Exception
  end

  class BadVersionException < UnsuccessfulOperationException
  end

  #:nodoc:
  def self.logger
    @@logger ||= begin
      logger = Logger.new(STDOUT)
      if ENV["DEBUG"]?
        logger.level = Logger::INFO
      else
        logger.level = Logger::ERROR
      end
      logger
    end
  end
end
