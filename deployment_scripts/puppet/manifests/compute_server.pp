# Just install packages
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  class {'scaleio::sds_server':
    ensure  => 'present',
  }
  class {'scaleio::sdc_server':
    ensure   => 'present',
    mdm_ip   => undef,
  }
}
