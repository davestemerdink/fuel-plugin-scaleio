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
    if $fuel_version <= '8.0' {
      #it is supposed that task is run on compute or controller
      $node_ips = split($::ip_address_array, ',')
      $is_sds_server = empty(intersection(split($::controller_ips, ','), $node_ips)) or $scaleio['sds_on_controller']
    } else {
      $all_nodes = hiera('nodes')
      $nodes = filter_nodes($all_nodes, 'name', $::hostname)
      $is_sds_server = ! empty(concat(filter_nodes($nodes, 'role', 'scaleio-storage-tier1'), filter_nodes($nodes, 'role', 'scaleio-storage-tier2')))
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
