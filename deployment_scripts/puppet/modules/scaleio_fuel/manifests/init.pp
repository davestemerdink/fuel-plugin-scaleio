
class scaleio_fuel {

  define environment() { 
    $all_nodes = hiera('nodes')
    $role = $name
    $nodes = $role ? {
      'sds' => filter_nodes($all_nodes, 'name', "${::hostname}"),
      default => filter_nodes($all_nodes, 'role', "scaleio-${role}")
    }
    $hashes         = nodes_to_hash($nodes, 'name', 'storage_address')
    $ips_array      = ipsort(values($hashes))
    $ips            = join($ips_array, ',') 
    file_line { "Append a FACTER_${role}_ips line to /etc/environment":
      ensure  => present,
      path    => '/etc/environment',
      match   => "^FACTER_${role}_ips=",
      line    => "FACTER_${role}_ips=${ips}",
    }  
  }
  
  define mdm_master() {
    $ip = $name
    notify {"Master MDM ${ip}": } ->
    class {'scaleio::mdm_server':
        ensure              => 'present',
        role                => 'manager',
        master_mdm_name     => $ip,
        mdm_ips             => $ip,
        mdm_management_ips  => $ip,
    }
  }
 
  define mdm_standby() {
    $ip = $name
    notify {"Standby MDM ${ip}": } ->
    class {'scaleio::mdm':
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
    notify {"Tie-Breaker MDM ${ip}": } ->
    class {'scaleio::mdm':
        ensure              => 'present',
        ensure_properties   => 'present',
        name                => $ip,
        role                => 'tb',
        ips                 => $ip,
        management_ips      => undef,
    }
  } 

  define login($password) {
    scaleio::login{"Login": password => $password}
  }

  define set_login($password) {
    login {'First login': password => 'admin'} ->
    class {'scaleio::cluster': password=>'admin', new_password=>$password }
  }

  define cluster($cluster_mode, $slave_names, $tb_names) {
    notify {"Configure cluster ${name}": } ->
    class {'scaleio::cluster':
        ensure              => 'present',
        cluster_mode        => $cluster_mode,
        slave_names         => $slave_names,
        tb_names            => $tb_names,
    }
  }  
}
  
