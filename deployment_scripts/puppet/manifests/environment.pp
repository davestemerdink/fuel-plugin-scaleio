# The puppet defines environment and facters for all of the further puppets.

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
  #use management network for ScaleIO components communications
  $hashes         = nodes_to_hash($nodes, 'name', 'internal_address')
  $ips_array_      = ipsort(values($hashes))
  $cur_mdms = $::scaleio_mdm_ips ? {
    undef   => [],
    default => split($::scaleio_mdm_ips, ',')
  }
  $cur_tb_mdms = $::scaleio_tb_ips ? {
    undef   => [],
    default => split($::scaleio_tb_ips, ',')
  }
  if $fuel_version == '6.1' or $fuel_version == '7.0' {
    $count = count(keys($hashes))
    $to_keep_mdm = intersection($cur_mdms, $ips_array_)
    $to_keep_tb = intersection($cur_tb_mdms, $ips_array_)
    $to_keep_nodes = concat($to_keep_mdm, $to_keep_tb)
    $available_nodes = difference($ips_array_, intersection($ips_array_, $to_keep_nodes))
    $available_nodes_count = count($available_nodes)
    case $role {
      'tb': {
        if $count < 3 {
          $to_add_tb_count = 0
        } else {
          if $count < 5 {
            $to_add_tb_count = 1 - count($to_keep_tb)
          } else {
            $to_add_tb_count = 2 - count($to_keep_tb)
          }
        }
        if $to_add_tb_count > 0 and $available_nodes_count >= $to_add_tb_count {
          $last_tb_index = $available_nodes_count - 1
          $first_tb_index = $last_tb_index - $to_add_tb_count + 1
          $ips_array = concat($to_keep_tb, values_at($available_nodes, "${first_tb_index}-${last_tb_index}"))
        } else {
          $ips_array = $to_keep_tb
        }                  
      }
      'mdm': {
        if $count < 3 {
          $to_add_mdm_count = 1 - count($to_keep_mdm)
        } else {
          if $count < 5 {
            $to_add_mdm_count = 2 - count($to_keep_mdm)
          } else {
            $to_add_mdm_count = 3 - count($to_keep_mdm)
          }
        }
        if $to_add_mdm_count > 0 and $available_nodes_count >= $to_add_mdm_count {
          $last_mdm_index = $to_add_mdm_count - 1
          $ips_array = concat($to_keep_mdm, values_at($available_nodes, "0-${last_mdm_index}"))
        } else {
          $ips_array = $to_keep_mdm
        }                  
      }
      'gateway': {
        $ips_array = $ips_array_
      }
      'controller': {
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
    command => "bash -c 'while [ ! -f /tmp/go ]; do :; done'",
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
    environment{['mdm', 'tb', 'gateway', 'controller']: } ->
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
