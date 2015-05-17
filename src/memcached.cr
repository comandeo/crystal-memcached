require "logger"
require "./memcached/*"

module Memcached
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
