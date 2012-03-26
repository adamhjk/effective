# Let's you evaluate whether you should use the current or desired state,
# based on a set of conditions. Optionally run triggers on success/failure.
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

require "effective/version"
require "effective"
require 'chef'
require 'chef/data_bag_item'
require 'chef/search/query'

class Effective
  class Chef
  
    attr_accessor :state_name, :node

    def initialize(node, state_name)
      @state_name = state_name  
      @node = node
    end

    def load_state(type)
      item_id = @node["effective"]["state"][@state_name][type]
      raise(ArgumentError, "Cannot find a value for node['effective']['state'][#{@state_name}][#{type}]!") if item_id == nil
      ::Chef::DataBagItem.load("state_#{@state_name}", "#{item_id}")
    end

    def get_node_attribute(node, attribute_list)
      cna = node
      attribute_list.each do |attr|
        cna = cna.send(attr)
      end
      cna
    end

    def generate_condition_lambda(query, attribute, desired_state)
      lambda do 
        node_conditions = { }
        my_group = nil
        
        q = ::Chef::Search::Query.new
        r, s, t = q.search(:node, query)
        r.each do |n|
          begin
            group_by = get_node_attribute(n, attribute)
          rescue ArgumentError
            next # Skip this node if it doesn't have the group_by attribute
          end
          node_conditions[group_by] ||= {} 

          begin
            current_state = get_node_attribute(n, [ "effective", "state", @state_name, "current" ])
          rescue ArgumentError
            current_state = nil 
          end
          node_conditions[group_by][n.name] = current_state 

          if n.name == @node.name
            my_group = group_by
          end
        end

        deploy_groups = node_conditions.keys.sort
        deploy_group_index = deploy_groups.index(my_group)
        if deploy_group_index == 0
          return true # If you are first, you have to fight
        else
          # If you aren't first, then you get to deploy if all your previous buddies are in the desired state.
          return node_conditions[deploy_groups[deploy_group_index - 1]].all? { |k,v| v == desired_state } 
        end
      end
    end

    # load desired state data
    # if no current state recorded for the node, go directly to desired, and stop
    # iterate the conditions
    #   . search for the query
    #   . sort and group by the attribute
    # do whatever
    # store the current state
    def check
      desired_state = load_state(:desired)
      begin
        current_state = load_state(:current) 
      rescue ArgumentError => e
        return desired_state["data"]
      end

      item_id = @node["effective"]["state"][@state_name]["desired"]
      e = Effective.new(current_state["data"], desired_state["data"])
      desired_state["conditions"].each do |condition_name, condition_opts|
        e.condition(condition_name, generate_condition_lambda(condition_opts["query"], condition_opts["attribute"], item_id))
      end
      result, why = e.check("or", desired_state["retry_count"], desired_state["random_wait"])
      return result
    end

  end
end

