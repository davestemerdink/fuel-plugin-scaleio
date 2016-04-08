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
    parts.join(',')
  end
end
