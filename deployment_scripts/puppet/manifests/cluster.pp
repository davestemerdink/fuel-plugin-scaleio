# Protection domains and Storage Pools.
# The puppet configures ScaleIO cluster - adds MDMs, SDSs, sets up

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

define storage_pool_ensure(
  $protection_domain,
  $zero_padding,
  $scanner_mode,
  $checksum_mode,
  $spare_policy,
  $cached_storage_pools_array,
) {
  $sp_name = $title
  if $::scaleio_storage_pools and $::scaleio_storage_pools != '' {
    $current_pools = split($::scaleio_storage_pools, ',')
  } else {
    $current_pools = []
  }
  if ! ("${protection_domain}:${sp_name}" in $current_pools) {
    if $sp_name in $cached_storage_pools_array {
      $rfcache_usage = 'use'
    } else {
      $rfcache_usage = 'dont_use'
    }    
    notify {"storage_pool_ensure ${protection_domain}:${sp_name}: zero_padding=${zero_padding}, checksum=${checksum_mode}, scanner=${scanner_mode}, spare=${spare_policy}, rfcache=${rfcache_usage}":
    } ->
    scaleio::storage_pool {"Storage Pool ${protection_domain}:${sp_name}":
      name                => $sp_name,
      protection_domain   => $protection_domain,
      zero_padding_policy => $zero_padding,
      checksum_mode       => $checksum_mode,
      scanner_mode        => $scanner_mode,
      spare_percentage    => $spare_policy,
      rfcache_usage       => $rfcache_usage,
    }
  } else {
    notify {"Skip storage pool ${sp_name} because it is already exists in ${::scaleio_storage_pools}": }
  } 
}

