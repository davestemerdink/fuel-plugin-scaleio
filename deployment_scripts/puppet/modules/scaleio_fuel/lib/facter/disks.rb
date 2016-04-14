scaleio_tier1_guid = 'f2e81bdc-99b3-4bf6-a68f-dc794da6cd8e'
scaleio_tier2_guid = 'd5321bb3-1098-433e-b4f5-216712fcd06f'

scaleio_tiers = {
  'tier1' => scaleio_tier1_guid,
  'tier2' => scaleio_tier2_guid,
}

scaleio_tiers.each do |tier, part_guid| 
  Facter.add("sds_storage_devices_%s" % tier) do
    setcode do
      disks = Facter::Util::Resolution.exec("lsblk -nr -o KNAME,TYPE | awk '/disk/ {print($1)}'").split(' ')
      parts = []
      disks.each do |d|
        disk_path =  "/dev/%s" % d
        part_number = Facter::Util::Resolution.exec("partx -s %s -oTYPE,NR | awk '/%s/ {print($2)}'" % [disk_path, part_guid])
        parts.push("%s%s" % [disk_path, part_number]) unless !part_number
      end
      if parts.count() > 0
        parts.join(',')
      else
        nil
      end
    end
  end
end


# facter to validate storage devices that are less than 96GB
Facter.add('sds_storage_small_devices') do
  setcode do
    result = nil
    disks1 = Facter.value('sds_storage_devices_tier1')
    disks2 = Facter.value('sds_storage_devices_tier2')
    if disks1 or disks2
      disks = [disks1, disks2].join(',')
    end
    if disks
      devices = disks.split(',')
      if devices.count() > 0
        devices.each do |d|
          size = Facter::Util::Resolution.exec("partx -r -b -o SIZE %s | grep -v SIZE" % d)
          if size and size.to_i < 96*1024*1024*1024
            if not result
              result = {}
            end
            result[d] = "%s MB" % (size.to_i / 1024 / 1024)
          end
        end
        result = result.to_s         
      end 
    end
    result
  end
end
