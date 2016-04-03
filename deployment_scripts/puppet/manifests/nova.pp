# The puppet configures OpenStack nova to use ScaleIO.

$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if ! $::gateway_ips {
    fail('Empty Gateway IPs configuration')    
  }
  $all_nodes = hiera('nodes')
  $nodes = filter_nodes($all_nodes, 'name', $::hostname)
  if empty(filter_nodes($nodes, 'role', 'compute')) {
    fail("Compute Role is not found on the host ${::hostname}")
  }  
  #TODO: after HA impl replace gw_ip  with  hiera('management_vip')
  #      for now just use own gateway or GW on master-controller 
  $ips = split($::gateway_ips, ',')
  $possible_ips = intersection($ips, split($::ip_address_array, ','))
  if count($possible_ips) > 0 {
    $gw_ip = $possible_ips[0]
  } else {
    $gw_ip = $ips[0]
  }
  class {'scaleio_openstack::nova':
    ensure              => present,
    gateway_user        => $::gateway_user,
    gateway_password    => $scaleio['gateway_password'],
    gateway_ip          => $gw_ip,
    gateway_port        => $::gateway_port,
    protection_domains  => $scaleio['protection_domain'],
    storage_pools       => $::storage_pools,
 }
}
