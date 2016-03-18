# Just install packages
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  class {'scaleio::mdm_server':
    ensure                   => 'present',
    is_manager               => 0,
    master_mdm_name          => undef,
    mdm_ips                  => undef,
    mdm_management_ips       => undef,
  }
}
