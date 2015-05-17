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
end
