require 'rails_helper'

RSpec.describe ::Api::V1::GroupsController, type: :controller do
  let(:valid_attributes) do
    { name: 'jumbo' }
  end

  before(:each) do
    @admin = build(:admin_user)
    @admin.access_token = build(:access_token)
    @admin.save
    @admin_token = @admin.access_token.token

    @user = build(:user, admin: false)
    @user.access_token = build(:access_token)
    @user.save
    @user_token = @user.access_token.token
  end

  describe '#create' do
    context 'authenticated as admin' do
      context 'with valid_attributes' do
        it 'should create groups' do
          post :create, params: { group: valid_attributes, access_token: @admin_token }
          group = Group.where(name: valid_attributes[:name]).first
          expect(group.blank?).to eq(false)
          expect(group.name).to eq(valid_attributes[:name])
        end

        it 'should return proper response' do
          post :create, params: { group: valid_attributes, access_token: @admin_token }
          expect(response.status).to eq(200)
          group = Group.where(name: valid_attributes[:name]).first
          obj = JSON.parse(response.body)
          expect(obj['id']).to eq group.id
          expect(obj['name']).to eq group.name
        end
      end

      context 'group already exist' do
        it 'should return existing group id' do
          existing_group = create(:group, name: valid_attributes[:name])
          post :create,  params: { group: valid_attributes, access_token: @admin_token }
          expect(response.status).to eq(422)
          expect(response.body).to eq({
            status: 'group already exist',
            id: existing_group.id,
            name: existing_group.name,
          }.to_json)
        end
      end
    end

    context 'unauthenticated' do
      it 'should return 401 http status' do
        post :create, params: { group: valid_attributes, access_token: 'foo' }
        expect(response.status).to eq(401)
      end
    end
  end

  describe '#add_user' do
    before(:each) do
      @group = create(:group)
      @new_user = create(:user, admin: false)
    end

    context 'invalid param' do
      context 'group id not found' do
        it 'should return 404 http status' do
          post :add_user, params: {
            id: 666,
            user_id: @new_user.id,
            access_token: @admin_token,
          }
          expect(response.status).to eq 404
        end
      end

      context 'invalid user id' do
        it 'should return 422 http status' do
          post :add_user, params: {
            id: @group.id,
            user_id: 'rand',
            access_token: @admin_token,
          }
          expect(response.status).to eq 422
        end
      end
    end

    context 'authenticated as admin' do
      context 'valid param' do
        it 'should return proper response' do
          post :add_user, params: {
            id: @group.id,
            user_id: @new_user.id,
            access_token: @admin_token,
          }
          expect(response.status).to eq 204
        end

        it 'should add user to group' do
          post :add_user, params: {
            id: @group.id,
            user_id: @new_user.id,
            access_token: @admin_token,
          }
          expect(@group.users).to contain_exactly @new_user
        end

        it 'should set membership expiration date' do
          post :add_user, params: {
            id: @group.id,
            user_id: @new_user.id,
            expiration_date: '2019-10-10',
            access_token: @admin_token,
          }
          membership = @group.group_associations.find_by(user_id: @new_user.id)
          expect(membership.expiration_date).to eq Date.parse('2019-10-10')
        end
      end
    end

    context 'authenticated as non admin' do
      it 'should not add user to group' do
        post :add_user, params: {
          id: @group.id,
          user_id: @new_user.id,
          access_token: @user_token,
        }
        expect(@group.users).to be_empty
      end

      it 'should return 401 http status' do
        post :add_user, params: {
          id: @group.id,
          user_id: @new_user.id,
          access_token: @user_token,
        }
        expect(response.status).to eq 401
      end
    end

    context 'authenticated as group admin' do
      before(:each) do
        @group.add_admin @user
      end
      it 'should add user to group' do
        post :add_user, params: {
          id: @group.id,
          user_id: @new_user.id,
          access_token: @user_token,
        }
        expect(@group.users).to contain_exactly @new_user
      end
    end

    context 'unauthenticated' do
      it 'should return 401 http status' do
        post :add_user, params: {
          id: @group.id,
          user_id: @new_user.id,
          access_token: 'foo',
        }
        expect(response.status).to eq 401
      end
    end
  end
end
