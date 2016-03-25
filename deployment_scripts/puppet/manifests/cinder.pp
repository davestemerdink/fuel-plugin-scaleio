# Configure Cinder to use ScaleIO
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if $::gateway_ips {
    $all_nodes = hiera('nodes')
    $nodes = filter_nodes($all_nodes, 'name', $::hostname)
    if empty(filter_nodes($nodes, 'role', 'cinder')) {
      fail('In order to use ScaleIO it is required to isntall Cinder Role on all controller nodes.')
    }
    
    #TODO: after HA impl replace gw_ip  with  hiera('management_vip')
    #      for now just use own gateway or GW on master-controller 
    $possible_ips = intersection(split($::gateway_ips, ','), split($::ip_address_array, ','))
    if count($possible_ips) > 0 {
      $gw_ip = $possible_ips[0]
    } else {
      $gw_ip = $::gateway_ips[0]
    }
    class {'scaleio_openstack::cinder':
      ensure                     => present,
      gateway_user               => 'admin',
      gateway_password           => $scaleio['gateway_password'],
      gateway_ip                 => $gw_ip,
      protection_domains         => $scaleio['protection_domain'],
      storage_pools              => $scaleio['storage_pools'],
    }
  } else {
    fail('Empty Gateway IPs configuration')
  }
}
