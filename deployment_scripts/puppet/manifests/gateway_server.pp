# Set password and connect to MDMs
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if ! $scaleio['existing_cluster'] {
    if $::mdm_ips {
      class {'scaleio::gateway_server':
        ensure   => 'present',
        mdm_ips  => $::mdm_ips,
        password => $scaleio['gateway_password'],
      }
    } else {
      fail('Empty MDM IPs configuration')
    }  
  } else {
    notify{'Skip deploying gateway server because of using existing cluster': }
  }
  
}
