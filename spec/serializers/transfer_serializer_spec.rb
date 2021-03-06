require "spec_helper"

describe Transferatu::Serializers::Transfer do
  let(:xfer) { create(:transfer) }
  let(:serializer) { Transferatu::Serializers::Transfer.new(:default) }

  it "serializes a transfer" do
    expect { serializer.serialize(xfer) }.to_not raise_error
  end
end
