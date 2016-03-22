$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if $::mdm_ips {
    scaleio::login {'login':
      password => $scaleio['password'],
      before   => Class['scaleio::sds']
    } ->
    class {'scaleio::sdc_server':
      ensure  => 'present',
      mdm_ips => $::mdm_ips,
    } ->
    class {'scaleio_openstack::nova':
      ensure  => present,
    }
    if $::sds_ips {
      #use first ip as SDS name
      $sds_name = $::sds_ips[0]
      # remove possible trailing comas
      $ips = join(split($::sds_ips, ','), ',')
      # generate array of roles (all) with lenght of ips
      $roles = join(values(hash(split(regsubst("${ips},", ',', ',all,', 'G'), ','))), ',')
      $paths = $scaleio['device_paths'] ? {
        udnef   => undef,
        default => join(split($scaleio['device_paths'], ','), ',')
      }
      if $paths and count($paths) > 0 {
        #generate array of pools with lenght of device_paths
        $device_paths = $paths
        $storage_pools = join(values(hash(split(regsubst("${device_paths},", ',', ",${scaleio['storage_pool']},", 'G'), ','))), ',')
      } else {
        $device_paths = undef
        $storage_pools = undef
      }
      notify {"Devices ${device_paths}": } ->
      notify {"Storage pools ${storage_pools}": } ->
      notify {"IPs and roles ${ips} /  ${roles}": } ->
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
        device_paths       => $device_paths,    # "/dev/sdb,/dev/sdc",
      }
    } else {
      fail('Wrong SDS IPs configuration')
    }
  } else {
    fail('Empty MDM IPs configuration')
  }
}
