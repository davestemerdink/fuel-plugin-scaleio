# Just install packages
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  $node_ips = split($::ip_address_array, ',')
  if empty(intersection(split($::tb_ips, ','), $node_ips)) {
    if empty(intersection(split($::mdm_ips, ','), $node_ips)) {
      fail("Wrong configuration, node_ips (${node_ips}) are not listed in both mdm_ips (${::mdm_ips}) and tb_ips (${::tb_ips})")
    }
    $is_manager = 1
  } else {
    $is_manager = 0
  }
  notify {"Controller server is_manager = ${is_manager}": } ->
  class {'scaleio::mdm_server':
    ensure                   => 'present',
    is_manager               => $is_manager,
    master_mdm_name          => undef,
    mdm_ips                  => undef,
    mdm_management_ips       => undef,
  }
}

