# Crystal Memcached
[![Build Status](https://travis-ci.org/comandeo/crystal-memcached.svg?branch=master)](https://travis-ci.org/comandeo/crystal-memcached)

Pure Crystal implementation of a Memcached client (work in progress).

## Installation

Add it to `Projectfile`

```crystal
deps do
  github "comandeo/crystal-memcached"
end
```

## Usage

```crystal
require "memcached"

client = Memcached::Client.new
client.set("Key", "Value")
value = client.get("Key")
```

## Status

### Alerady there

* get
* multi-get for faster getting multiple keys values (read [here](https://code.google.com/p/memcached/wiki/BinaryProtocolRevamped#Get,_Get_Quietly,_Get_Key,_Get_Key_Quietly) for details)
* set (with or without expiration)
* delete
* append
* prepend
* touch
* flush
* increment
* decrement

### To be done

* data version check (CAS)

## Contributing

1. Fork it ( https://github.com/comandeo/crystal-memcached/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [comandeo](https://github.com/comandeo) Dmitry Rybakov - creator, maintainer
