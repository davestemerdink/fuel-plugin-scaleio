$scaleio = hiera('scaleio')
if $scaleio['metadata']['enabled'] {
  
  notify{'ScaleIO plugin enabled': }

  case $::osfamily {
    'RedHat': {
      fail('This is temporary limitation. The only Ubuntu is supported for now.')
    }
    
    'Debian': {
      # nothing to do
    }

    default: {
      fail("Unsupported osfamily: ${::osfamily} operatingsystem: ${::operatingsystem}, module ${module_name} only support osfamily RedHat and Debian")
    }
  }

  scaleio_fuel::environment{['mdm', 'tb', 'gateway']: }

} else {
    notify{'ScaleIO plugin disabled': }
}
