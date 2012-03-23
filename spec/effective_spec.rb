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

  describe "check" do
    before(:each) do
      @e = Effective.new(1, 2)
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
  end
end
