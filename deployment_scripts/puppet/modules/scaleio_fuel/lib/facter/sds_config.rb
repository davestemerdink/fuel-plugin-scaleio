require 'date'
require 'facter'
require 'yaml'

$scaleio_log_file = "/var/log/fuel-plugin-scaleio.log"
def debug_log(msg)  
  File.open($scaleio_log_file, 'a') {|f| f.write("%s: %s\n" % [Time.now.strftime("%Y-%m-%d %H:%M:%S"), msg]) }
end


$astute_config = '/etc/astute.yaml'
if File.exists?($astute_config)
  Facter.add(:sds_config) do
    setcode do
      result = nil
      config = YAML.load_file($astute_config)
      if config
        mysql_opts = config['mysql']
        galera_host = config['management_vip']
        sql_query = "mysql -h %s -uroot -p%s -e 'USE scaleio; SELECT * FROM sds;' 2>>%s" % [galera_host, mysql_opts['root_password'], $scaleio_log_file]
        query_result = Facter::Util::Resolution.exec(sql_query)
        puts(sql_query)
        puts(query_result)
        debug_log(query_result)
      end
      result
    end
  end
end
