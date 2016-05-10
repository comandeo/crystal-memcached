require "socket"

# This class is a client for memcached storage
#
# ** Usage **
# ```crystal
# # Require package
# require "memcached"
#
# # Create client instance
# client = Memcached::Client.new
#
# # Execute commands
# client.set("key", "value")
# client.set("another_key", "another_value")
# client.get("key")   # "value"
# client.get_multi(["key", "another_key"]) # { "key" => "value", "another_key" => "another_value"}
# client.delete("key")
# ```
module Memcached
  class Client
    #:nodoc:
    HEADER_SIZE = 24

    #:nodoc:
    MAGICS = {
      "request"  => 0x80_u8,
      "response" => 0x81_u8
    }

    #:nodoc:
    OPCODES = {
      "get"       => 0x00_u8,
      "set"       => 0x01_u8,
      "delete"    => 0x04_u8,
      "increment" => 0x05_u8,
      "decrement" => 0x06_u8,
      "flush"     => 0x08_u8,
      "getq"      => 0x09_u8,
      "noop"      => 0x0a_u8,
      "getk"      => 0x0c_u8,
      "getkq"     => 0x0d_u8,
      "append"    => 0x0e_u8,
      "prepend"   => 0x0f_u8,
      "touch"     => 0x1c_u8
    }

    # Opens connection to memcached server
    #
    # **Options**
    # * host : String - memcached host
    # * port : Number - memcached port
    def initialize(host = "localhost", port = 11211)
      Memcached.logger.info("Connecting to #{host}:#{port}")
      @socket = TCPSocket.new(host, port)
    end

    #:nodoc:
    def finalize
      if !@socket.nil?
        @socket.close
      end
    end

    # Set key - value pair in memcached.
    #
    # By default the key is set without expiration time.
    # If you want to set TTL for the key,
    # pass TTL in seconds as *expire* parameter
    # If *version* parameter is provided, it will be compared to existing key
    # version in memcached. If versions differ, *Memcached::BadVersionException*
    # will be raised.
    def set(key : String, value : String, expire : Number = 0, version : Number = 0) : Int64
      ex = expire.to_u32
      ver = version.to_i64
      send_request(
        OPCODES["set"],
        key.bytes,
        value.bytes,
        [
          0xde_u8, 0xad_u8, 0xbe_u8, 0xef_u8,
          ((ex >> 24) & 0xFF).to_u8,
          ((ex >> 16) & 0xFF).to_u8,
          ((ex >> 8) & 0xFF).to_u8,
          ( ex  & 0xFF).to_u8
        ],
        ver
      )
      @socket.flush
      read_response.try do |response|
        if response.successful? && response.opcode == OPCODES["set"]
          response.version
        elsif response.status_is?("key_exists")
          raise BadVersionException.new
        else
          raise UnsuccessfulOperationException.new
        end
      end || raise UnsuccessfulOperationException.new
    end

    # Get single key value from memcached.
    def get(key : String) : String?
      send_request(
        OPCODES["get"],
        key.bytes,
        Array(UInt8).new(0),
        Array(UInt8).new(0)
      )
      @socket.flush
      read_response.try do |response|
        if response.successful? && response.opcode == OPCODES["get"]
          String.new(response.body)
        else
          nil
        end
      end
    end

    # Get single key value and its current version.
    def get_with_version(key : String) : Tuple(String, Int64)?
      send_request(
        OPCODES["get"],
        key.bytes,
        Array(UInt8).new(0),
        Array(UInt8).new(0)
      )
      @socket.flush
      read_response.try do |response|
        if response.successful? && response.opcode == OPCODES["get"]
          Tuple.new(String.new(response.body), response.version)
        else
          nil
        end
      end
    end

    # Get multiple keys values from memcached.
    #
    # If a key was not found or an error occured while getting the key,
    # value for this key will be nil in the returned hash
    def get_multi(keys : Array(String)) : Hash(String, String | Nil)
      result = Hash(String, String | Nil).new
      keys.each do |key|
        result[key] = nil
        send_request(
          OPCODES["getkq"],
          key.bytes,
          Array(UInt8).new(0),
          Array(UInt8).new(0)
        )
      end
      send_request(
        OPCODES["noop"],
        Array(UInt8).new(0),
        Array(UInt8).new(0),
        Array(UInt8).new(0)
      )
      @socket.flush
      while response = read_response
        Memcached.logger.info(String.new(response.body))
        case response.opcode
        when OPCODES["noop"]
          return result
        when OPCODES["getkq"]
          key = String.new(response.body[0, response.key_length])
          value = String.new(
            response.body[
              response.key_length,
              response.body.size - response.key_length
            ]
          )
          result[key] = value
        end
      end
      result
    end

    # Deletes the key from memcached.
    def delete(key : String) : Bool
      send_request(
        OPCODES["delete"],
        key.bytes,
        Array(UInt8).new(0),
        Array(UInt8).new(0)
      )
      @socket.flush
      read_response.try do |response|
        response.successful? && response.opcode == OPCODES["delete"]
      end || false
    end

    # Append value afrer an existing key value
    def append(key : String, value : String) : Bool
      send_request(
        OPCODES["append"],
        key.bytes,
        value.bytes,
        Array(UInt8).new(0)
      )
      @socket.flush
      read_response.try do |response|
        response.successful? && response.opcode == OPCODES["append"]
      end || false
    end

    # Prepend value before an existing key value
    def prepend(key : String, value : String) : Bool
      send_request(
        OPCODES["prepend"],
        key.bytes,
        value.bytes,
        Array(UInt8).new(0)
      )
      @socket.flush
      read_response.try do |response|
        response.successful? && response.opcode == OPCODES["prepend"]
      end || false
    end

    # Update key expiration time
    def touch(key : String, expire : Number) : Bool
      exp = expire.to_u32
      send_request(
        OPCODES["touch"],
        key.bytes,
        Array(UInt8).new(0),
        [
          ((exp >> 24) & 0xFF).to_u8,
          ((exp >> 16) & 0xFF).to_u8,
          ((exp >> 8) & 0xFF).to_u8,
          (exp & 0xFF).to_u8
        ]
      )
      @socket.flush
      read_response.try do |response|
        response.successful? && response.opcode == OPCODES["touch"]
      end || false
    end

    # Remove all keys from memcached.
    #
    # Passing delay parameter postpone the removal.
    def flush(delay = 0_u32) : Bool
      send_request(
        OPCODES["flush"],
        Array(UInt8).new(0),
        Array(UInt8).new(0),
        [
          ((delay >> 24) & 0xFF).to_u8,
          ((delay >> 16) & 0xFF).to_u8,
          ((delay >> 8) & 0xFF).to_u8,
          (delay & 0xFF).to_u8
        ]
      )
      @socket.flush
      read_response.try do |response|
        response.successful? && response.opcode == OPCODES["flush"]
      end || false
    end

    # Increment key value by delta.
    #
    # If key does not exist, it will be set to initial_value.
    def increment(
      key : String,
      delta : Number,
      initial_value = 0,
      expire = 0
    ) : Int64?
      dl = delta.to_i64
      iv = initial_value.to_i64
      exp = expire.to_u32
      send_request(
        OPCODES["increment"],
        key.bytes,
        Array(UInt8).new(0),
        [
          ((dl >> 56) & 0xFF).to_u8,
          ((dl >> 48) & 0xFF).to_u8,
          ((dl >> 40) & 0xFF).to_u8,
          ((dl >> 32) & 0xFF).to_u8,
          ((dl >> 24) & 0xFF).to_u8,
          ((dl >> 16) & 0xFF).to_u8,
          ((dl >> 8)  & 0xFF).to_u8,
          ( dl         & 0xFF).to_u8,
          ((iv >> 56) & 0xFF).to_u8,
          ((iv >> 48) & 0xFF).to_u8,
          ((iv >> 40) & 0xFF).to_u8,
          ((iv >> 32) & 0xFF).to_u8,
          ((iv >> 24) & 0xFF).to_u8,
          ((iv >> 16) & 0xFF).to_u8,
          ((iv >> 8)  & 0xFF).to_u8,
          ( iv        & 0xFF).to_u8,
          ((exp >> 24) & 0xFF).to_u8,
          ((exp >> 16) & 0xFF).to_u8,
          ((exp >> 8) & 0xFF).to_u8,
          ( exp  & 0xFF).to_u8
        ]
      )
      @socket.flush
      read_response.try do |response|
        if response.successful? && response.opcode == OPCODES["increment"]
          to_int_64(response.body)
        end
      end
    end

    # Decrement key value by delta.
    #
    # If key does not exist, it will be set to initial_value.
    def decrement(
      key : String,
      delta : Number,
      initial_value : Number = 0,
      expire : Number = 0
    ) : Int64?
    dl = delta.to_i64
    iv = initial_value.to_i64
    exp = expire.to_u32
    send_request(
      OPCODES["decrement"],
      key.bytes,
      Array(UInt8).new(0),
      [
        ((dl >> 56) & 0xFF).to_u8,
        ((dl >> 48) & 0xFF).to_u8,
        ((dl >> 40) & 0xFF).to_u8,
        ((dl >> 32) & 0xFF).to_u8,
        ((dl >> 24) & 0xFF).to_u8,
        ((dl >> 16) & 0xFF).to_u8,
        ((dl >> 8)  & 0xFF).to_u8,
        ( dl         & 0xFF).to_u8,
        ((iv >> 56) & 0xFF).to_u8,
        ((iv >> 48) & 0xFF).to_u8,
        ((iv >> 40) & 0xFF).to_u8,
        ((iv >> 32) & 0xFF).to_u8,
        ((iv >> 24) & 0xFF).to_u8,
        ((iv >> 16) & 0xFF).to_u8,
        ((iv >> 8)  & 0xFF).to_u8,
        ( iv        & 0xFF).to_u8,
        ((exp >> 24) & 0xFF).to_u8,
        ((exp >> 16) & 0xFF).to_u8,
        ((exp >> 8) & 0xFF).to_u8,
        ( exp  & 0xFF).to_u8
      ]
    )
      @socket.flush
      read_response.try do |response|
        if response.successful? && response.opcode == OPCODES["decrement"]
          to_int_64(response.body)
        end
      end
    end

    private def read_response
      response_header = Slice(UInt8).new(HEADER_SIZE)
      @socket.read_fully(response_header)
      if response_header[0] != MAGICS["response"]
        return nil
      end
      Memcached.logger.info("Response received")
      opcode = response_header[1]
      key_length = response_header[2].to_u32 << 8 |
        response_header[3].to_u32
      extras_length = response_header[4].to_i32
      total_length = response_header[8].to_u32 << 24 |
        response_header[9].to_u32 << 16 |
        response_header[10].to_u32 << 8 |
        response_header[11].to_u32
      body_length = (total_length - extras_length).to_i32
      Memcached.logger.info("Total length: #{total_length}, \
        extras_length: #{extras_length}, body_length: #{body_length}")
      status_code = response_header[7]
      Memcached.logger.info("Response status code: #{status_code}")
      version = to_int_64(response_header[16, 8])
      extras = Slice(UInt8).new(extras_length)
      body = Slice(UInt8).new(body_length)
      if extras_length > 0
        @socket.read(extras)
      end
      if body_length > 0
        @socket.read(body)
      end
      Response.new(status_code, opcode, key_length, body, extras, version)
    end

    private def send_request(
      opcode : UInt8,
      key : Array(UInt8),
      value : Array(UInt8),
      extras : Array(UInt8),
      version : Int64 = 0
    )
      v = version.to_i64
      extras_length = extras.size.to_u8
      key_length = key.size.to_u16
      total_length = (key.size + value.size + extras_length).to_u32
      # Header
      args = [
        MAGICS["request"],                              # magic 0
        opcode,                                         # opcode 1
        ((key_length >> 8) & 0xFF).to_u8,               # key length 2
        (key_length & 0xFF).to_u8,                      # key length 3
        extras_length,                                  # extra length 4
        0_u8,                                           # data type 5
        0_u8, 0_u8,                                     # vbucket 6, 7
        ((total_length >> 24) & 0xFF).to_u8,            # total body 8
        ((total_length >> 16) & 0xFF).to_u8,            # total body 9
        ((total_length >> 8) & 0xFF).to_u8,             # total body 10
        (total_length & 0xFF).to_u8,                    # total body 11
        0_u8, 0_u8, 0_u8, 0_u8,                         # opaque 12, 13, 14, 15
        ((v >> 56) & 0xFF).to_u8,                       # cas 16
        ((v >> 48) & 0xFF).to_u8,                       # cas 17
        ((v >> 40) & 0xFF).to_u8,                       # cas 18
        ((v >> 32) & 0xFF).to_u8,                       # cas 19
        ((v >> 24) & 0xFF).to_u8,                       # cas 20
        ((v >> 16) & 0xFF).to_u8,                       # cas 21
        ((v >> 8)  & 0xFF).to_u8,                       # cas 22
        ( v        & 0xFF).to_u8,                       # cas 23
      ]
      @socket.write(Slice(UInt8).new(args.to_unsafe, args.size))

      # Body
      if extras.size > 0
        @socket.write(Slice(UInt8).new(extras.to_unsafe, extras.size))
      end
      if key.size > 0
        @socket.write(Slice(UInt8).new(key.to_unsafe, key.size))
      end
      if value.size > 0
        @socket.write(Slice(UInt8).new(value.to_unsafe, value.size))
      end
    end

    private def to_int_64(arr : Slice(UInt8)) : Int64
      arr[0].to_i64 << 56 |
        arr[1].to_i64 << 48 |
        arr[2].to_i64 << 40 |
        arr[3].to_i64 << 32 |
        arr[4].to_i64 << 24 |
        arr[5].to_i64 << 16 |
        arr[6].to_i64 << 8  |
        arr[7].to_i64
    end

  end
end
