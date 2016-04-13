scaleio_sds_disk_guid = 'f2e81bdc-99b3-4bf6-a68f-dc794da6cd8e'

Facter.add('sds_storage_devices') do
  setcode do
    disks = Facter::Util::Resolution.exec("lsblk -nr -o KNAME,TYPE | awk '/disk/ {print($1)}'").split(' ')
    parts = []
    disks.each do |d|
      disk_path =  "/dev/%s" % d
      part_number = Facter::Util::Resolution.exec("partx -s %s -oTYPE,NR | awk '/%s/ {print($2)}'" % [disk_path, scaleio_sds_disk_guid])
      parts.push("%s%s" % [disk_path, part_number]) unless !part_number
    end
    if parts.count() > 0
      parts.join(',')
    else
      nil
    end
  end
end


# facter to validate storage devices that are less than 96GB
Facter.add('sds_storage_small_devices') do
  setcode do
    result = nil
    disks = Facter.value('sds_storage_devices')
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
