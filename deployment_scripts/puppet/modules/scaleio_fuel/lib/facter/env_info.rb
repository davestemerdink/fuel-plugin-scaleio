# This is a workaround because FUEL daemons don't inherit environment variables
require 'facter'
require 'json'

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
      login_req   = "curl -k --basic --connect-timeout 5 --user #{user}:#{password} #{login_url} 2>/dev/null | sed 's/\"//g'"
      token       = Facter::Util::Resolution.exec(login_req)
      if token && token != ''
        req_url     = "curl -k --basic --connect-timeout 10 --user #{user}:#{token} #{config_url} 2>/dev/null"
        config_str  = Facter::Util::Resolution.exec(req_url)
        config      = JSON.parse(config_str)
        mdm_ips     = config['mdmAddresses'].join(',')
        mdm_ips
      else
        nil
      end
    end
  end
end

cluster_components = {
  'current_master_mdm_ip' => 'Master MDM',
  'current_slave_ips'     => 'Slave MDMs',
  'current_tb_ips'        => 'Tie-Breakers',
}

cluster_components.each do |name, selector|
  Facter.add(name) do
    setcode do
      mdm_ips = Facter.value(:controller_ips)
      if mdm_ips && mdm_ips != ''
        mdm_opts = []
        mdm_ips.split(',').each do |ip|
          mdm_opts.push("--mdm_ip %s" % ip)
        end
      else
        mdm_opts = ['']
      end
      ip = nil
      mdm_opts.each do |opts|
        cmd = "scli %s --query_cluster --approve_certificate | grep  -A 2 '%s' | awk '/IPs:/ {print($2)}' | tr -d ','" % [opts, selector]
        res = Facter::Util::Resolution.exec(cmd)
        ip = res unless !res
      end
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
      mdm_ips = Facter.value(:mdm_ips)
      mdm_password = Facter.value(:mdm_password)
      if mdm_ips && mdm_ips != ''
        mdm_opts = "--mdm_ip %s" % mdm_ips
      else
        mdm_opts = ''
      end
      login_cmd = "scli %s --approve_certificate --login --username admin --password %s" % [mdm_opts, mdm_password]
      query_cmd = "scli %s --approve_certificate --query_all_%s" % [mdm_opts, selector[0]]
      result = Facter::Util::Resolution.exec("%s && %s" % [login_cmd, query_cmd])
      if result
        skip_cmd = ''
        if selector[2]
          skip_cmd = "grep -v '%s' | " % selector[2]
        end
        select_cmd = "%s grep -o '%s' | awk '{print($2)}'" % [skip_cmd, selector[1]]
        result = Facter::Util::Resolution.exec("echo '%s' | %s" % [result, select_cmd])
        if result
          result = result.split(' ')
          if result.count() > 0
            result = result.join(',')
          end
        end
      end
      result
    end
  end
end
