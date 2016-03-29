$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if $scaleio['existing_cluster'] {
    notify{'Use existing ScaleIO cluster': }
    env_fact{"Environment fact: role mdm, ips from existing cluster":
      role => 'mdm',
      fact => 'ips',
      value => $::existing_cluster_mdm_ips
    }
    if ! $::existing_cluster_mdm_ips or $::existing_cluster_mdm_ips == '' {
      fail('Cannot request MDM IPs from existing cluster. Check Gateway address/port and  user name with password.')
    }
  }
} else {
    notify{'ScaleIO plugin disabled': }
}
