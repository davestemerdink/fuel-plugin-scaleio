# Configure Cinder to use ScaleIO
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if $::gateway_ips {
    $all_nodes = hiera('nodes')
    $nodes = filter_nodes($all_nodes, 'name', $::hostname)
    if empty(filter_nodes($nodes, 'role', 'cinder')) {
      fail('In order to use ScaleIO it is required to isntall Cinder Role on all controller nodes.')
    }
    class {'scaleio_openstack::cinder':
      ensure                     => present,
      gateway_user               => 'admin',
      gateway_password           => $scaleio['gateway_password'],
      gateway_ip                 => $::gateway_ips,
      protection_domains         => $scaleio['protection_domain'],
      storage_pools              => $scaleio['storage_pools'],
    }
  } else {
    fail('Empty Gateway IPs configuration')
  }
}
