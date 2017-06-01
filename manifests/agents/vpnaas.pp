#
# Copyright (C) 2013 eNovance SAS <licensing@enovance.com>
#
# Author: Emilien Macchi <emilien.macchi@enovance.com>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
# == Class: neutron::agents:vpnaas
#
# Setups Neutron VPN agent.
#
# === Parameters
#
# [*package_ensure*]
#   (optional) Ensure state for package. Defaults to 'present'.
#
# [*enabled*]
#   (optional) Enable state for service. Defaults to 'true'.
#
# [*manage_service*]
#   (optional) Whether to start/stop the service
#   Defaults to true
#
# [*vpn_device_driver*]
#   (optional) Defaults to 'neutron.services.vpn.device_drivers.ipsec.OpenSwanDriver'.
#
# [*interface_driver*]
#  (optional) Defaults to 'neutron.agent.linux.interface.OVSInterfaceDriver'.
#
# [*ipsec_status_check_interval*]
#   (optional) Status check interval. Defaults to $::os_service_default.
#
# [*purge_config*]
#   (optional) Whether to set only the specified config options
#   in the vpnaas config.
#   Defaults to false.
#
# === Deprecated Parameters
#
# [*external_network_bridge*]
#  (optional) Deprecated. Defaults to $::os_service_default
#
class neutron::agents::vpnaas (
  $package_ensure              = present,
  $enabled                     = true,
  $manage_service              = true,
  $vpn_device_driver           = 'neutron.services.vpn.device_drivers.ipsec.OpenSwanDriver',
  $interface_driver            = 'neutron.agent.linux.interface.OVSInterfaceDriver',
  $external_network_bridge     = $::os_service_default,
  $ipsec_status_check_interval = $::os_service_default,
  $purge_config                = false,
) {

  include ::neutron::deps
  include ::neutron::params

  case $vpn_device_driver {
    /\.OpenSwan/: {
      Package['openswan'] -> Package<| title == 'neutron-vpnaas-agent' |>
      package { 'openswan':
        ensure => $package_ensure,
        name   => $::neutron::params::openswan_package,
        tag    => ['neutron-support-package', 'openstack'],
      }
    }
    /\.LibreSwan/: {
      if($::osfamily != 'Redhat') {
        fail("LibreSwan is not supported on osfamily ${::osfamily}")
      } else {
        Package['libreswan'] -> Package<| title == 'neutron-vpnaas-agent' |>
        package { 'libreswan':
          ensure => $package_ensure,
          name   => $::neutron::params::libreswan_package,
          tag    => ['neutron-support-package', 'openstack'],
        }
      }
    }
    /\.StrongSwan/: {
      Package['strongswan'] -> Package<| title == 'neutron-vpnaas-agent' |>
      package { 'strongswan':
        ensure => $package_ensure,
        name   => 'strongswan', # $::neutron::params::strongswan_package,
        tag    => ['neutron-support-package', 'openstack'],
      }
    }
    default: {
      fail("Unsupported vpn_device_driver ${vpn_device_driver}")
    }
  }

  resources { 'neutron_vpnaas_agent_config':
    purge => $purge_config,
  }

  # The VPNaaS agent loads both neutron.ini and its own file.
  # This only lists config specific to the agent.  neutron.ini supplies
  # the rest.
  neutron_vpnaas_agent_config {
    'vpnagent/vpn_device_driver':        value => $vpn_device_driver;
    'ipsec/ipsec_status_check_interval': value => $ipsec_status_check_interval;
    'DEFAULT/interface_driver':          value => $interface_driver;
  }

  if ! is_service_default ($external_network_bridge) {
    warning('parameter external_network_bridge is deprecated')
  }

  neutron_vpnaas_agent_config {
    'DEFAULT/external_network_bridge': value => $external_network_bridge;
  }

  if $::neutron::params::vpnaas_agent_package {
    ensure_resource( 'package', 'neutron-vpnaas-agent', {
      'ensure' => $package_ensure,
      'name'   => $::neutron::params::vpnaas_agent_package,
      'tag'    => ['openstack', 'neutron-package'],
    })
  }

  if $manage_service {
    if $enabled {
      $service_ensure = 'running'
    } else {
      $service_ensure = 'stopped'
    }
    service { 'neutron-vpnaas-service':
      ensure => $service_ensure,
      name   => $::neutron::params::vpnaas_agent_service,
      enable => $enabled,
      tag    => 'neutron-service',
    }
  }

}
