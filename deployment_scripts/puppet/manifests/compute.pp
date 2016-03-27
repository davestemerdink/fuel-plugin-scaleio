$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if $::mdm_ips {
    $gw_ips = split($::gateway_ips, ',')
    $gateway_ip = $gw_ips[0] #TODO: replace with management_vip after HA be implemented

    class {'scaleio::sdc_server':
      ensure  => 'present',
      mdm_ip  => $::mdm_ips,
    } ->
    class {'scaleio_openstack::nova':
      ensure              => present,
#      gateway_user        => admin, #default
      gateway_password    => $scaleio['gateway_password'],
      gateway_ip          => $gateway_ip,
#      gateway_port        => 4443, #default
      protection_domains  => $scaleio['protection_domain'],
      storage_pools       => $scaleio['storage_pools'],
   }
  } else {
    fail('Empty MDM IPs configuration')
  }
}
