# Just install packages
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  $node_ips = split($::ip_address_array, ',')
  if empty(intersection(split($::mdm_ips, ','), $node_ips)) {
    #it is supposed that task is run on compute
    $is_sds_server = true
  } else {
    $is_sds_server = $scaleio['sds_on_controller']
  }
  if $is_sds_server {
    class {'scaleio::sds_server':
      ensure  => 'present',
    }
  }
}

