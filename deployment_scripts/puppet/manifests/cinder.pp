# Configure Cinder to use ScaleIO
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if $::gateway_ips {
    $protection_domains = split($scaleio['protection_domain'], ',')
    $storage_pools = split($scaleio['storage_pool'], ',')
    class {'scaleio_openstack::cinder':
      ensure                     => present,
      gateway_user               => 'admin',
      gateway_password           => $scaleio['gateway_password'],
      gateway_ip                 => $::gateway_ips,
      protection_domains         => $scaleio['protection_domain'],
      storage_pools              => $scaleio['storage_pool'],
    }
  } else {
    fail('Empty Gateway IPs configuration')
  }
}
