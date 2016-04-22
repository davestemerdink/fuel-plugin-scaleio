# The puppet discovers cluster and updates mdm_ips and tb_ips values for next cluster task.

$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if ! $scaleio['existing_cluster'] {
    # names of mdm and tb are IPs in fuel
    $current_mdms = concat(split($::scaleio_mdm_ips, ','), split($::scaleio_standby_mdm_ips, ','))
    $current_tbs = concat(split($::scaleio_tb_ips, ','), split($::scaleio_standby_tb_ips, ','))
    $discovered_mdms_ips = join($current_mdms, ',')
    $discovered_tbs_ips = join($current_tbs, ',')
    if count($current_mdms) > 0 or count($current_tbs) > 0 {
      notify {"Cluster: current_mdms='${discovered_mdms_ips}', current_tbs='${discovered_tbs_ips}'": }
    } else {
      notify {'Cluster is not discovered': }
    }
    file_line {'FACTER_mdm_ips':
      ensure  => present,
      path    => '/etc/environment',
      match   => "^FACTER_mdm_ips=",
      line    => "FACTER_mdm_ips=${discovered_mdms_ips}",
    } ->
    file_line {'FACTER_tb_ips':
      ensure  => present,
      path    => '/etc/environment',
      match   => "^FACTER_tb_ips=",
      line    => "FACTER_tb_ips=${discovered_tbs_ips}",
    }    
  } else {
    notify{'Skip configuring cluster because of using existing cluster': }
  }
}
