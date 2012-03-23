.. effective documentation master file, created by
   sphinx-quickstart on Thu Mar 22 19:48:08 2012.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Welcome to effective's documentation!
=====================================

The intent here is to be able to decide whether or not we should be moving to a
new state - whether or not now is the time to "effect" the change.

.. code-block:: ruby

  Effective.new
  e.check
  Effective.check({ "version" => 1 }, { "version" => 2 }, lambda { true }, true ) do |data|
    # data == { "version" => 2 } if all the conditions are met
    # data == { "version" => 1 } if the conditions are not met
  end

The check involves the "current" state, a "desired" state, and a series of
checks which must all evaluate to true in order to get the next state. The
block you pass will get the right data passed in.

Inside of chef..

.. code-block:: ruby

  effective Chef::DataBagItem.load("current_state"), 
            Chef::DataBagItem.load("desired_state"),
            :operator => "and",
            :retry_count => 10,
            :conditions => [ 
              lambda { search(:nodes, "datacenter:las_vegas").all? { |n| n[:current_state] == 1 }} 
            ]


.. toctree::
   :maxdepth: 2

Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`

