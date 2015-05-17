require "spec"

describe Memcached::Client do
  it "sets and then gets" do
    server = Memcached::Client.new
    server.set("Hello", "World").should eq(true)
    server.get("Hello").should eq("World")
  end

  it "does not get non existing key" do
    server = Memcached::Client.new
    server.get("SomeStrangeKey").should eq(nil)
  end
end
