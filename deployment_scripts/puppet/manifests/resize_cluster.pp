# The puppet sets 1_node mode and removes absent nodes if there are any ones.
# It expects that facters mdm_ips and tb_ips are correctly set to current cluster state


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
    $controllers_ips = values(nodes_to_hash($controllers_nodes, 'name', 'internal_address'))
    # names of mdm and tb are IPs in fuel
    $current_mdms = split($::mdm_ips, ',')
    $current_tbs = split($::tb_ips, ',')
    $mdms_present = intersection($current_mdms, $controllers_ips)
    $mdms_absent = difference($current_mdms, $mdms_present)
    $tbs_present = intersection($current_tbs, $controllers_ips)
    $tbs_absent = difference($current_tbs, $tbs_present)
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
    $nodes_present = concat(intersection($current_mdms, $controllers_ips), $tbs_present)
    $available_nodes = difference($controllers_ips, intersection($nodes_present, $controllers_ips))
    if $to_add_tb_count > 0 and count($available_nodes) >= $to_add_tb_count {
      $last_tb_index = count($available_nodes) - 1
      $first_tb_index = $last_tb_index - $to_add_tb_count + 1
      $tbs_present_tmp = intersection($current_tbs, $controllers_ips) # use tmp because concat modifys first param
      $new_tb_ips = join(concat($tbs_present_tmp, values_at($available_nodes, "${first_tb_index}-${last_tb_index}")), ',')
    } else {
      $new_tb_ips = join($tbs_present, ',')
    }                  
    if $to_add_mdm_count > 0 and count($available_nodes) >= $to_add_mdm_count {
      $last_mdm_index = $to_add_mdm_count - 1
      $mdms_present_tmp = intersection($current_mdms, $controllers_ips) # use tmp because concat modifys first param
      $new_mdms_ips = join(concat($mdms_present_tmp, values_at($available_nodes, "0-${last_mdm_index}")), ',')
    } else {
      $new_mdms_ips = join($mdms_present, ',')
    }                  
    notify {"Cluster: controllers_ips='${controllers_ips}', current_mdms='${current_mdms}', current_tbs='${current_tbs}'": }
    if count($mdms_present) {
      notify {"Cluster MDM change: mdms_present='${mdms_present}', mdms_absent='${mdms_absent}'": } ->
      notify {"Cluster TB change: tbs_present='${tbs_present}', tbs_absent='${tbs_absent}'": }
      # primary-controller will do cleanup
      if ! empty(filter_nodes(filter_nodes($all_nodes, 'name', $::hostname), 'role', 'primary-controller')) {
        $password = $scaleio['password']
        notify {"Resize cluster: controllers_ips='${controllers_ips}', current_mdms='${current_mdms}', current_tbs='${current_tbs}'": }
        if count($mdms_absent) > 0 or count($tbs_absent) > 0 {
          $slaves_names = join(delete($current_mdms, $current_mdms[0]), ',') # first is current master
          $to_remove_mdms = concat(split(join($mdms_absent, ','), ','), $tbs_absent)  # join/split because concat affects first argument
          scaleio::login {'Normal':
            password => $password
          } ->
          scaleio::cluster {'Resize cluster mode to 1_node and remove other MDMs':
            ensure              => 'absent',
            cluster_mode        => 1,
            slave_names         => $slaves_names,
            tb_names            => $::scaleio_tb_ips,
            require             => Scaleio::Login['Normal'],
            before              => File_line['SCALEIO_mdm_ips']
          } ->
          cleanup_mdm {$to_remove_mdms:
            before              => File_line['SCALEIO_mdm_ips']
          }
        }
      } else {
        notify {"Not first MDM IP ${mdms_present[0]}": }
      }
    } else {
      notify {'Cluster is not discovered': }
    }
    file_line {'SCALEIO_mdm_ips':
      ensure  => present,
      path    => '/etc/environment',
      match   => "^SCALEIO_mdm_ips=",
      line    => "SCALEIO_mdm_ips=${new_mdms_ips}",
    } ->
    file_line {'SCALEIO_tb_ips':
      ensure  => present,
      path    => '/etc/environment',
      match   => "^SCALEIO_tb_ips=",
      line    => "SCALEIO_tb_ips=${new_tb_ips}",
    } ->
    file_line {'SCALEIO_discovery_allowed':
      ensure  => present,
      path    => '/etc/environment',
      match   => "^SCALEIO_discovery_allowed=",
      line    => "SCALEIO_discovery_allowed=yes",
    }
  } else {
    notify{'Skip configuring cluster because of using existing cluster': }
  }
}
