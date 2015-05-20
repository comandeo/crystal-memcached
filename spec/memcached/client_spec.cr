require "spec"

describe Memcached::Client do
  it "sets and then gets" do
    client = Memcached::Client.new
    client.flush
    client.set("Hello", "World").should_not eq(nil)
    client.get("Hello").should eq("World")
  end

  it "does not get non existing key" do
    client = Memcached::Client.new
    client.flush
    client.get("SomeStrangeKey").should eq(nil)
  end

  it "sets with expire" do
    client = Memcached::Client.new
    client.flush
    client.set("expires", "soon", 2)
    client.get("expires").should eq("soon")
    sleep(3)
    client.get("expires").should eq(nil)
  end

  it "gets multiple keys" do
    client = Memcached::Client.new
    client.flush
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

  it "handles version" do
    client = Memcached::Client.new
    client.flush
    version = client.set("vkey", "value")
    new_version = client.set("vkey", "new_value", version: version.not_nil!)
    client.get_with_version("vkey").try do |response|
      response[0].should eq("new_value")
      response[1].should eq(new_version)
    end
    raised = false
    begin
      client.set("vkey", "another_value", version: new_version.not_nil! + 1).should eq(nil)
    rescue Memcached::BadVersionException
      raised = true
    end
    raised.should eq(true)
  end

  it "deletes key" do
    client = Memcached::Client.new
    client.flush
    client.set("key", "value")
    client.get("key").should eq("value")
    client.delete("key").should eq(true)
    client.get("key").should eq(nil)
    client.delete("key").should eq(false)
  end

  it "appends" do
    client = Memcached::Client.new
    client.flush
    client.set("key", "value")
    client.get("key").should eq("value")
    client.append("key", "andmore").should eq(true)
    client.get("key").should eq("valueandmore")
  end

  it "prepends" do
    client = Memcached::Client.new
    client.flush
    client.set("pkey", "value")
    client.get("pkey").should eq("value")
    client.prepend("pkey", "somethingand").should eq(true)
    client.get("pkey").should eq("somethingandvalue")
  end

  it "touches" do
    client = Memcached::Client.new
    client.flush
    client.set("tkey", "value", 1)
    client.touch("tkey", 10).should eq(true)
    sleep(2)
    client.get("tkey").should eq("value")
  end

  it "does not touch non existing key" do
    client = Memcached::Client.new
    client.flush
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

  it "increments" do
    client = Memcached::Client.new
    client.flush
    client.increment("ikey", 2, 5).should eq(5)
    client.increment("ikey", 2, 0).should eq(7)
  end

  it "decrements" do
    client = Memcached::Client.new
    client.flush
    client.decrement("dkey", 2, 5).should eq(5)
    client.decrement("dkey", 2, 0).should eq(3)
  end

end
