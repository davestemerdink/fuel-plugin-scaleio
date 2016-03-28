# Configure Cinder to use ScaleIO
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if ! $::mdm_ips {
    fail('Empty MDM IPs configuration')    
  }
  if ! $::gateway_ips {
    fail('Empty Gateway IPs configuration')    
  }
  $all_nodes = hiera('nodes')
  $nodes = filter_nodes($all_nodes, 'name', $::hostname)
  if empty(filter_nodes($nodes, 'role', 'cinder')) {
    fail("Cinder Role is not found on the host ${::hostname}")
  }
  #TODO: after HA impl replace gw_ip  with  hiera('management_vip')
  #      for now just use own gateway or GW on master-controller 
  $possible_ips = intersection(split($::gateway_ips, ','), split($::ip_address_array, ','))
  if count($possible_ips) > 0 {
    $gw_ip = $possible_ips[0]
  } else {
    $gw_ip = $::gateway_ips[0]
  }
  class {'scaleio::sdc_server':
    ensure  => 'present',
    mdm_ip  => $::mdm_ips,
  } ->  
  class {'scaleio_openstack::cinder':
    ensure                     => present,
    gateway_user               => $::gateway_user,
    gateway_password           => $scaleio['gateway_password'],
    gateway_ip                 => $gw_ip,
    gateway_port               => $::gateway_port,
    protection_domains         => $scaleio['protection_domain'],
    storage_pools              => $::storage_pools,
  }
}
