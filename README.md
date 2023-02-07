# ContainerMine

Makes a bootable VHDX from a Dockerfile.  Usable in Windows!

## Usage

```
# Populate a bootable Dockerfile from the sample
New-LinuxVHDXDockerfile

# Grab your public key if it exists
$PubKey = ""
if (Test-Path -PathType Leaf $HOME\.ssh\id_rsa.pub) {
    $PubKey = (Get-Content $HOME\.ssh\id_rsa.pub)
}

# Build the disk image
New-LinuxVHDX -RootAuthorizedKeys $PubKey

# And now launch a VM using it.  Adapt to your needs.
$vm = New-VM `
             -name containermine `
             -memorystartupbytes 1024MB `
             -Generation 2 `
             -BootDevice VHD `
             -VHDPath .\linux.vhdx   
$vm | Set-VMFirmware -enablesecureboot off
$vmna = ($vm | Get-VMNetworkAdapter)
$switch = Get-VMSwitch |? {$_.SwitchType -eq "External"}
$vmna | Connect-VMNetworkAdapter -switchname $switch.Name
$vm | Start-VM
```