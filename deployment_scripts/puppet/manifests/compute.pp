$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if $::mdm_ips {
    class {'scaleio::sdc_server':
      ensure  => 'present',
      mdm_ip  => $::mdm_ips,
    } ->
    class {'scaleio_openstack::nova':
      ensure  => present,
    }
  } else {
    fail('Empty MDM IPs configuration')
  }
}
