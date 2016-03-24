#Helping defines for array processings
define sds_device_cleanup() {
  $device = $title
  exec { "device ${device} cleaup":
    command => "bash -c 'for i in \$(parted ${device} print | awk \"/^ [0-9]+/ {print(\\\$1)}\"); do parted ${device} rm \$i; done'",
    path => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
  }
}

define sds(
  $protection_domain,
  $storage_pools,
  $device_paths,
) {
  $sds_node     = $title
  $sds_name     = $sds_node['name']
  $sds_ips      = $sds_node['storage_address']
  $sds_ip_roles = undef # TODO: set to 'all' as unless_query appears in scaleio::sds for role updates
  if count(split($sds_ips, ',')) != 1 {
    fail("TODO: behaviour changed - storage_address becomes coma-separated list ${sds_ips}, so it is needed to add the generation of ip roles")
  }
  scaleio::sds {$sds_name:
    ensure             => 'present',
    ensure_properties  => undef,
    name               => $sds_name,
    protection_domain  => $protection_domain,
    fault_set          => undef,
    port               => undef,
    ips                => $sds_ips,
    ip_roles           => $sds_ip_roles,
    storage_pools      => $storage_pools,
    device_paths       => $device_paths,
  }
}

# Main
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
    $all_nodes  = hiera('nodes')
    $nodes  = filter_nodes($all_nodes, 'name', $::hostname)
    $sds_node = $nodes[0]    #just take first element, there could be more than 1 if the node plays more than 1 role
    $paths = $scaleio['device_paths'] ? {
      udnef   => undef,
      default => split($scaleio['device_paths'], ',')
    }
    $storage_pools = $scaleio['storage_pools'] ? {
      undef   => undef,
      default => split($scaleio['storage_pools'], ',')
    }
    if $paths and $storage_pools {
      #generate array of pools with lenght of device_paths
      $device_paths = join($paths, ',')
      #generate pools for devices if provided one pool
      #otherwise just use provided array
      if count($storage_pools) == 1 {
        $device_storage_pools = join(values(hash(split(regsubst("${device_paths},", ',', ",${storage_pools[0]},", 'G'), ','))), ',')
      } else {
        $device_storage_pools = join($storage_pools, ',')
      }
    } else {
      notify {'Devices and pool will not be configured':}
      $device_paths = undef
      $device_storage_pools = undef
    }

    sds_device_cleanup {$device_paths: } ->
    scaleio::login {'Normal': password => $scaleio['password'] } ->
    notify {"Pools and Devices ${device_storage_pools} / ${device_paths}": } ->
    sds {$sds_node:
      protection_domain => $protection_domain,
      storage_pools     => $device_storage_pools,
      device_paths      => $device_paths,
    }
  }
}