define sds_ensure(
  $sds_nodes,
  $protection_domain,
  $storage_pools,       # if sds_devices_config==undef then storage_pools and device_paths are used,
  $device_paths,        #   this is FUELs w/o plugin's roles support, so all SDSes have the same config
  $rfcache_devices,
  $sds_devices_config,  # for FUELs with plugin's roles support, config could be different for SDSes
) {
  $sds_name = $title
  $sds_node_ = filter_nodes($sds_nodes, 'name', $sds_name) 
  $sds_node = $sds_node_[0]
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
  if $sds_devices_config {
    $cfg = $sds_devices_config[$sds_name]
    if $cfg {
      notify{"sds ${sds_name} config: ${cfg}": }
      $pool_devices = $cfg  ? { false => undef, default => convert_sds_config($cfg) }
      if $pool_devices {
        $sds_pools = $pool_devices[0]
        $sds_device = $pool_devices[1]
      } else {
        warn("sds ${sds_name} there is empty pools and devices in configuration")      
        $sds_pools = undef
        $sds_device = undef
      }
      if $cfg['rfcache_devices'] and $cfg['rfcache_devices'] != '' {
        $sds_rfcache_devices = $cfg['rfcache_devices']
      } else {
        $sds_rfcache_devices = undef
      }
    } else {
      warn("sds ${sds_name} there is no sds config in DB")
      $sds_pools = undef
      $sds_device = undef
      $sds_rfcache_devices = undef
    }
  } else {
    $sds_pools = $storage_pools
    $sds_device = $device_paths
    $sds_rfcache_devices = $rfcache_devices
  }
  notify { "sds ${sds_name}: pools:devices:rfcache: '${sds_pools}': '${sds_device}': '${sds_rfcache_devices}'": } ->
  scaleio::sds {$sds_name:
    ensure             => 'present',
    name               => $sds_name,
    protection_domain  => $protection_domain,
    ips                => $sds_ips,
    ip_roles           => $sds_ip_roles,
    storage_pools      => $sds_pools,
    device_paths       => $sds_device,
    rfcache_devices    => $sds_rfcache_devices,        
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
      $all_nodes = hiera('nodes')
      # primary controller configures cluster
      if ! empty(filter_nodes(filter_nodes($all_nodes, 'name', $::hostname), 'role', 'primary-controller')) {
        $fuel_version = hiera('fuel_version')
        if $fuel_version <= '8.0' {
          $storage_nodes = filter_nodes($all_nodes, 'role', 'compute')
          if $scaleio['sds_on_controller'] {    
            $controller_nodes  = filter_nodes($all_nodes, 'role', 'controller')   
            $pr_controller_nodes = filter_nodes($all_nodes, 'role', 'primary-controller')
            $sds_nodes = concat(concat($pr_controller_nodes, $controller_nodes), $storage_nodes)
          } else {    
            $sds_nodes = $storage_nodes
          }
        } else {
          $sds_nodes = concat(filter_nodes($all_nodes, 'role', 'scaleio-storage-tier1'), filter_nodes($all_nodes, 'role', 'scaleio-storage-tier2'))
        }
        $sds_nodes_names = keys(nodes_to_hash($sds_nodes, 'name', 'internal_address'))
        $sds_nodes_count = count($sds_nodes_names)
        $sdc_nodes =concat(filter_nodes($all_nodes, 'role', 'compute'), filter_nodes($all_nodes, 'role', 'cinder'))
        $sdc_nodes_ips = values(nodes_to_hash($sdc_nodes, 'name', 'internal_address'))
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
        if $scaleio['protection_domain_nodes'] {
          $protection_domain_number = ($sds_nodes_count + $scaleio['protection_domain_nodes'] - 1) / $scaleio['protection_domain_nodes']          
        } else {
          $protection_domain_number = 1
        }
        $protection_domain =  $protection_domain_number ? {
          0       => $scaleio['protection_domain'],
          1       => $scaleio['protection_domain'],
          default => "${scaleio['protection_domain']}_${protection_domain_number}"
        }
        # parse config from centralized DB if exists
        if $::scaleio_sds_config and $::scaleio_sds_config != '' {
          $sds_devices_config = parsejson($::scaleio_sds_config)
          }
        else {
          $sds_devices_config = undef
        }
        if $scaleio['device_paths'] and $scaleio['device_paths'] != '' {
          # if devices come from settings, remove probable trailing commas
          $paths = join(split($scaleio['device_paths'], ','), ',')
        } else {
          $paths = undef
        }
        if $scaleio['storage_pools'] and $scaleio['storage_pools'] != '' {
          # if storage pools come from settings remove probable trailing commas
          $pools_array = split($scaleio['storage_pools'], ',') 
          $pools = join($pools_array, ',')
        } else {
          $pools_array = get_pools_from_sds_config($sds_devices_config)
          $pools = undef
        }
        $zero_padding = $scaleio['zero_padding'] ? {
          false   => 'disable',
          default => 'enable'
        }
        $scanner_mode = $scaleio['scanner_mode'] ? {
          false   => 'disable',
          default => 'enable'
        }
        $checksum_mode = $scaleio['checksum_mode'] ? {
          false   => 'disable',
          default => 'enable'
        }
        $spare_policy = $scaleio['spare_policy'] ? {
          false   => undef,
          default => $scaleio['spare_policy']
        }
        if $scaleio['rfcache_devices'] and $scaleio['rfcache_devices'] != '' {
          $rfcache_devices = $scaleio['rfcache_devices']
        } else {
          $rfcache_devices = undef
        }
        if $scaleio['cached_storage_pools'] and $scaleio['cached_storage_pools'] != '' {
          $cached_storage_pools_array = split($scaleio['cached_storage_pools'], ',')
        } else {
          $cached_storage_pools_array = []
        }
        if $scaleio['capacity_high_alert_threshold'] and $scaleio['capacity_high_alert_threshold'] != '' {
          $capacity_high_alert_threshold = $scaleio['capacity_high_alert_threshold']
        } else {
          $capacity_high_alert_threshold = undef
        }
        if $scaleio['capacity_critical_alert_threshold'] and $scaleio['capacity_critical_alert_threshold'] != '' {
          $capacity_critical_alert_threshold = $scaleio['capacity_critical_alert_threshold']
        } else {
          $capacity_critical_alert_threshold = undef
        }
        notify {"Configure cluster MDM: ${master_mdm}": } ->
        scaleio::login {'Normal':
          password => $password,
          require  => File_line['SCALEIO_discovery_allowed']
        }
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
          notify {"SDS change current='${::scaleio_sds_names}' new='${new_sds_names}' to_remove='${to_remove_sds}'": } ->
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
            require             => Scaleio::Login['Normal'],          
          }
        }
        $protection_domain_resource_name = "Ensure protection domain ${protection_domain}"
        scaleio::protection_domain {$protection_domain_resource_name:
          name                => $protection_domain,
          require             => Scaleio::Login['Normal'],          
        } ->
        storage_pool_ensure {$pools_array:
          protection_domain           => $protection_domain,
          zero_padding                => $zero_padding,
          scanner_mode                => $scanner_mode,
          checksum_mode               => $checksum_mode,
          spare_policy                => $spare_policy,
          cached_storage_pools_array  => $cached_storage_pools_array,
        } ->
        sds_ensure {$to_add_sds_names:
          sds_nodes           => $sds_nodes,		
          protection_domain   => $protection_domain,		
          storage_pools       => $pools,		
          device_paths        => $paths,
          rfcache_devices     => $rfcache_devices,
          sds_devices_config  => $sds_devices_config,
          require             => Scaleio::Protection_domain[$protection_domain_resource_name],
        }
        if $capacity_high_alert_threshold and $capacity_critical_alert_threshold {
          scaleio::cluster {'Configure alerts':
            ensure                            => 'present',
            capacity_high_alert_threshold     => $capacity_high_alert_threshold,
            capacity_critical_alert_threshold => $capacity_critical_alert_threshold,
            require                           => Scaleio::Protection_domain[$protection_domain_resource_name],
          }
        }
        # Apply high performance profile to SDC-es
        # Use first sdc ip because underlined puppet uses all_sdc parameters
        if ! empty($sdc_nodes_ips) {
          scaleio::sdc {'Set performance settings for all available SDCs':
            ip      => $sdc_nodes_ips[0],
            require => Scaleio::Protection_domain[$protection_domain_resource_name],          
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
      } ->
      # forbid requesting sdc/sds from discovery facters,
      # this is a workaround of the ScaleIO problem - 
      # these requests hangs in some reason if cluster is in degraded state
      file_line {'SCALEIO_discovery_allowed':
        ensure  => present,
        path    => '/etc/environment',
        match   => "^SCALEIO_discovery_allowed=",
        line    => "SCALEIO_discovery_allowed=no",
      }

    } else {
      fail('Empty MDM IPs configuration')
    }
  } else {
    notify{'Skip configuring cluster because of using existing cluster': }
  }
}
