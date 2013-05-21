# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'

describe OmfCommon::Message do
  describe "when initialised" do
    before do
      @internal_attr = %w(type operation guard mid ts replyto cid itype)
      @message = OmfCommon::Message.create(:create, { p1: 'p1_value', p2: 'p2_value' }, { rtype: :bob })
    end

    it "must be able to query internal properties" do
      @message.type.must_equal :create
      @message.operation.must_equal :create
      @message.mid.wont_be_nil
      @message.ts.wont_be_nil
    end

    it "must be able to get property value"  do
      @message[:p1].must_equal 'p1_value'
      @message.read_property(:p1).must_equal 'p1_value'
    end

    it "must be able to set property value" do
      @message[:p1] = 'new_value'
      @message[:p1].must_equal 'new_value'
      @message.write_property(:p2, 'new_value')
      @message[:p2].must_equal 'new_value'
    end

    it "must be able to query internal message properties" do
      @internal_attr.each do |name|
        @message.must_respond_to name
      end
    end

    it "must evaluate erb code when read property with evaluate option is true" do
      skip
      @message[:p3] = "1 + 1 = <%= 1 + 1 %>"
      @message[:p4] = "1 + 1 = <%= two %>"
      @message.read_property(:p3, binding).must_equal "1 + 1 = 2"
      @message[:p3].must_equal "1 + 1 = <%= 1 + 1 %>"
      two = 2
      @message[:p4, binding].must_equal "1 + 1 = 2"
      @message[:p4].must_equal "1 + 1 = <%= two %>"
    end

    it "must be able to pretty print an app_event message" do
      @message = OmfCommon::Message.create(:inform,
                     { status_type: 'APP_EVENT',
                       event: 'DONE.OK',
                       app: 'app100',
                       msg: 'Everything will be OK',
                       seq: 1 },
                     { itype: 'STATUS' })
      @message.print_app_event.must_equal "APP_EVENT (app100, #1, DONE.OK): Everything will be OK"
    end

    it "must return inform type (itype), formatted" do
      @message.itype = 'CREATION.OK'

      @message.itype.must_equal 'CREATION.OK'
      @message.itype(:ruby).must_equal 'creation_ok'
      @message.itype(:frcp).must_equal 'CREATION.OK'

      @message.itype = :creation_ok

      @message.itype.must_equal :creation_ok
      @message.itype(:ruby).must_equal 'creation_ok'
      @message.itype(:frcp).must_equal 'CREATION.OK'
    end
  end
end
