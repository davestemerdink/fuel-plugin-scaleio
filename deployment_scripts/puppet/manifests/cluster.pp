# The puppet configures ScaleIO cluster - adds MDMs, SDSs, sets up
# Protection domains and Storage Pools.

#Helpers for array processing
define mdm_standby() {
  $ip = $title
  notify {"Configure Standby MDM ${ip}": } ->
  scaleio::mdm {"Standby MDM ${ip}":
      ensure              => 'present',
      ensure_properties   => 'present',
      name                => $ip,
      role                => 'manager',
      ips                 => $ip,
      management_ips      => $ip,
  }
}

define mdm_tb() {
  $ip = $title
  notify {"Configure Tie-Breaker MDM ${ip}": } ->
  scaleio::mdm {"Tie-Breaker MDM ${ip}":
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
  $sds_nodes,
  $protection_domain,
  $storage_pools,
  $device_paths,
) {
  $sds_name = $title
  $sds_node = filter_nodes($sds_nodes, 'name', $sds_name)[0]
  #ips for data path traffic
  $storage_ips      = $sds_node['storage_address']
  $storage_ip_roles = 'sdc_only'
  #ips for communication with MDM and SDS<=>SDS
  $mgmt_ips      = $sds_node['internal_address']
  $mgmt_ip_roles = 'sds_only'
  if count(split($storage_ips, ',')) != 1 or count(split($mgmt_ips, ',')) != 1 {
    fail("TODO: behaviour changed: address becomes comma-separated list ${storage_ips} or ${mgmt_ips}, so it is needed to add the generation of ip roles")
  }
  $sds_ips      = "${storage_ips},${mgmt_ips}"
  $sds_ip_roles = "${storage_ip_roles},${mgmt_ip_roles}"
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
    if $::mdm_ips {
      $mdm_ip_array = split($::mdm_ips, ',')
      $tb_ip_array = split($::tb_ips, ',')
      if has_ip_address($mdm_ip_array[0]) {
        $all_nodes = hiera('nodes')
        $storage_nodes = concat(filter_nodes($all_nodes, 'role', 'scaleio-storage'), filter_nodes($all_nodes, 'role', 'compute'))
        if $scaleio['sds_on_controller'] {    
          $controller_nodes  = filter_nodes($all_nodes, 'role', 'controller')   
          $pr_controller_nodes = filter_nodes($all_nodes, 'role', 'primary-controller')
          $sds_nodes = concat(concat($pr_controller_nodes, $controller_nodes), $storage_nodes)
        } else {    
          $sds_nodes = $storage_nodes
        }
        $sds_nodes_names = keys(nodes_to_hash($sds_nodes, 'name', 'internal_address'))
        $sds_nodes_count = count($sds_nodes_names)
        $sdc_nodes =concat(filter_nodes($all_nodes, 'role', 'compute'), filter_nodes($all_nodes, 'role', 'cinder'))
        $sdc_nodes_ips = values(nodes_to_hash($sdc_nodes, 'name', 'internal_address'))
        $standby_mdm_count = count($mdm_ip_array) - 1
        if $standby_mdm_count == 0 {
          $standby_ips = []
          $slave_names = undef
          $tb_names    = undef
        } else {
          $standby_ips = delete($mdm_ip_array, $mdm_ip_array[0]) # first is proposed to be muster or is current mdm
          $slave_names = join($standby_ips, ',')
          $tb_names    = join($tb_ip_array, ',')
        }
        $total_mdm_count = count($mdm_ip_array) + count($tb_ip_array)
        if $total_mdm_count < 3 {
          $cluster_mode = 1
        } else {
          if $total_mdm_count < 5 {
            $cluster_mode = 3
          } else {
            $cluster_mode = 5
          }
        }
        $password = $scaleio['password']
        $protection_domain_number = 1 + $sds_nodes_count / $scaleio['protection_domain_nodes']
        $protection_domain =  $protection_domain_number ? {
          1       => $scaleio['protection_domain'],
          default => "${scaleio['protection_domain']}_${protection_domain_number}"
        }
        $tier1_devices = split($::sds_storage_devices_tier1, ',')
        $tier2_devices = split($::sds_storage_devices_tier2, ',')
        if $scaleio['device_paths'] {
          # for fuel6.1 devices come from settings
          $paths_ = split($scaleio['device_paths'], ',')
          $paths = count($paths_) > 0 ? {
            true    => $paths_,
            default => undef
          }
        } else {
          # for fuel 7.0 devices come from facter (search partition by guid)
          $tier12_paths = concat(split($::sds_storage_devices_tier1, ','), $tier2_devices) # concat changes first array!!
          $paths = count(tier12_paths) > 0 ? {
            true    => tier12_paths,
            default => undef
          }
        }
        if $scaleio['storage_pools'] {
          # for fuel6.1 storage pools come from settings
          $pools_ = split($scaleio['storage_pools'], ',')
          $pools = count($pools_) > 0 ? {
            true    => $pools_,
            default => undef
          }
        } else {  
          # for fuel 7.0 storage pools are generated for two storage tier2
          $tier1_devices_str = join($tier1_devices, ',')
          $storage_pools_tier1 = count($tier1_devices) > 0 ? {
            false   => [],
            default => join(values(hash(split(regsubst("${tier1_devices_str},", ',', ",sp_tier1,", 'G'), ','))), ',')
          }  
          $tier2_devices_str = join($tier2_devices, ',')
          $storage_pools_tier2 = count($tier2_devices) > 0 ? {
            false   => [],
            default => join(values(hash(split(regsubst("${tier2_devices_str},", ',', ",sp_tier2,", 'G'), ','))), ',')
          }
          $tier12_pools = concat($storage_pools_tier1, $storage_pools_tier2)
          $pools = count($tier12_pools) > 0 ? {
            false   => undef,
            default => $tier12_pools
          }
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
        scaleio::login {'Normal': password => $password }
        if $::scaleio_sdc_ips {
          $current_sdc_ips = split($::scaleio_sdc_ips, ',')
          $to_keep_sdc = intersection($current_sdc_ips, $sdc_nodes_ips)
          $to_remove_sdc = difference($current_sdc_ips, $to_keep_sdc)
          # todo: not clear is it safe: actually task sdc is run before cluster task,
          # so there to_add_sdc_ips is always empty, because all SDCs
          # are already registered in cluster and are returned from facter scaleio_current_sdc_list
          notify {"SDC change current='${::scaleio_current_sdc_list}', to_add='${to_add_sdc_ips}', to_remove='${to_remove_sdc}'": } ->
          cleanup_sdc {$to_remove_sdc:
            require             => Scaleio::Login['Normal'],
          }
        }
        if $::scaleio_sds_names {
          $current_sds_names = split($::scaleio_sds_names, ',')
          $to_keep_sds = intersection($current_sds_names, $sds_nodes_names)
          $to_add_sds_names = difference($sds_nodes_names, $to_keep_sds)
          $to_remove_sds = difference($current_sds_names, $to_keep_sds)
          notify {"SDS change current='${::scaleio_current_sds_list}' new='${new_sds_names}' to_remove='${to_remove_sds}'": } ->
          cleanup_sds {$to_remove_sds:
            require             => Scaleio::Login['Normal'],
          }
        } else {
          $to_add_sds_names = $sds_nodes_names
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
        sds_device {$to_add_sds_names:
            sds_nodes         => $sds_nodes,		
            protection_domain => $protection_domain,		
            storage_pools     => $device_storage_pools,		
            device_paths      => $device_paths,		
        }
        # Apply high performance profile to SDC-es
        # Use first sdc ip because underlined puppet uses all_sdc parameters
        if count($sdc_nodes_ips) > 0 {
          scaleio::sdc {'Set performance settings for all available SDCs':
            ip                => $sdc_nodes_ips[0],
            require           => Sds_device[$to_add_sds_names],
          }  
        }
      } else {
        notify {"Not Master MDM IP ${master_mdm}": }
      }
    } else {
      fail('Empty MDM IPs configuration')
    }
  } else {
    notify{'Skip configuring cluster because of using existing cluster': }
  }
}
