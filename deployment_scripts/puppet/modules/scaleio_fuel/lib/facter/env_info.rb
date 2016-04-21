# This is a workaround because FUEL daemons don't inherit environment variables
require 'date'
require 'facter'
require 'json'

def debug_log(msg)  
  File.open("/tmp/scaleio_dbg.log", 'a') {|f| f.write("%s: %s\n" % [Time.now.strftime("%Y-%m-%d %H:%M:%S"), msg]) }
end

base_cmd = "bash -c 'source /etc/environment; echo $FACTER_%s'"
facters = ['controller_ips', 'tb_ips', 'mdm_ips', 'gateway_user', 'gateway_port', 'gateway_ips', 'gateway_password', 'mdm_password', 'storage_pools']
facters.each { |f|
  if ! Facter.value(f)
    Facter.add(f) do
      setcode base_cmd % f 
    end
  end
}

#skip fact for existing cluster if no gateway password that means deploying new cluster
gw_passw = Facter.value('gateway_password')
if gw_passw && gw_passw != ''
  Facter.add('existing_cluster_mdm_ips') do
    setcode do
      user        = Facter.value('gateway_user')
      password    = gw_passw
      host        = Facter.value('gateway_ips').split(',')[0]
      port        = Facter.value('gateway_port')
      base_url    = "https://%s:%s/api/%s"
      login_url   = base_url % [host, port, 'login']
      config_url  = base_url % [host, port, 'Configuration']
      login_req   = "curl -k --basic --connect-timeout 5 --user #{user}:#{password} #{login_url} 2>>/tmp/scaleio_dbg.log | sed 's/\"//g'"
      debug_log(login_req)
      token       = Facter::Util::Resolution.exec(login_req)
      if token && token != ''
        req_url     = "curl -k --basic --connect-timeout 10 --user #{user}:#{token} #{config_url} 2>>/tmp/scaleio_dbg.log"
        debug_log(req_url)
        config_str  = Facter::Util::Resolution.exec(req_url)
        config      = JSON.parse(config_str)
        mdm_ips     = config['mdmAddresses'].join(',')
      else
        mdm_ips = nil
      end
      debug_log("%s='%s'" % ['existing_cluster_mdm_ips', mdm_ips])
      mdm_ips
    end
  end
end

        
# Facter to scan existign cluster
# MDM IPs to scan
mdm_ips = Facter.value(:mdm_ips)
if mdm_ips and mdm_ips != ''
  # Register all facts for MDMs
  # Example of output that facters below parse:
  #   Cluster:
  #       Mode: 3_node, State: Normal, Active: 3/3, Replicas: 2/2
  #   Master MDM:
  #       Name: 192.168.0.4, ID: 0x0ecb483853835e00
  #           IPs: 192.168.0.4, Management IPs: 192.168.0.4, Port: 9011
  #           Version: 2.0.5014
  #   Slave MDMs:
  #       Name: 192.168.0.5, ID: 0x3175fbe7695bbac1
  #           IPs: 192.168.0.5, Management IPs: 192.168.0.5, Port: 9011
  #           Status: Normal, Version: 2.0.5014
  #   Tie-Breakers:
  #       Name: 192.168.0.6, ID: 0x74ccbc567622b992
  #           IPs: 192.168.0.6, Port: 9011
  #           Status: Normal, Version: 2.0.5014
  #   Standby MDMs:
  #       Name: 192.168.0.5, ID: 0x0ce414fa06a17491, Manager
  #           IPs: 192.168.0.5, Management IPs: 192.168.0.5, Port: 9011
  #       Name: 192.168.0.6, ID: 0x74ccbc567622b992, Tie Breaker
  #           IPs: 192.168.0.6, Port: 9011
  mdm_components = {
    'scaleio_mdm_ips'           => ['/Master MDM/,/\(Tie-Breakers\)\|\(Standby MDMs\)/p', '/./,//p', 'IPs:'],
    'scaleio_tb_ips'            => ['/Tie-Breakers/,/Standby MDMs/p', '/./,//p', 'IPs:'],
    'scaleio_mdm_names'         => ['/Master MDM/,/\(Tie-Breakers\)\|\(Standby MDMs\)/p', '/./,//p', 'Name:'],
    'scaleio_tb_names'          => ['/Tie-Breakers/,/Standby MDMs/p', '/./,//p', 'Name:'],
    'scaleio_standby_mdm_ips'   => ['/Standby MDMs/,//p', '/Manager/,/Tie Breaker/p', 'IPs:'],
    'scaleio_standby_tb_ips'    => ['/Standby MDMs/,//p', '/Tie Breaker/,//p', 'IPs:'],
  }
  mdm_components.each do |name, selector|
    Facter.add(name) do
      setcode do
        # Define mdm opts for SCLI tool to connect to ScaleIO cluster.
        # If there is no mdm_ips available it is expected to be run on a node with MDM Master. 
        mdm_opts = []
        mdm_ips.split(',').each do |ip|
          mdm_opts.push("--mdm_ip %s" % ip)
        end
        ip = nil
        # the cycle over MDM IPs because for query cluster SCLI's behaiveour is strange 
        # it works for one IP but doesn't for the list.
        mdm_opts.each do |opts|
          cmd = "scli %s --query_cluster --approve_certificate 2>>/tmp/scaleio_dbg.log | sed -n '%s' | sed -n '%s' | awk '/%s/ {print($2)}' | tr -d ','" % [opts, selector[0], selector[1], selector[2]]
          debug_log(cmd)
          res = Facter::Util::Resolution.exec(cmd)
          ip = res.split(' ').join(',') unless !res
        end
        debug_log("%s='%s'" % [name, ip])
        ip
      end
    end
  end


  sds_sdc_components = {
    'scaleio_current_sdc_list' => ['sdc', 'IP: [^ ]*', nil],
    'scaleio_current_sds_list' => ['sds', 'Name: [^ ]*', 'Protection Domain'],
  }
  sds_sdc_components.each do |name, selector|
    Facter.add(name) do
      setcode do
        mdm_password = Facter.value(:mdm_password)
        mdm_opts = "--mdm_ip %s" % mdm_ips
        login_cmd = "scli %s --approve_certificate --login --username admin --password %s 2>>/tmp/scaleio_dbg.log" % [mdm_opts, mdm_password]
        query_cmd = "scli %s --approve_certificate --query_all_%s 2>>/tmp/scaleio_dbg.log" % [mdm_opts, selector[0]]
        cmd = "%s && %s" % [login_cmd, query_cmd]
        debug_log(cmd)
        result = Facter::Util::Resolution.exec(cmd)
        if result
          skip_cmd = ''
          if selector[2]
            skip_cmd = "grep -v '%s' | " % selector[2]
          end
          select_cmd = "%s grep -o '%s' | awk '{print($2)}'" % [skip_cmd, selector[1]]
          cmd = "echo '%s' | %s" % [result, select_cmd]
          debug_log(cmd)
          result = Facter::Util::Resolution.exec(cmd)
          if result
            result = result.split(' ')
            if result.count() > 0
              result = result.join(',')
            end
          end
        end
        debug_log("%s='%s'" % [name, result])
        result
      end
    end
  end
  
end # if mdm_ips and mdm_ips != ''