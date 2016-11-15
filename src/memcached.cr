require "logger"
require "./memcached/*"

module Memcached
  @@logger = Memcached.new_logger

  class UnsuccessfulOperationException < Exception
  end

  class BadVersionException < UnsuccessfulOperationException
  end

  # :nodoc:
  def self.logger
    @@logger
  end

  def self.new_logger : Logger
    logger = Logger.new(STDOUT)
    if ENV["DEBUG"]?
      logger.level = Logger::DEBUG
    else
      logger.level = Logger::ERROR
    end
    logger
  end
end
