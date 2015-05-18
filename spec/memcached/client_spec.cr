require "spec"

describe Memcached::Client do
  it "sets and then gets" do
    client = Memcached::Client.new
    client.set("Hello", "World").should eq(true)
    client.get("Hello").should eq("World")
  end

  it "does not get non existing key" do
    client = Memcached::Client.new
    client.get("SomeStrangeKey").should eq(nil)
  end

  it "sets with expire" do
    client = Memcached::Client.new
    client.set("expires", "soon", 2)
    client.get("expires").should eq("soon")
    sleep(3)
    client.get("expires").should eq(nil)
  end

  it "gets multiple keys" do
    client = Memcached::Client.new
    client.set("key1", "value1")
    client.set("key3", "value3")
    response = client.get_multi(["key1", "key2", "key3", "key4", "key5"])
    response.should eq({
      "key1" => "value1",
      "key2" => nil,
      "key3" => "value3",
      "key4" => nil,
      "key5" => nil
    })
  end

  it "deletes key" do
    client = Memcached::Client.new
    client.set("key", "value")
    client.get("key").should eq("value")
    client.delete("key").should eq(true)
    client.get("key").should eq(nil)
    client.delete("key").should eq(false)
  end

  it "appends" do
    client = Memcached::Client.new
    client.set("key", "value")
    client.get("key").should eq("value")
    client.append("key", "andmore").should eq(true)
    client.get("key").should eq("valueandmore")
  end

  it "prepends" do
    client = Memcached::Client.new
    client.set("pkey", "value")
    client.get("pkey").should eq("value")
    client.prepend("pkey", "somethingand").should eq(true)
    client.get("pkey").should eq("somethingandvalue")
  end

  it "touches" do
    client = Memcached::Client.new
    client.set("tkey", "value", 1)
    client.touch("tkey", 10).should eq(true)
    sleep(2)
    client.get("tkey").should eq("value")
  end

  it "does not touch non existing key" do
    client = Memcached::Client.new
    client.touch("SomeStrangeKey", 10).should eq(false)
  end

  it "flushes" do
    client = Memcached::Client.new
    client.set("fkey", "value")
    client.flush.should eq(true)
    client.get("fkey").should eq(nil)
  end

  it "flushes with delay" do
    client = Memcached::Client.new
    client.set("fdkey", "value")
    client.flush(2).should eq(true)
    client.get("fdkey").should eq("value")
    sleep(3)
    client.get("fdkey").should eq(nil)
  end

end
