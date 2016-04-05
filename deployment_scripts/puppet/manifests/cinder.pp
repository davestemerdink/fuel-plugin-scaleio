# The puppet configures OpenStack cinder to use ScaleIO.

$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  $all_nodes = hiera('nodes')
  $nodes = filter_nodes($all_nodes, 'name', $::hostname)
  if empty(filter_nodes($nodes, 'role', 'cinder')) {
    fail("Cinder Role is not found on the host ${::hostname}")
  }
  class {'scaleio_openstack::cinder':
    ensure                     => present,
    gateway_user               => $::gateway_user,
    gateway_password           => $scaleio['gateway_password'],
    gateway_ip                 => hiera('management_vip'),
    gateway_port               => $::gateway_port,
    protection_domains         => $scaleio['protection_domain'],
    storage_pools              => $::storage_pools,
  }
}
