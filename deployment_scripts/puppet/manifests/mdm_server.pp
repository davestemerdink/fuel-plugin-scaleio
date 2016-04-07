# The puppet installs ScaleIO MDM packages.

$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if ! $scaleio['existing_cluster'] {
    $node_ips = split($::ip_address_array, ',')
    $is_tb = ! empty(intersection(split($::tb_ips, ','), $node_ips))
    $is_mdm = ! empty(intersection(split($::mdm_ips, ','), $node_ips))
    if $is_tb or $is_mdm {
      if $is_tb {
        $is_manager = 0
        $master_mdm_name = undef
        $master_ip = undef
      } else {
        $is_manager = 1
        $master_ip_ = $::master_mdm_ip
        if $master_ip_ and has_ip_address($master_ip_) {
          $master_mdm_name = $master_ip_
          $master_ip = $master_ip_
        } else {
          $master_mdm_name = undef
          $master_ip = undef
        }
        $env_password = $::mdm_password
        $old_password = $env_password ? {
          undef   => 'admin',
          default => $env_password
        }
        $password = $scaleio['password']
      }
      notify {"Controller server is_manager=${is_manager} master_mdm_name=${master_mdm_name} master_ip=${master_ip}": } ->
      class {'scaleio::mdm_server':
        ensure                   => 'present',
        is_manager               => $is_manager,
        master_mdm_name          => $master_mdm_name,
        mdm_ips                  => $master_ip,
      }
      if $master_mdm_name and $old_password != $password {
        scaleio::login {'First':
          password => $old_password,
          require  => Class['scaleio::mdm_server']
        } ->
        scaleio::cluster {'Set password':
          password      => $old_password,
          new_password  => $password,
        } ->
        file_line { "Append a FACTER_mdm_password line to /etc/environment":
          ensure  => present,
          path    => '/etc/environment',
          match   => "^FACTER_mdm_password=",
          line    => "FACTER_mdm_password=${password}",
        }
      }
    } else {
      notify{'Skip deploying mdm server because it is not mdm and tb': }
    }
  } else {
    notify{'Skip deploying mdm server because of using existing cluster': }
  }
}

