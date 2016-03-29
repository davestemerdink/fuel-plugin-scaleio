define env_fact($role, $fact, $value) {
  file_line { "Append a FACTER_${role}_${fact} line to /etc/environment":
    ensure  => present,
    path    => '/etc/environment',
    match   => "^FACTER_${role}_${fact}=",
    line    => "FACTER_${role}_${fact}=${value}",
  }  
}
