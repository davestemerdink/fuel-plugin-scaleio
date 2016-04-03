# The puppet configure ScaleIO MDM IPs in environment for existing ScaleIO cluster.

#TODO: move it from this file and from environment.pp into modules
define env_fact($role, $fact, $value) {
  file_line { "Append a FACTER_${role}_${fact} line to /etc/environment":
    ensure  => present,
    path    => '/etc/environment',
    match   => "^FACTER_${role}_${fact}=",
    line    => "FACTER_${role}_${fact}=${value}",
  }  
}

$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if $scaleio['existing_cluster'] {
    $ips = $::existing_cluster_mdm_ips
    if ! $ips or $ips == '' {
      fail('Cannot request MDM IPs from existing cluster. Check Gateway address/port and user name with password.')
    }
    env_fact{"Environment fact: role mdm, ips from existing cluster ${ips}":
      role => 'mdm',
      fact => 'ips',
      value => $ips
    }
  }
} else {
    notify{'ScaleIO plugin disabled': }
}
