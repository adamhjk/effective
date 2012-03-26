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

require File.expand_path(File.join(File.dirname(__FILE__), "..", 'spec_helper'))

require 'effective/chef'
require 'chef/node'
require 'chef/mash'

describe "Effective" do
  describe "Chef" do
    before(:each) do 
      @node = Chef::Node.new()
      @node.name "test-node1"
      @node.override_attrs["fqdn"] = "test-node1.example.com"
      @node.default_attrs = Mash.new({
        "effective" => {
          "state" => {
            "test-application" => {
              "desired" => "2"
            }
          }
        }
      })
      @previous_node = Chef::Node.new()
      @previous_node.name "test-node2"
      @previous_node.override_attrs["fqdn"] = "test-node2.example.com"
      @previous_node.default_attrs = Mash.new({
        "effective" => {
          "state" => {
            "test-application" => {
              "desired" => "2" 
            }
          }
        }
      })
      @release_one = Chef::DataBagItem.new
      @release_one.data_bag("state_test-application")
      @release_one.raw_data ={
        "data" => {
          "repo_name" => "test-application-1"
        },
        "retry_count" => 0,
        "conditions" => {
          "by fqdn" => {
            "attribute" => [
              "fqdn"
            ],
            "query" => "fqdn:*"
          }
        },
        "id" => "1",
        "operator" => "and",
        "random_wait" => 10
      }
      @release_two = Chef::DataBagItem.new
      @release_two.data_bag("state_test-application")
      @release_two.raw_data ={
        "data" => {
          "repo_name" => "test-application-2"
        },
        "retry_count" => 0,
        "conditions" => {
          "by fqdn" => {
            "attribute" => [
              "fqdn"
            ],
            "query" => "fqdn:*"
          }
        },
        "id" => "2",
        "operator" => "and",
        "random_wait" => 10
      }

      @ec = Effective::Chef.new(@node, "test-application")
    end

    describe "initialize" do
      it "stores the node" do
        @ec.node.should == @node
      end

      it "stores the state name we want to check" do
        @ec.state_name.should == "test-application"
      end
    end

    describe "load_state" do
      before(:each) do 
        ::Chef::DataBagItem.stub(:load).with("state_test-application", "2") { @release_two }
      end

      it "loads the data bag item from state_STATE_NAME referenced in the nodes desired state for the application" do
        ::Chef::DataBagItem.should_receive(:load).with("state_test-application", "2")
        @ec.load_state(:desired)
      end

      it "returns the data bag item" do
        @ec.load_state(:desired).should == @release_two
      end

      it "raises ArgumentError if the state is not found" do
        lambda { @ec.load_state(:will_raise) }.should raise_error(ArgumentError)
      end
    end


    describe "get_node_attribute" do
      it "returns the attribute from the node if it is a single attribute" do
        @ec.get_node_attribute(@node, ["fqdn"]).should == "test-node1.example.com"
      end
      it "returns the attribute from the node if it is deeply nested" do
        @ec.get_node_attribute(@node, ["effective", "state", "test-application", "desired"]).should == "2"
      end
      it "throws an argument error if the attr does not exist" do
        lambda { @ec.get_node_attribute(@node, [ "does", "not", "exist"]) }.should raise_error(ArgumentError)
      end
    end

    # Also - "condition lambda" is awesome to say.
    describe "generate_condition_lambda" do
      before(:each) do 
        @search_query = double(::Chef::Search::Query)
        @search_query.stub(:search).and_return([[ @node, @previous_node ], nil, nil])
        Chef::Search::Query.stub(:new).and_return(@search_query)
        @ec.generate_condition_lambda("fqdn:*", [ "fqdn" ], 1) 
      end

      it "builds a lambda" do
        @ec.generate_condition_lambda("fqdn:*", [ "fqdn" ], 1).should be_a_kind_of(Proc)
      end
    end

    describe "check" do
      before(:each) do 
        @search_query = double(::Chef::Search::Query)
        @search_query.stub(:search).and_return([[ @node, @previous_node ], nil, nil])
        Chef::Search::Query.stub(:new).and_return(@search_query)
        ::Chef::DataBagItem.stub(:load).with("state_test-application", "1") { @release_one }
        ::Chef::DataBagItem.stub(:load).with("state_test-application", "2") { @release_two }
      end

      it "returns desired if all the nodes have the same current release as the desired release" do
        @node.default["effective"]["state"]["test-application"]["current"] = 2 
        @previous_node.default["effective"]["state"]["test-application"]["current"] = 2
        @ec.check.should == @release_two["data"]
      end

      it "returns desired if the previous node has the current current release, and the node does not" do
        @node.default["effective"]["state"]["test-application"]["current"] = 1 
        @previous_node.default["effective"]["state"]["test-application"]["current"] = 2
        @ec.check.should == @release_two["data"]
      end

      it "returns desired if the node does not have a current release" do
        @node.default["effective"]["state"]["test-application"]["current"] = nil
        @previous_node.default["effective"]["state"]["test-application"]["current"] = 2
        @ec.check.should == @release_two["data"]
      end

      it "returns desired if all the nodes lack the correct current state, and the node is in the first group" do
        @node.default["effective"]["state"]["test-application"]["current"] = 1 
        @previous_node.default["effective"]["state"]["test-application"]["current"] = 1
        @ec.check.should == @release_two["data"]
      end

      it "returns desired if the current node lacks the correct current state, but the previous group is complete" do
        @node.override_attrs["fqdn"] = "zedsortslate"
        @node.default["effective"]["state"]["test-application"]["current"] = 1
        @previous_node.default["effective"]["state"]["test-application"]["current"] = 2
        @ec.check.should == @release_one["data"]
      end

      it "returns current if all the nodes lack the correct current state, and the node is not in the first group" do
        @node.override_attrs["fqdn"] = "zedsortslate"
        @node.default["effective"]["state"]["test-application"]["current"] = 1 
        @previous_node.default["effective"]["state"]["test-application"]["current"] = 1
        @ec.check.should == @release_one["data"]
      end
    end
  end
end
