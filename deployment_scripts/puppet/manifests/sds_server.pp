# The puppet installs ScaleIO SDS packages

# helping define for array processing
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
  if ! $scaleio['existing_cluster'] {      
    $fuel_version = hiera('fuel_version')
    if $fuel_version == '6.1' {
      $is_sds_server = empty(intersection(split($::mdm_ips, ','), $node_ips)) or $scaleio['sds_on_controller']
    } else {
      $all_nodes = hiera('nodes')
      $nodes = filter_nodes($all_nodes, 'name', $::hostname)
      $is_sds_server = !empty(filter_nodes($nodes, 'role', 'scaleio-storage'))
    }
    if $is_sds_server {
      if $scaleio['device_paths'] {
        $devices = split($scaleio['device_paths'], ',')
        sds_device_cleanup {$devices:
          before => Class['scaleio::sds_server']
        }
      }
      class {'scaleio::sds_server':
        ensure  => 'present',
      }
    }
  } else {
    notify{'Skip sds server because of using existing cluster': }
  }
}
