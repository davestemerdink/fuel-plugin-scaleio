# The only first mdm which is proposed to be the first master does cluster configuration
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if $::mdm_ips {
    $master_ip = $::mdm_ips[0]
    if has_ip_address($master_ip) {
      $stand_by_mds_count = count($::mdm_ips) - 1
      $standby_ips = values_at($::mdm_ips, ["1-${stand_by_mds_count}"])
      $cluster_mode = count(::mdm_ips) + count($::tb_ips)
      scaleio_fuel::mdm_master {$master_ip: } ->
      scaleio_fuel::set_login {'set login:': password => $scaleio['password']}
      scaleio_fuel::mdm_standby {$standby_ips: } ->
      scaleio_fuel::mdm_tb{$::tb_ips:} ->
      scaleio_fuel::cluster{$master_ip: cluster_mode => $cluster_mode, slave_names => $standby_ips, tb_names => $::tb_ips}
    }
  } else {
    fail('Empty MDM IPs configuration')
  }
}
