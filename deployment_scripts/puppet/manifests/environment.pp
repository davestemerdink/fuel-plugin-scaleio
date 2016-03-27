# Helper for array processing
define environment() {
  $fuel_version = hiera('fuel_version')
  $all_nodes = hiera('nodes')
  $role = $name
  $nodes = $fuel_version ? {
    /(6\.1|7\.0)/   => concat(filter_nodes($all_nodes, 'role', 'primary-controller'), filter_nodes($all_nodes, 'role', 'controller')),
    default         => filter_nodes($all_nodes, 'role', "scaleio-${role}"),
  }
  $hashes         = nodes_to_hash($nodes, 'name', 'storage_address')
  $ips_array_      = ipsort(values($hashes))
  if $fuel_version == '6.1' or $fuel_version == '7.0' {
    $count = count(keys($hashes))
    case $role {
      'tb': {
        $ips_array = $count ? {
          3 => values_at($ips_array_, 2),
          5 => values_at($ips_array_, ['3-4']),
          default => fail("Only configuration cluster_3 and cluster_5 are supported, actualy ${count}")
        }
      }
      'mdm': {
        $ips_array = $count ? {
          3 => values_at($ips_array_, ['0-1']),
          5 => values_at($ips_array_, ['0-2']),
          default => fail("Only configuration cluster_3 and cluster_5 are supported, actualy ${count}")
        }
      }
      'gateway': {
        $ips_array = $ips_array_
      }
      default: {
        fail("Unsupported role ${role}")
      }
    }
  } else {
    $ips_array = $ips_array_
  }
  $ips = join($ips_array, ',')
  notify {"Environment role: ${role}, nodes: ${nodes}, ips: ${ips}": } ->
  file_line { "Append a FACTER_${role}_ips line to /etc/environment":
    ensure  => present,
    path    => '/etc/environment',
    match   => "^FACTER_${role}_ips=",
    line    => "FACTER_${role}_ips=${ips}",
  }
}

$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  notify{'ScaleIO plugin enabled': }
  case $::osfamily {
    'RedHat': {
      fail('This is temporary limitation. The only Ubuntu is supported for now.')
    }
    'Debian': {
      # nothing to do
    }
    default: {
      fail("Unsupported osfamily: ${::osfamily} operatingsystem: ${::operatingsystem}, module ${module_name} only support osfamily RedHat and Debian")
    }
  }
  environment{['mdm', 'tb', 'gateway']: }
} else {
    notify{'ScaleIO plugin disabled': }
}
