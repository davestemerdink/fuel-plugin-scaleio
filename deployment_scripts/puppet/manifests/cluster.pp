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

define ensure_password($old_password, $password) {
  if $old_password != $password {
    scaleio::login {'First': password => $old_password} ->
    scaleio::cluster {'Set password':
      password      => $old_password,
      new_password  => $password,
    } ->
    file_line { "Append a FACTER_mdm_password line to /etc/environment":
      ensure  => present,
      path    => '/etc/environment',
      match   => "^FACTER_mdm_password=",
      line    => "FACTER_mdm_password=${password}",
      before  => Scaleio::Login['Normal'],
    }
  }
  scaleio::login {'Normal': password => $password }
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

# The only first mdm which is proposed to be the first master does cluster configuration
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if ! $scaleio['existing_cluster'] {
    if $::mdm_ips {
      $mdm_ip_array = split($::mdm_ips, ',')
      $tb_ip_array = split($::tb_ips, ',')
      $master_ip = $mdm_ip_array[0]
      if has_ip_address($master_ip) {
        $standby_mdm_count = count($mdm_ip_array) - 1
        if $standby_mdm_count == 0 {
          $standby_ips = []
          $slave_names = undef
          $tb_names    = undef
        } else {
          $standby_ips = values_at($mdm_ip_array, ["1-${standby_mdm_count}"])
          $slave_names = join($standby_ips, ',')
          $tb_names    = join($tb_ip_array, ',')
        }
        $cluster_mode = count($mdm_ip_array) + count($tb_ip_array)
        $env_password = $::mdm_password
        $old_password = $env_password ? {
          undef   => 'admin',
          default => $env_password
        }
        $password = $scaleio['password']
        $protection_domain = $scaleio['protection_domain']
        $pools = $scaleio['storage_pools'] ? {
          undef   => undef,
          default => split($scaleio['storage_pools'], ',')
        }
        $all_nodes = hiera('nodes')
        $compute_nodes  = filter_nodes($all_nodes, 'role', 'compute')		
        if $scaleio['sds_on_controller'] {		
          $controller_nodes  = filter_nodes($all_nodes, 'role', 'controller')		
          $pr_controller_nodes = filter_nodes($all_nodes, 'role', 'primary-controller')		
          $sds_nodes = concat(concat($pr_controller_nodes, $controller_nodes), $compute_nodes)		
        } else {		
          $sds_nodes = $compute_nodes		
        }
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
  
        notify {"Master MDM ${master_ip}": } ->
        class {'scaleio::mdm_server':
          ensure              => 'present',
          is_manager          => undef,
          master_mdm_name     => $master_ip,
          mdm_ips             => $master_ip,
          mdm_management_ips  => $master_ip,
        } ->
        ensure_password {'Set password': old_password => $old_password, password => $password} ->
        mdm_standby {$standby_ips: } ->
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
        notify {"Not Master MDM ${master_ip}": }
      }
    } else {
      fail('Empty MDM IPs configuration')
    }
  } else {
    notify{'Skip configuring cluster because of using existing cluster': }
  }
}
