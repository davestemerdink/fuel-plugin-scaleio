# This is a workaround because FUEL daemons don't inherit environment variables
require 'facter'
require 'json'

base_cmd = "bash -c 'source /etc/environment; echo $FACTER_%s'"
facters = ['tb_ips', 'mdm_ips', 'gateway_user', 'gateway_port', 'gateway_ips', 'gateway_password', 'mdm_password', 'storage_pools']
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

Facter.add('master_mdm_ip') do
  setcode do
    mdm_ips = Facter.value(:mdm_ips)
    if mdm_ips && mdm_ips != ''
      mdm_opts = "--mdm_ip %s" % mdm_ips
      first_ip = mdm_ips.split(',')[0]
    else
      mdm_opts = ''
      first_ip = ''
    end
    ip = Facter::Util::Resolution.exec("scli %s --query_cluster --approve_certificate | grep  -A 2 'Master MDM' | awk '/IPs:/ {print($2)}' | tr -d ','" % mdm_opts)
    if ip and ip != ''
      ip
    else
      first_ip
    end
  end
end
