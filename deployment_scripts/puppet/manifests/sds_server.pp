define sds_device_cleanup() {
  $device = $title
  exec { "device ${device} cleaup":
    command => "bash -c 'for i in \$(parted ${device} print | awk \"/^ [0-9]+/ {print(\\\$1)}\"); do parted ${device} rm \$i; done'",
    path => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
  }
}

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
    $devices = split($scaleio['device_paths'], ',')
    class {'scaleio::sds_server':
      ensure  => 'present',
    } ->
    sds_device_cleanup {$devices: }
  }
}

