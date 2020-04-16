module Memcached # :nodoc:
  class Response
    STATUSES = {
      "no_error"                              => 0x00,
      "key_not_found"                         => 0x01,
      "key_exists"                            => 0x02,
      "value_too_large"                       => 0x03,
      "invalid_arguments"                     => 0x04,
      "item_not_stored"                       => 0x05,
      "incr_recr_on_non_numeric_value"        => 0x06,
      "the_vbucket_belongs_to_another_server" => 0x07,
      "authentication_error"                  => 0x08,
      "authentication_continue"               => 0x09,
      "unknown_command"                       => 0x81,
      "out_of_memory"                         => 0x82,
      "not_supported"                         => 0x83,
      "internal_error"                        => 0x84,
      "busy"                                  => 0x85,
      "temporary_failure"                     => 0x86,
    }

    getter status_code : UInt8

    getter opcode : UInt8

    getter key_length : Int32

    getter body : Slice(UInt8)

    getter extras : Slice(UInt8)

    getter version : Int64

    def initialize(
      status_code : UInt8,
      opcode : UInt8,
      key_length : UInt32,
      body : Slice(UInt8),
      extras : Slice(UInt8),
      version : Int64
    )
      @status_code = status_code
      @opcode = opcode
      @key_length = key_length.to_i32
      @body = body
      @extras = extras
      @version = version
    end

    def successful?
      status_code == STATUSES["no_error"]
    end

    def status_is?(status)
      STATUSES[status] == @status_code
    end
  end
end
