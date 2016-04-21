# The puppet:
# - sets 1_node mode and removes absent nodes if there are any ones.
# - updates mdm_ips and tb_ips values for next cluster task.

define cleanup_mdm () {
  $mdm_name = $title
  scaleio::mdm {"Remove MDM ${mdm_name}":
    ensure             => 'absent',
    name               => $mdm_name,
  }
}

# The only mdm with minimal IP from current MDMs does cleaunp
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if ! $scaleio['existing_cluster'] {
    $all_nodes = hiera('nodes')
    $controllers_nodes = concat(filter_nodes($all_nodes, 'role', 'primary-controller'), filter_nodes($all_nodes, 'role', 'controller'))
    #use management network for ScaleIO components communications
    $controllers_ips = ipsort(values(nodes_to_hash($controllers_nodes, 'name', 'internal_address')))
    # names of mdm and tb are IPs in fuel
    $current_mdms = concat(split($::scaleio_mdm_ips, ','), split($::scaleio_standby_mdm_ips, ','))
    $current_tbs = concat(split($::scaleio_tb_ips, ','), split($::scaleio_standby_tb_ips, ','))
    $mdms_present = intersection($controllers_ips, $current_mdms)
    $mdms_absent = difference($controllers_ips, $current_mdms)
    $tbs_present = intersection($controllers_ips, $current_tbs)
    $tbs_absent = difference($controllers_ips, $current_tbs)
    $controllers_count = count($controllers_ips)
    if $controllers_count < 3 {
      # 1 node mode
      $to_add_mdm_count = 1 - count($mdms_present)
      $to_add_tb_count = 0
    } else {
      # 3 node mode
      if $controllers_count < 5 {
        $to_add_mdm_count = 2 - count($mdms_present)
        $to_add_tb_count = 1 - count($tbs_present)
      } else {
        # 5 node mode
        $to_add_mdm_count = 3 - count($mdms_present)
        $to_add_tb_count = 2 - count($tbs_present)
      }
    }
    $nodes_present = concat(intersection($controllers_ips, $current_mdms), $tbs_present)
    $available_nodes = difference($controllers_ips, intersection($controllers_ips, $nodes_present))
    if $to_add_tb_count > 0 and count($available_nodes) >= $to_add_tb_count {
      $last_tb_index = count($available_nodes) - 1
      $first_tb_index = $last_tb_index - $to_add_tb_count + 1
      $tbs_present_tmp = intersection($controllers_ips, $current_tbs) # use tmp because concat modifys first param
      $tb_ips = join(concat($tbs_present_tmp, values_at($available_nodes, "${first_tb_index}-${last_tb_index}")), ',')
    } else {
      $tb_ips = join($tbs_present, ',')
    }                  
    if $to_add_mdm_count > 0 and count($available_nodes) >= $to_add_mdm_count {
      $last_mdm_index = $to_add_mdm_count - 1
      $mdms_present_tmp = intersection($controllers_ips, $current_mdms) # use tmp because concat modifys first param
      $mdms_ips = join(concat($mdms_present_tmp, values_at($available_nodes, "0-${last_mdm_index}")), ',')
    } else {
      $mdms_ips = join($mdms_present, ',')
    }                  
    notify {"Cluster: controllers_ips='${controllers_ips}', current_mdms='${current_mdms}', current_tbs='${current_tbs}'": }
    if count($mdms_present) {
      notify {"Cluster MDM change: mdms_present='${mdms_present}', mdms_absent='${mdms_absent}'": } ->
      notify {"Cluster TB change: tbs_present='${tbs_present}', tbs_absent='${tbs_absent}'": }
      # the only mdm with minimal ip will do cleanup
      if has_ip_address($mdms_present[0]) {
        $password = $scaleio['password']
        notify {"Resize cluster: controllers_ips='${controllers_ips}', current_mdms='${current_mdms}', current_tbs='${current_tbs}'": } ->
        scaleio::login {'Normal':
          password => $password
        }
        if count($mdms_absent) > 0 or count($tbs_absent) > 0 {
          $slaves_names = join(delete($current_mdms, $current_mdms[0]), ',') # first is current master
          $to_remove_mdms = concat($mdms_absent, $tbs_absent) # !!! do not use $mdms_absent after this line
          scaleio::cluster {'Resize cluster mode to 1_node and remove other MDMs':
            ensure              => 'absent',
            cluster_mode        => 1,
            slave_names         => $slaves_names,
            tb_names            => $::scaleio_tb_names,
            require             => Scaleio::Login['Normal'],
          } ->
          cleanup_mdm {$to_remove_mdms:
            before              => File_line['FACTER_mdm_ips']
          }
        }
      } else {
        notify {"Not first MDM IP ${mdms_present[0]}": }
      }
    } else {
      notify {'Cluster is not discovered': }
    }
    file_line {'FACTER_mdm_ips':
      ensure  => present,
      path    => '/etc/environment',
      match   => "^FACTER_mdm_ips=",
      line    => "FACTER_mdm_ips=${mdms_ips}",
    } ->
    file_line {'FACTER_tb_ips':
      ensure  => present,
      path    => '/etc/environment',
      match   => "^FACTER_tb_ips=",
      line    => "FACTER_tb_ips=${tb_ips}",
    }    
  } else {
    notify{'Skip configuring cluster because of using existing cluster': }
  }
}
