require "spec"

describe Memcached::Client do
    it "sets" do
        server = Memcached::Client.new
        server.set("Hello", "World").should eq(true)
        server.get("Hello").should eq("World")
    end
end
