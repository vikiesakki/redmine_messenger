# This file is a part of redmine_reporting,
# a reporting and statistics plugin for Redmine.
#
# Copyright (c) 2016-2018 AlphaNodes GmbH
# https://alphanodes.com

require File.expand_path('../../test_helper', __FILE__)

class RoutingTest < Redmine::RoutingTest
  test 'routing sla' do
    should_route 'GET /projects/1/settings/messenger' => 'projects#settings', id: '1', tab: 'messenger'
    should_route 'PUT /projects/1/messenger_setting' => 'messenger_settings#update', project_id: '1'
  end
end
