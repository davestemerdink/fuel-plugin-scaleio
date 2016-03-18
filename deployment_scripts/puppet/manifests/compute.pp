# Connect to cluster
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if $::mdm_ips {
    scaleio_fuel::login {'login':
      password => $scaleio['password'],
    } ->
    class {'scaleio::sdc_server':
      ensure  => 'present',
      mdm_ips => $::mdm_ips,
    } ->
    class {'scaleio_openstack::nova':
      ensure  => present,
    }
  } else {
    fail('Empty MDM IPs configuration')
  }
}
