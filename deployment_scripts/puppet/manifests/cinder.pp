# Configure Cinder to use ScaleIO
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if $::gateway_ips {
    class {'scaleio_openstack::cinder':
      ensure                     => present,
      gateway_user               => 'admin',
      gateway_password           => $scaleio['gateway_password'],
      gateway_ip                 => $::gateway_ips,
      protection_domains         => $scaleio['protection_domain'],
      storage_pools              => $scaleio['storage_pool'],
    } ->
    class {'scaleio_openstack::volume_type':
      ensure              => present,
      protection_domains  => [$scaleio['protection_domain']],
      storage_pools       => [$scaleio['storage_pool']],
      provisioning        => ['thin'],
      os_password         => $::os_password,
      os_tenant_name      => $::os_tenant_name,
      os_username         => $::os_username,
      os_auth_url         => $::os_auth_url,
    }
  } else {
    fail('Empty Gateway IPs configuration')
  }
}
