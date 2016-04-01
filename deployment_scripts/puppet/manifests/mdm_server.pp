# Just install packages
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if ! $scaleio['existing_cluster'] {
    $node_ips = split($::ip_address_array, ',')
    $is_tb    = ! empty(intersection(split($::tb_ips, ','), $node_ips))
    $is_mdm  = ! empty(intersection(split($::mdm_ips, ','), $node_ips))
    if $is_tb or $is_mdm {
      if $is_tb {
        $is_manager = 0
      } else {
        $is_manager = 1
      }
      notify {"Controller server is_manager = ${is_manager}": } ->
      class {'scaleio::mdm_server':
        ensure                   => 'present',
        is_manager               => $is_manager,
        master_mdm_name          => undef,
        mdm_ips                  => undef,
        mdm_management_ips       => undef,
      }
    } else {
      notify{'Skip deploying mdm server because it is not mdm and tb': }
    }
  } else {
    notify{'Skip deploying mdm server because of usign existing cluster': }
  }
}

