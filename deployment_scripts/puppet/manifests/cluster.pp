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

define cleanup_mdm () {
  $mdm_name = $title
  scaleio::mdm {"Remove MDM ${mdm_name}":
    ensure             => 'absent',
    name               => $mdm_name,
  }
}
 

# The only first mdm which is proposed to be the first master does cluster configuration
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if ! $scaleio['existing_cluster'] {
    if $::mdm_ips {
      $mdm_ip_array = split($::mdm_ips, ',')
      $tb_ip_array = split($::tb_ips, ',')
      $master_mdm = $::current_master_mdm_ip ? {
        undef   => $mdm_ip_array[0],
        default => $::current_master_mdm_ip
      }
      if has_ip_address($master_mdm) {
        $all_nodes = hiera('nodes')
        $compute_nodes  = filter_nodes($all_nodes, 'role', 'compute')   
        if $scaleio['sds_on_controller'] {    
          $controller_nodes  = filter_nodes($all_nodes, 'role', 'controller')   
          $pr_controller_nodes = filter_nodes($all_nodes, 'role', 'primary-controller')   
          $sds_nodes = concat(concat($pr_controller_nodes, $controller_nodes), $compute_nodes)
        } else {    
          $sds_nodes = $compute_nodes   
        }
        $cinder_nodes = filter_nodes($all_nodes, 'role', 'cinder')   
        $sdc_nodes =concat($compute_nodes, $cinder_nodes)
        $standby_mdm_count = count($mdm_ip_array) - 1
        if $standby_mdm_count == 0 {
          $standby_ips = []
          $slave_names = undef
          $tb_names    = undef
        } else {
          $standby_ips = delete($mdm_ip_array, $master_mdm)
          $slave_names = join($standby_ips, ',')
          $tb_names    = join($tb_ip_array, ',')
        }
        $cluster_mode = count($mdm_ip_array) + count($tb_ip_array)
        $password = $scaleio['password']
        $protection_domain = $scaleio['protection_domain']        
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
          $tier12_paths = concat($tier1_devices, $tier2_devices)
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
          $tier1_devices_str = joint($tier1_devices, ',')
          $storage_pools_tier1 = count($tier1_devices) > 0 ? {
            false   => [],
            default => join(values(hash(split(regsubst("${tier1_devices_str},", ',', ",sp_tier1,", 'G'), ','))), ',')
          }  
          $tier2_devices_str = joint($tier2_devices, ',')
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
        if $::scaleio_current_sdc_list {
          $current_sdc_ips = split($::scaleio_current_sdc_list, ',')
          $new_sdc_ips = values(nodes_to_hash($sdc_nodes, 'name', 'internal_address'))
          $to_remove_sdc = difference($current_sdc_ips, intersection($current_sdc_ips, $new_sdc_ips))
          notify {"Resize cluster current sdc-es '${::current_sdc_ips}'": } ->
          notify {"Resize cluster new sdc-es '${new_sdc_ips}'": } ->
          notify {"Resize cluster remove sdc-es '${to_remove_sdc}'": } ->
          cleanup_sdc {$to_remove_sdc:
            require             => Scaleio::Login['Normal'],
            before              => Mdm_standby[$standby_ips],           
          }
        }
        if $::scaleio_current_sds_list {
          $current_sds_names = split($::scaleio_current_sds_list, ',')
          $new_sds_names = keys(nodes_to_hash($sds_nodes, 'name', 'internal_address'))
          $to_remove_sds = difference($current_sds_names, intersection($current_sds_names, $new_sds_names))
          notify {"Resize cluster current sds-es '${::scaleio_current_sds_list}'": } ->
          notify {"Resize cluster new sds-es '${new_sds_names}'": } ->
          notify {"Resize cluster remove sds-es '${to_remove_sds}'": } ->
          cleanup_sds {$to_remove_sds:
            require             => Scaleio::Login['Normal'],
            before              => Mdm_standby[$standby_ips],           
          }
        }
        if $::current_slave_ips or $::current_tb_ips {
          $controllers = split($::controller_ips, ',')
          if $::current_slave_ips {
            $cur_slaves = split($::current_slave_ips, ',')
            $slaves_absent = difference($cur_slaves, intersection($cur_slaves, $controllers))
          } else {
            $slaves_absent = []
          }
          if $::current_tb_ips {
            $cur_tbs = split($::current_tb_ips, ',')
            $tb_absent = difference($cur_tbs, intersection($cur_tbs, $controllers))
          } else {
            $tb_absent = []
          }
          #set cluster mode 1 to reconfigure cluster
          #new mode will be set below after adding new mdm and tb
          notify {"Resize cluster current mdms '${::current_slave_ips}', tbs '${::current_tb_ips}'": } ->
          notify {"Resize cluster new mdms '${::mdm_ips}', tbs '${::tb_ips}', controllers ${::controller_ips}": } ->
          notify {"Resize cluster remove mdms '${slaves_absent}', tbs '${tb_absent}'": }
          if count($slaves_absent) > 0 or count($tb_absent) > 0 {
            $to_remove_mdms = concat($slaves_absent, $tb_absent)
            scaleio::cluster {'Resize cluster mode to 1_node and remove other MDMs':
              ensure              => 'absent',
              cluster_mode        => 1,
              slave_names         => $::current_slave_ips,
              tb_names            => $::current_tb_ips,
              require             => Scaleio::Login['Normal'],
            } ->
            cleanup_mdm {$to_remove_mdms:
              before              => Mdm_standby[$standby_ips],              
            }
          }
        }
        mdm_standby {$standby_ips:
          require             => Scaleio::Login['Normal'],          
        } ->
        mdm_tb{$tb_ip_array:} ->
        scaleio::cluster {'Configure cluster mode':
          ensure              => 'present',
          cluster_mode        => $cluster_mode,
          slave_names         => $slave_names,
          tb_names            => $tb_names,
        } ->
        scaleio::protection_domain {"Ensure protection domain ${protection_domain}": name => $protection_domain } ->
        storage_pool_ensure {$pools: protection_domain => $protection_domain } ->
        sds_device {$sds_nodes:		
            protection_domain => $protection_domain,		
            storage_pools     => $device_storage_pools,		
            device_paths      => $device_paths,		
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
