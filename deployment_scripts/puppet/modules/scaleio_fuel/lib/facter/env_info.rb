# This is a workaround because FUEL daemons dont inherit evnironment variables
require 'facter'

base_cmd = "bash -c 'source /etc/environment; echo $FACTER_%s'"
facters = ['tb_ips', 'mdm_ips', 'gateway_ips']
facters.each { |f|
  if ! Facter.value(f)
    Facter.add(f) do
      setcode base_cmd % f 
    end
  end
}

