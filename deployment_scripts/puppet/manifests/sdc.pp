# The puppet installs ScaleIO SDC packages and connect to MDMs.

$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if ! $::mdm_ips {
    fail('Empty MDM IPs configuration')    
  }
  class {'scaleio::sdc_server':
    ensure  => 'present',
    mdm_ip  => $::mdm_ips,
  }
}

