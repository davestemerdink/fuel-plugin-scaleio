# Configure SDS and Devices
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if $::mdm_ips {
    if $::sds_ips {
      #use first ip as name
      $sds_name = $::sds_ips[0]
      # remove possible trailing comas
      $ips = join(split($::sds_ips, ','), ',')
      # generate array os roles (all) with lenght of ips
      $roles = join(values(hash(split(regsubst("${ips},", ',', ',all,', 'G'), ','))), ',')
      if $scaleio['use_unallocated_disks'] or $scaleio['use_unallocated_disks'] {
        $paths = concat(
          $scaleio['use_unallocated_disks'] ? { true=>$::unallocated_disks, default=>[]},
          $scaleio['use_unallocated_space'] ? { true=>$::unallocated_space, default=>[]}  
        )
      } else{
        if $scaleio['device_paths'] {
          $paths =  split($scaleio['device_paths'], ',')
        } else {
          $paths =  undef
        }
      }
      if $paths and count($paths) > 0 {
        $device_paths = join($paths, ',')
        #generate array of pools with lenght of device_paths
        $storage_pools = join(values(hash(split(regsubst("${device_paths},", ',', ",${scaleio['storage_pool']},", 'G'), ','))), ',')
      } else {
        $device_paths = undef
        $storage_pools = undef
      }
      scaleio_fuel::login {'login':
        password => $scaleio['password'],
      } ->
      class {'scaleio::sds':
        ensure             => 'present',
        ensure_properties  => undef,
        name               => $sds_name,
        protection_domain  => $scaleio['protection_domain'],
        fault_set          => undef,
        port               => undef,
        ips                => $ips,             # "1.2.3.4,1.2.3.5"
        ip_roles           => $roles,           # "all,all"
        storage_pools      => $storage_pools,   # "sp1,sp2"
        device_paths       => $device_paths,    # "/dev/sdb,/dev/sdc"
      }
    } else {
      fail('Wrong SDS IPs configuration')
    }  
  } else {
    fail('Empty MDM IPs configuration')
  }  
}
