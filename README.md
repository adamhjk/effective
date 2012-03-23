# Effective

Let's you choose between a 'current' and 'desired' state through a series of
conditional checks, and run triggers based on the results.

## Installation

Add this line to your application's Gemfile:

    gem 'effective'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install effective

## Usage

```ruby
require 'effective'

e = Effective.new(1, 2)
e.condition("always true", lambda { true })
result, data = e.check
puts result
# Success, result == 2 

e.condition("always false", lambda { false })
result, data = e.check
puts result
# Failure, result == 1

result, data = e.check("or")
puts result
# Success, result == 2, because we are "or" not "and"-ing.
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

New contributors will need to sign a CLA at http://wiki.opscode.com/display/chef/How+to+Contribute.

## License

Author: adam@opscode.com

Copyright 2012, Opscode, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


