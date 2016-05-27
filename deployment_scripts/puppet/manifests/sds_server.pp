# The puppet installs ScaleIO SDS packages

# helping define for array processing
define sds_device_cleanup() {
  $device = $title
  exec { "device ${device} cleaup":
    command => "bash -c 'for i in \$(parted ${device} print | awk \"/^ [0-9]+/ {print(\\\$1)}\"); do parted ${device} rm \$i; done'",
    path => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
  }
}

# Just install packages
$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  if ! $scaleio['existing_cluster'] {      
    $fuel_version = hiera('fuel_version')
    $use_plugin_roles = $fuel_version > '8.0'
    if ! $use_plugin_roles {
      #it is supposed that task is run on compute or controller
      $node_ips = split($::ip_address_array, ',')
      $is_sds_server = empty(intersection(split($::controller_ips, ','), $node_ips)) or $scaleio['sds_on_controller']
    } else {
      $all_nodes = hiera('nodes')
      $nodes = filter_nodes($all_nodes, 'name', $::hostname)
      $is_sds_server = ! empty(concat(
        concat(filter_nodes($nodes, 'role', 'scaleio-storage-tier1'), filter_nodes($nodes, 'role', 'scaleio-storage-tier2')),
        filter_nodes($nodes, 'role', 'scaleio-storage-tier3')))
    }
    if $is_sds_server {
      class {'scaleio::sds_server':
        ensure  => 'present',
      }
      if $scaleio['rfcache_devices'] and $scaleio['rfcache_devices'] != '' {
        class {'scaleio::xcache_server':
          ensure  => 'present',
          require => Class['Scaleio::Sds_server'],
        }
      }
      if ! $use_plugin_roles {
        if $scaleio['device_paths'] and $scaleio['device_paths'] != '' {
          $devices = split($scaleio['device_paths'], ',')
          sds_device_cleanup {$devices:
            before => Class['scaleio::sds_server']
          }
        }
      } else {
        # save devices in shared DB
        $tier1_devices = $::sds_storage_devices_tier1 ? {
          undef   => '',
          default => join(split($::sds_storage_devices_tier1, ','), ',')
        }
        $tier2_devices = $::sds_storage_devices_tier2 ? {
          undef   => '',
          default => join(split($::sds_storage_devices_tier2, ','), ',')
        }
        $tier3_devices = $::sds_storage_devices_tier3 ? {
          undef   => '',
          default => join(split($::sds_storage_devices_tier3, ','), ',')
        }
        $rfcache_devices = $::sds_storage_devices_rfcache ? {
          undef   => '',
          default => join(split($::sds_storage_devices_rfcache, ','), ',')
        }
        $sds_config = {
          "${::hostname}" => {
            'devices' => {
              'tier1' => $tier1_devices,
              'tier2' => $tier2_devices,
              'tier3' => $tier3_devices,
            },
            'rfcache_devices' => $rfcache_devices,
          }
        }
        $sds_config_str = regsubst(inline_template('<%= @sds_config.to_s %>'), '=>', ":", 'G')
        $mysql_opts = hiera('mysql')
        $galera_host = hiera('management_vip')
        $sql_connect = "mysql -h ${galera_host} -uroot -p${mysql_opts['root_password']}"  
        $db_query = 'CREATE DATABASE IF NOT EXISTS scaleio; USE scaleio'
        $table_query = 'CREATE TABLE IF NOT EXISTS sds (name VARCHAR(64), PRIMARY KEY(name), value TEXT(1024))'
        $update_query = "INSERT INTO sds (name, value) VALUES ('${::hostname}', '${sds_config_str}') ON DUPLICATE KEY UPDATE value='${sds_config_str}'"
        $sql_query = "${sql_connect} -e \"${db_query}; ${table_query}; ${update_query};\""
        package {'mysql-client':
          ensure => present,
          require => Class['Scaleio::Sds_server'],
        } ->
        exec {'sds_devices_config':
          command => $sql_query,
          path    => '/bin:/usr/bin:/usr/local/bin',
        }
      }
    }
  } else {
    notify{'Skip sds server because of using existing cluster': }
  }
}
