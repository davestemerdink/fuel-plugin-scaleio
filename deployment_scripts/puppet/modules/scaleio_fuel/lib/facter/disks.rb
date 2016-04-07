
scaleio_sds_disk_guid = 'f2e81bdc-99b3-4bf6-a68f-dc794da6cd8e'

Facter.add('sds_storage_devices') do
  setcode do
    ls_cmd = "lsblk -nr -o KNAME,UUID | awk '/%s/ {print($1)}' | grep -o '[a-z]*'" % scaleio_sds_disk_guid
    disks = Facter::Util::Resolution.exec(ls_cmd).split('\n')
    disks.join(',')
  end
end