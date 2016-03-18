# Just install packages
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  class {'scaleio::gateway_server':
    ensure   => 'present',
    mdm_ips  => udnef,
    password => udnef,
  }
}
