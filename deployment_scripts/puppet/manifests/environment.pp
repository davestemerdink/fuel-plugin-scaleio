define env_fact($role, $fact, $value) {
  file_line { "Append a FACTER_${role}_${fact} line to /etc/environment":
    ensure  => present,
    path    => '/etc/environment',
    match   => "^FACTER_${role}_${fact}=",
    line    => "FACTER_${role}_${fact}=${value}",
  }  
}

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
          0       => undef,
          1       => [],
          2       => [],
          3       => values_at($ips_array_, 2),
          4       => values_at($ips_array_, 2),
          default => values_at($ips_array_, ['3-4']),
        }
        if ! $ips_array {
          fail("Only configuration cluster_3 and cluster_5 are supported, actualy ${count}")
        }
      }
      'mdm': {
        $ips_array = $count ? {
          0       => undef,
          1       => $ips_array_,
          2       => values_at($ips_array_, 0),
          3       => values_at($ips_array_, ['0-1']),
          4       => values_at($ips_array_, ['0-1']),
          default => values_at($ips_array_, ['0-2']),
        }
        if ! $ips_array {
          fail("Only configuration cluster_3 and cluster_5 are supported, actualy ${count}")
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
  env_fact {"Environment fact: ${role}, nodes: ${nodes}, ips: ${ips}":
    role  => $role,
    fact  => 'ips',
    value => $ips,
  }
}

$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  notify{'ScaleIO plugin enabled': }
  # The following exec allows interrupt for debugging at the very beginning of the plugin deployment
  # because Fuel doesn't provide any tools for this and deployment can last for more than two hours.
  # Timeouts in tasks.yaml and in the deployment_tasks.yaml (which in 6.1 is not user-exposed and
  # can be found for example in astute docker container during deloyment) should be set to high values.
  # It'll be invoked only if /tmp/scaleio_debug file exists on particular node and you can use 
  # "touch /tmp/go" when you're ready to resume.
  exec { "Wait on debug interrupt: use touch /tmp/go to resume":
    command => "bash -c 'while [ ! -f /tmp/go ]; '",
    path => [ '/bin/' ],
    onlyif => "ls /tmp/scaleio_debug",
  }
  case $::osfamily {
    'RedHat': {
      fail('This is a temporary limitation. ScaleIO supports only Ubuntu for now.')
    }
    'Debian': {
      # nothing to do
    }
    default: {
      fail("Unsupported osfamily: ${::osfamily} operatingsystem: ${::operatingsystem}, module ${module_name} only support osfamily RedHat and Debian")
    }
  }
  $all_nodes = hiera('nodes')
  if count(filter_nodes($all_nodes, 'role', 'cinder')) == 0 {
    fail('At least one Node with Cinder role is required')
  }
  if $scaleio['existing_cluster'] {
    # Existing ScaleIO cluster attaching
    notify{'Use existing ScaleIO cluster': }
    env_fact{"Environment fact: role gateway, ips: ${scaleio['gateway_ip']}":
      role => 'gateway',
      fact => 'ips',
      value => $scaleio['gateway_ip']
    } ->
    env_fact{"Environment fact: role gateway, user: ${scaleio['gateway_user']}":
      role => 'gateway',
      fact => 'user',
      value => $scaleio['gateway_user']
    } ->
    env_fact{"Environment fact: role gateway, password: ${scaleio['gateway_password']}":
      role => 'gateway',
      fact => 'password',
      value => $scaleio['gateway_password']
    } ->
    env_fact{"Environment fact: role gateway, port: ${scaleio['gateway_port']}":
      role => 'gateway',
      fact => 'port',
      value => $scaleio['gateway_port']
    } ->
    env_fact{"Environment fact: role storage, pools: ${scaleio['existing_storage_pools']}":
      role => 'storage',
      fact => 'pools',
      value => $scaleio['existing_storage_pools']
    }
    # mdm_ips are requested from gateways in separate manifest because no way to pass args to facter
  } 
  else {
    # New ScaleIO cluster deployment
    $controller_sds_count = $scaleio['sds_on_controller'] ? {
      true    => count(concat(filter_nodes($all_nodes, 'role', 'primary-controller'), filter_nodes($all_nodes, 'role', 'controller'))),
      default => 0  
    }
    $total_sds_count = count(filter_nodes($all_nodes, 'role', 'compute')) + $controller_sds_count
    if $total_sds_count < 3 {
      fail('There should be at least 3 nodes with SDSs, either add Compute node or use Controllers as SDS.')
    }
    $nodes = filter_nodes($all_nodes, 'name', $::hostname)
    if ! empty(filter_nodes($nodes, 'role', 'cinder')) {
      notify {"Ensure devices size are greater than 100GB for Cinder Node ${::hostname}": }
      #TODO: add check devices sizes
    }
    notify{'Deploy new ScaleIO cluster': }
    environment{['mdm', 'tb', 'gateway']: } ->
    env_fact{'Environment fact: role gateway, user: admin':
      role => 'gateway',
      fact => 'user',
      value => 'admin'
    } ->
    env_fact{'Environment fact: role gateway, port: 4443':
      role => 'gateway',
      fact => 'port',
      value => 4443
    } ->
    env_fact{"Environment fact: role storage, pools: ${scaleio['storage_pools']}":
      role => 'storage',
      fact => 'pools',
      value => $scaleio['storage_pools']
    }
  }
} else {
    notify{'ScaleIO plugin disabled': }
}
