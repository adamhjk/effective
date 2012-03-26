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

class Effective

  attr_accessor :current, :desired, :conditions, :triggers, :no_sleep

  def initialize(current=nil, desired=nil)
    @current = current
    @desired = desired
    @conditions = [] 
    @no_sleep = false
    @triggers = {
      :success => [],
      :failure => [],
      :any => []
    }
  end

  # Add a trigger to be run on a given success critera.
  #
  #   e.trigger(:any, lambda { true })
  #
  # @param [Symbol] criteria Should be :success, :failure, or :any
  # @param [optional, Proc] trigger Takes a lambda/proc to execute 
  # @yield An optional block that will be used in place of the lambda/proc option above
  def trigger(criteria, inline_trigger=nil, &block_trigger)
    to_trigger = inline_trigger
    to_trigger ||= block_trigger
    raise(ArgumentError, "must provide a block for the trigger") unless to_trigger
    unless criteria == :success || criteria == :failure || criteria == :any
      raise(ArgumentError, "criteria must be ':success', ':failure' or ':any'")
    end
    @triggers[criteria] << to_trigger
  end

  # Run the triggers for a given success criteria.
  #
  #   e.run_triggers(:success)
  #
  # @param [Symbol] criteria Should be :success, :failure, or :any
  def run_triggers(criteria)
    unless criteria == :success || criteria == :failure 
      raise(ArgumentError, "criteria must be ':success', ':failure' or ':any'")
    end
    [ criteria, :any ].each do |cri|
      @triggers[cri].each do |trigger|
        trigger.call
      end
    end
  end

  # Add a condition to check when determining whether to use current/desired data.
  #
  #   e.condition("truth", lambda { true })
  #
  # @param [String] name The name for this condition
  # @param [optional, Proc] check Takes a lambda/proc to execute, must return true on success or false otherwise.
  # @yield An optional block that will be used in place of the lambda/proc option above
  def condition(name, inline_check=nil, &block_check)
    to_check = inline_check
    to_check ||= block_check
    raise(ArgumentError, "must provide a block for the condition") unless to_check
    @conditions << [ name, to_check ]
  end

  # Evaluate whether the conditions are valid. 
  #
  #   e.evaluate
  #   e.evaluate("and")
  #   e.evaluate("or")
  #
  # If "and" is the operator, will be true if all conditions are true. If "or"
  # is the operator, will be true if any of the conditions are true.
  #
  # @param [String] operator The operator to check - "and" or "or".  
  # @return [Array] Returns [success, result_data]. Success is true or false. Result
  #   data is a hash with the name of the condition as the key, and the value
  #   being the return of the conditions lambda (useful for inspecting why you
  #   failed). 
  def evaluate(operator="and")
    unless operator == "and" || operator == "or"
      raise(ArgumentError, "operator must be 'and' or 'or'")
    end
  
    result_data = {}

    @conditions.each do |condition|
      result_data[condition[0]] = condition[1].call
    end
 
    result = case operator
             when "and"
               result_data.all? { |name, result| result }
             when "or"
               result_data.any? { |name, result| result }
             end
   
    return result, result_data
  end

  # Check which data structure to use. Allows you to set the operator (which gets sent on to evaluate), 
  # a retry_count, and how high the random number to wait should be (in seconds). If you set a retry_count,
  # this method will continue trying to get success retry_count number of times. It will also sleep:
  #
  #   1 + (attempts * 2) + rand(random_wait)
  #
  # Time between attempts.
  #
  # @param [String] operator The operator to check - "and" or "or".  
  # @param [Integer] retry_count The number of times to retry the check.
  # @param [Integer] random_wait How high a number to randomly choose to sleep.
  # @return [Array] Returns a two-element array - the current or desired data,
  #   followed by the result_data from the interanl call to "evaluate"
  def check(operator="and", retry_count=0, random_wait=60)
    attempts = 0
    result = nil
    result_data = nil
    keep_going = 1 

    while keep_going > 0
      attempts += 1 
      keep_going = retry_count - attempts + 1 
      result, result_data = evaluate(operator) 
      if result
        break
      elsif keep_going > 0
        backoff_time = 1 + (attempts * 2) + rand(random_wait)
        sleep backoff_time unless no_sleep
      end
    end

    if result
      run_triggers(:success)
      return @desired, result_data
    else 
      run_triggers(:failure)
      return @current, result_data
    end
  end
end
