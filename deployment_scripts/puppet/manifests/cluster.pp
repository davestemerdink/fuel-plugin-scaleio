# The puppet configures ScaleIO cluster - adds MDMs, SDSs, sets up
# Protection domains and Storage Pools.

#Helpers for array processing
define mdm_standby() {
  $ip = $name
  notify {"Configure Standby MDM ${ip}": } ->
  scaleio::mdm {"Standby MDM ${name}":
      ensure              => 'present',
      ensure_properties   => 'present',
      name                => $ip,
      role                => 'manager',
      ips                 => $ip,
      management_ips      => $ip,
  }
}

define mdm_tb() {
  $ip = $name
  notify {"Configure Tie-Breaker MDM ${ip}": } ->
  scaleio::mdm {"Tie-Breaker MDM ${name}":
      ensure              => 'present',
      ensure_properties   => 'present',
      name                => $ip,
      role                => 'tb',
      ips                 => $ip,
      management_ips      => undef,
  }
}

define storage_pool_ensure($protection_domain) {
  $sp_name = $title
  scaleio::storage_pool {"Storage Pool ${protection_domain}:${sp_name}": name => $sp_name, protection_domain => $protection_domain } 
}

define sds_device(
  $protection_domain,
  $storage_pools,
  $device_paths,
) {
  $sds_node = $title
  $sds_name = $sds_node['name']
  #ips for data path traffic
  $storage_ips      = $sds_node['storage_address']
  $storage_ip_roles = 'sdc_only'
  #ips for communication with MDM and SDS<=>SDS
  $mgmt_ips      = $sds_node['internal_address']
  $mgmt_ip_roles = 'sds_only'
  if count(split($storage_ips, ',')) != 1 or count(split($mgmt_ips, ',')) != 1 {
    fail("TODO: behaviour changed: address becomes comma-separated list ${storage_ips} or ${mgmt_ips}, so it is needed to add the generation of ip roles")
  }
  if $mgmt_ips == $storage_ips {
    $sds_ips      = "${storage_ips}"
    $sds_ip_roles = 'all'
  }
  else {
    $sds_ips      = "${storage_ips},${mgmt_ips}"
    $sds_ip_roles = "${storage_ip_roles},${mgmt_ip_roles}"
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

define cleanup_sdc () {
  $sdc_ip = $title
  scaleio::sdc {"Remove SDC ${sdc_ip}":
    ensure             => 'absent',
    ip                 => $sdc_ip,
  }
}

define cleanup_sds () {
  $sds_name = $title
  scaleio::sds {"Remove SDS ${sds_name}":
    ensure             => 'absent',
    name               => $sds_name,
  }
}
 

# The only first mdm which is proposed to be the first master does cluster configuration
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if ! $scaleio['existing_cluster'] {
    if $::managers_ips {
      # forbid requesting sdc/sds from discovery facters,
      # this is a workaround of the ScaleIO problem - 
      # these requests hangs in some reason if cluster is in degraded state
      file_line {'SCALEIO_discovery_allowed':
        ensure  => present,
        path    => '/etc/environment',
        match   => "^SCALEIO_discovery_allowed=",
        line    => "SCALEIO_discovery_allowed=no",
      }
      $all_nodes = hiera('nodes')
      # primary controller configures cluster
      if ! empty(filter_nodes(filter_nodes($all_nodes, 'name', $::hostname), 'role', 'primary-controller')) {
        $mdm_ip_array = split($::managers_ips, ',')
        $tb_ip_array = split($::tb_ips, ',')
        $mdm_count = count($mdm_ip_array)
        $tb_count = count($tb_ip_array)
        if $mdm_count < 2 or $tb_count == 0 {
          $cluster_mode = 1
          $standby_ips = []
          $slave_names = undef
          $tb_names    = undef
        } else {
          # primary controller IP is first in the list in case of first deploy and it creates cluster.
          # it's guaranied by the tasks environment.pp and resize_cluster.pp
          # in case of re-deploy the first ip is current master ip
          $standby_ips = delete($mdm_ip_array, $mdm_ip_array[0])        
          if $mdm_count < 3 or $tb_count == 1 {
            $cluster_mode = 3
            $slave_names = join(values_at($standby_ips, "0-0"), ',')
            $tb_names    = join(values_at($tb_ip_array, "0-0"), ',')
          } else {
            $cluster_mode = 5
            # incase of switch 3 to 5 nodes add only standby mdm/tb
            $to_add_slaves = difference(values_at($standby_ips, "0-1"), intersection(values_at($standby_ips, "0-1"), split($::scaleio_mdm_ips, ',')))
            $to_add_tb = difference(values_at($tb_ip_array, "0-1"), intersection(values_at($tb_ip_array, "0-1"), split($::scaleio_tb_ips, ',')))
            $slave_names = join($to_add_slaves, ',')
            $tb_names    = join($to_add_tb, ',')
          }
        }
        $password = $scaleio['password']
        $protection_domain = $scaleio['protection_domain']
        $pools = $scaleio['storage_pools'] ? {
          undef   => undef,
          default => split($scaleio['storage_pools'], ',')
        }
        $compute_nodes  = filter_nodes($all_nodes, 'role', 'compute')		
        if $scaleio['sds_on_controller'] {		
          $controller_nodes  = filter_nodes($all_nodes, 'role', 'controller')		
          $sds_nodes = concat(concat(filter_nodes($all_nodes, 'role', 'primary-controller'), $controller_nodes), $compute_nodes)
        } else {		
          $sds_nodes = $compute_nodes		
        }
        $cinder_nodes = filter_nodes($all_nodes, 'role', 'cinder')   
        $sdc_nodes =concat(flatten($compute_nodes), $cinder_nodes)
        $sdc_nodes_ips = values(nodes_to_hash($sdc_nodes, 'name', 'internal_address'))
        $paths = $scaleio['device_paths'] ? {
          udnef   => undef,
          default => split($scaleio['device_paths'], ',')
        }
        if $paths and $pools {
          $device_paths = join($paths, ',')
          #generate pools for devices if provided one pool
          #otherwise just use provided array
          if count($pools) == 1 {
            $device_storage_pools = join(values(hash(split(regsubst("${device_paths},", ',', ",${pools[0]},", 'G'), ','))), ',')
          } else {
            $device_storage_pools = join($pools, ',')
          }
        } else {
         notify {'Devices and pool will not be configured':}
         $device_paths = undef
         $device_storage_pools = undef
        }  
        notify {"Configure cluster MDM: ${master_mdm}": } ->
        scaleio::login {'Normal':
          password => $password,
          require  => File_line['SCALEIO_discovery_allowed']
        }
        if $::scaleio_current_sdc_list {
          $current_sdc_ips = split($::scaleio_current_sdc_list, ',')
          $to_keep_sdc = intersection($current_sdc_ips, $sdc_nodes_ips)
          $to_remove_sdc = difference($current_sdc_ips, $to_keep_sdc)
          $to_add_sdc_ips = difference($sdc_nodes_ips, $to_keep_sdc)
          # todo: not clear is it safe: actually task sdc is run before cluster task,
          # so there to_add_sdc_ips is always empty, because all SDCs
          # are already registered in cluster and are returned from facter scaleio_current_sdc_list
          notify {"SDC change current='${::scaleio_current_sdc_list}', to_add='${to_add_sdc_ips}', to_remove='${to_remove_sdc}'": } ->
          cleanup_sdc {$to_remove_sdc:
            require             => Scaleio::Login['Normal'],
          }
        } else {
          $to_add_sdc_ips = $sdc_nodes_ips
          notify {"No resize cluster, new sdc-es '${to_add_sdc_ips}'": }
        }
        if $::scaleio_current_sds_list {
          $current_sds_names = split($::scaleio_current_sds_list, ',')
          $new_sds_names = keys(nodes_to_hash($sds_nodes, 'name', 'internal_address'))
          $to_remove_sds = difference($current_sds_names, intersection($current_sds_names, $new_sds_names))
          notify {"SDS change current='${::scaleio_current_sds_list}' new='${new_sds_names}' to_remove='${to_remove_sds}'": } ->
          cleanup_sds {$to_remove_sds:
            require             => Scaleio::Login['Normal'],
          }
        }
        if $cluster_mode != 1 {
          mdm_standby {$standby_ips:
            require             => Scaleio::Login['Normal'],          
          } ->
          mdm_tb{$tb_ip_array:} ->
          scaleio::cluster {'Configure cluster mode':
            ensure              => 'present',
            cluster_mode        => $cluster_mode,
            slave_names         => $slave_names,
            tb_names            => $tb_names,
          }
        }
        scaleio::protection_domain {"Ensure protection domain ${protection_domain}":
          name                => $protection_domain,
          require             => Scaleio::Login['Normal'],          
        } ->
        storage_pool_ensure {$pools: protection_domain => $protection_domain } ->
        sds_device {$sds_nodes:		
            protection_domain => $protection_domain,		
            storage_pools     => $device_storage_pools,		
            device_paths      => $device_paths,		
        }
        # Apply high performance profile to SDC-es
        # Use first sdc ip because underlined puppet uses all_sdc parameters
        if count($sdc_nodes_ips) > 0 {
          scaleio::sdc {'Set performance settings for all available SDCs':
            ip                => $sdc_nodes_ips[0],
            require           => Sds_device[$sds_nodes],
          }
        }
      } else {
        notify {"Not Master MDM IP ${master_mdm}": }
      }      
      file_line {'SCALEIO_mdm_ips':
        ensure  => present,
        path    => '/etc/environment',
        match   => "^SCALEIO_mdm_ips=",
        line    => "SCALEIO_mdm_ips=${::managers_ips}",
      }
    } else {
      fail('Empty MDM IPs configuration')
    }
  } else {
    notify{'Skip configuring cluster because of using existing cluster': }
  }
}
