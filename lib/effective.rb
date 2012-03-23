require "effective/version"

class Effective
  attr_accessor :current, :desired, :conditions

  def initialize(current=nil, desired=nil)
    @current = current
    @desired = desired
    @conditions = [] 
  end

  def condition(name, inline_check=nil, &block_check)
    to_check = inline_check
    to_check ||= block_check
    @conditions << [ name, to_check ]
  end

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
        sleep backoff_time
      end
    end
    if result
      return @desired, result_data
    else 
      return @current, result_data
    end
  end
end
