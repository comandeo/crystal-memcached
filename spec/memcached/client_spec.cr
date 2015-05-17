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
end
