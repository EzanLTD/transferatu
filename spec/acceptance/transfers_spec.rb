require "spec_helper"

module Transferatu
  describe Endpoints::Transfers do
    include Committee::Test::Methods
    include Rack::Test::Methods

    def app
      Routes
    end

    let(:request_data) {
      {
        from_url: 'postgres:///test1', from_type: 'pg_dump', from_name: 'ezra',
        to_url: 'postgres:///test2', to_type: 'pg_restore', to_name: 'george'
      }
    }

    before do
      @password = 'hunter2'
      @user = create(:user, password: @password)
      @group = create(:group, user: @user)
    end

    describe "when unauthenticated" do
      it "rejects requests" do
        get "/groups/#{@group.name}/transfers"
        expect(last_response.status).to eq(401)
        response = JSON.parse(last_response.body)

        expect(response["message"]).to match("Unauthorized")
        expect(response["status"]).to eq(401)
      end
    end

    describe "when authenticated" do
      before do
        authorize @user.name, @password
      end

      it "GET /groups/:name/transfers" do
        get "/groups/#{@group.name}/transfers"
        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq([])
      end

      it "POST /groups/:name/transfers" do
        post "/groups/#{@group.name}/transfers", request_data
        expect(last_response.status).to eq(201)
        response = JSON.parse(last_response.body)
        request_data.keys.each do |key|
          expect(response[key.to_s]).to eq request_data[key]
        end
        xfer_id = response["uuid"]
        expect(xfer_id).to_not be_nil
        xfer = Transferatu::Transfer[xfer_id]
        request_data.keys.each do |key|
          expect(xfer.public_send(key)).to eq request_data[key]
        end
      end

      it "GET /groups/:name/transfers/:id" do
        xfer = create(:transfer, group: @group)
        get "/groups/#{@group.name}/transfers/#{xfer.uuid}"
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        %i(from_url from_name from_type to_url to_name to_type).each do |field|
          expect(response[field.to_s]).to eq(xfer.public_send(field))
        end
      end

      it "DELETE /groups/:name/transfers/:id" do
        xfer = create(:transfer, group: @group)
        before_deletion = Time.now
        delete "/groups/#{@group.name}/transfers/#{xfer.uuid}"
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        %i(from_url from_name from_type to_url to_name to_type).each do |field|
          expect(response[field.to_s]).to eq(xfer.public_send(field))
        end
        xfer.reload
        expect(xfer.deleted?).to be true
        expect(xfer.deleted_at).to be > before_deletion
        expect(xfer.deleted_at).to be < Time.now
      end
    end
  end
end
