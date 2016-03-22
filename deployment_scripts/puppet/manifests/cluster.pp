#Helpers for array processing
define mdm_standby() {
  $ip = $name
  notify {"Configure Standby MDM ${ip}": } ->
  scaleio::mdm {"Standby MDM ${name}":
      ensure              => 'present',
      ensure_properties   => 'present',
      name                => $ip,
      role                => 'manager',
      ips                 => $ip,
      management_ips      => $ip,
  }
}

define mdm_tb() {
  $ip = $name
  notify {"Configure Tie-Breaker MDM ${ip}": } ->
  scaleio::mdm {"Tie-Breaker MDM ${name}":
      ensure              => 'present',
      ensure_properties   => 'present',
      name                => $ip,
      role                => 'tb',
      ips                 => $ip,
      management_ips      => undef,
  }
}

# The only first mdm which is proposed to be the first master does cluster configuration
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if $::mdm_ips {
    $mdm_ip_array = split($::mdm_ips, ',')
    $tb_ip_array = split($::tb_ips, ',')
    $master_ip = $mdm_ip_array[0]
    if has_ip_address($master_ip) {
      $stand_by_mds_count = count($mdm_ip_array) - 1
      $standby_ips = values_at($mdm_ip_array, ["1-${stand_by_mds_count}"])
      $cluster_mode = count($mdm_ip_array) + count(split($tb_ip_array, ','))
      $slave_names = join($standby_ips, ',')
      $tb_names = join($tb_ip_array, ',')
      $password = $scaleio['password']
      notify {"Master MDM ${master_ip}": } ->
      class {'scaleio::mdm_server':
        ensure              => 'present',
        role                => 'manager',
        master_mdm_name     => $master_ip,
        mdm_ips             => $master_ip,
        mdm_management_ips  => $master_ip,
      } ->
      scaleio::login {'First login': password => 'admin'} ->
      scaleio::cluster {'Set password': password=>'admin', new_password=>$password }->
      mdm_standby {$standby_ips: } ->
      mdm_tb{$tb_ip_array:} ->
      scaleio::cluster {'Configure cluster mode':
        ensure              => 'present',
        cluster_mode        => $cluster_mode,
        slave_names         => $slave_names,
        tb_names            => $tb_names,
      }
    } else {
      notify {"Not Master MDM ${master_ip}": }
    }
  } else {
    fail('Empty MDM IPs configuration')
  }
}
