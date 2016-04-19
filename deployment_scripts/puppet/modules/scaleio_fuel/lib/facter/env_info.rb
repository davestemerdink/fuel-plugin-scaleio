# This is a workaround because FUEL daemons don't inherit environment variables
require 'facter'


base_cmd = "bash -c 'source /etc/environment; echo $FACTER_%s'"
facters = ['controller_ips', 'tb_ips', 'mdm_ips', 'gateway_user', 'gateway_port', 'gateway_ips', 'gateway_password', 'mdm_password', 'storage_pools']
facters.each { |f|
  if ! Facter.value(f)
    Facter.add(f) do
      setcode base_cmd % f 
    end
  end
}
