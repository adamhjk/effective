#
# Author: adam@opscode.com
#
# Copyright 2012, Opscode, Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe "Effective" do
  describe "VERSION" do
    it "has a version constant" do
      Effective::VERSION.should =~ /^\d+\.\d+\.\d+$/
    end
  end

  describe "new" do
    before(:each) do
      @e = Effective.new(1, 2)
    end

    it "sets the current data structure" do
      @e.current.should == 1
    end

    it "takes a desired data structure" do
      @e.desired.should == 2
    end

    it "sets conditions to an empty array" do
      @e.conditions.should == []
    end
  end

  describe "condition" do
    before(:each) do
      @e = Effective.new(1, 2)
      @e.condition("not neglected") do
        true
      end
    end

    it "adds the condition to the conditions array" do
      @e.conditions[0][0].should == "not neglected"
      @e.conditions[0][1].should be_a_kind_of(Proc)
    end

    it "accepts inline conditions as Procs/Lambda" do
      @e.condition("not neglected", lambda { true })  
      @e.conditions[0][1].should be_a_kind_of(Proc) 
    end

    it "prefers the inline to the attached block" do
      @e.condition("not neglected", lambda { true }) do
        false
      end
      @e.conditions[0][1].call.should == true
    end

  end

  describe "evaluate" do
    before(:each) do
      @e = Effective.new(1, 2)
    end

    it "accepts only and and or for the operator" do
      lambda { @e.evaluate("and") }.should_not raise_error(ArgumentError)
      lambda { @e.evaluate("or") }.should_not raise_error(ArgumentError)
      lambda { @e.evaluate("snuffy") }.should raise_error(ArgumentError)
    end

    it "returns a result and the attendant data" do
      @e.condition("truthy", lambda { true })
      @e.condition("falsy", lambda { false })
      result, data = @e.evaluate
      result.should == false
      data.should == { "truthy" => true, "falsy" => false }
    end

    describe "and" do
      it "returns true if all the conditions are true" do
        @e.condition("truthy", lambda { true })
        @e.condition("faithful", lambda { true })
        @e.evaluate("and")[0].should == true
      end

      it "returns false if any the conditions are not true" do
        @e.condition("truthy", lambda { true })
        @e.condition("falsy", lambda { false })
        @e.evaluate("and")[0].should == false
      end
    end

    describe "or" do
      it "returns true if any the conditions are true" do
        @e.condition("truthy", lambda { true })
        @e.condition("falsy", lambda { false })
        @e.evaluate("or")[0].should == true
      end

      it "returns false if all the conditions are false" do
        @e.condition("truthy", lambda { false })
        @e.condition("falsy", lambda { false })
        @e.evaluate("or")[0].should == false
      end
    end
  end

  describe "trigger" do
    before(:each) do 
      @e = Effective.new(1, 2)
      @e.condition("truthy", lambda { true })
      @e.trigger(:success, lambda { "woot" }) 
    end

    it "stores the trigger in the array for its success criteria" do
      @e.triggers[:success][0].should be_a_kind_of(Proc)
      @e.triggers[:success][0].call.should == "woot" 
    end

    it "raises an error if no block is provided" do
      lambda { @e.trigger(:success) }.should raise_error(ArgumentError)
    end

    it "raises an error if the criteria is not :success, :failure or :any" do
      lambda { @e.trigger(:success, lambda { "whee" }) }.should_not raise_error(ArgumentError)
      lambda { @e.trigger(:failure, lambda { "whee" }) }.should_not raise_error(ArgumentError)
      lambda { @e.trigger(:any, lambda { "whee" }) }.should_not raise_error(ArgumentError)
      lambda { @e.trigger(:musicality, lambda { "whee" }) }.should raise_error(ArgumentError)
    end
  end

  describe "check" do
    before(:each) do
      @e = Effective.new(1, 2)
      @e.no_sleep = true
      @e.condition("truthy", lambda { true })
      @e.condition("falsy", lambda { true })
    end

    it "should return the desired data if the evaluation passes" do
      @e.check[0].should == 2
    end

    it "should return the current data if the evaluation fails" do
      @e.condition("false", lambda { false })
      @e.check[0].should == 1
    end

    it "should retry the evaluation a number of times equal to the retry count" do
      @e.condition("false", lambda { false })
      @e.should_receive(:evaluate).twice
      @e.check("and", 1, 0)
    end

    it "should run the triggers on success" do
      @pony = "foo"
      @e.trigger(:failure, lambda { @pony = "baz" })
      @e.trigger(:success, lambda { @pony = "bar" })
      @e.check("and")
      @pony.should == "bar"
    end

    it "should run the triggers on failure" do
      @pony = "foo"
      @e.trigger(:failure, lambda { @pony = "baz" })
      @e.trigger(:success, lambda { @pony = "bar" })
      @e.condition("false", lambda { false })
      @e.check("and")
      @pony.should == "baz"
    end

    it "should run the any triggers all the time" do
      @pony = "foo"
      @e.trigger(:any, lambda { @pony = "smee" })
      @e.trigger(:failure, lambda { @pony = "baz" })
      @e.trigger(:success, lambda { @pony = "bar" })
      @e.check("and")
      @pony.should == "smee"
      @e.condition("false", lambda { false })
      @e.check("and")
      @pony.should == "smee"
    end
  end

end
