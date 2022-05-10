function New-LinuxVHDX()
{
    param(
        [Parameter()][AllowEmptyString()][string] $ComputerName,
        [Parameter()][AllowEmptyString()][string] $DockerContext,
        [string] $Dockerfile = "Dockerfile",
        [Parameter()][string] $OutputPath = ".",
        [Parameter()][string] $Name = "linux"
    )
    $origloc = Get-Location
    
    $dockerctx = $DockerContext
    if ($dockerctx -eq "") {
        $dockerctx = "."
    }

    if (-not (test-path -pathtype leaf $dockerctx\$Dockerfile)) {
        Write-Error "$dockerctx\$Dockerfile does not exist.  cannot convert it into a VM!"
        return
    }

    $tmp = ""
    while ($true) {
        try {
            $tmp = New-Item -Path $OutputPath\.temp-$(Get-Random) -itemtype directory
            break
        } catch {}
    }

    $block = {
        docker build -t guestfs -f $PSScriptRoot\Dockerfile.appliance $PSScriptRoot 2>&1



        docker build -f $dockerctx\$Dockerfile --iidfile $tmp\iid.txt $dockerctx 2>&1
        $wip = (docker create (Get-Content $tmp\iid.txt))
        docker export $wip -o $tmp\wip.tar 2>&1
        docker rm $wip 2>&1
        docker run --device /dev/kvm -v "${PSScriptRoot}:/src" -v "${tmp}:/work" -w /work -ti guestfs bash /src/builddisk.sh
        $PSScriptRoot
        dir $PSScriptRoot
        $tmp
        dir $tmp
        docker run --device /dev/kvm -v "${PSScriptRoot}:/src" -v "${tmp}:/work" -w /work -ti guestfs qemu-img convert wip.qcow2 -O vpc wip.vhd
        if (Test-Path ${OutputPath}\${Name}.VHDX) {
            Remove-Item -Force "${OutputPath}\${Name}.VHDX"
        }
        Convert-VHD "${tmp}\wip.vhd" "${OutputPath}\${Name}.VHDX" -VHDType Dynamic
    }

    try {
        if ($ComputerName -ne "") {
            Invoke-Command -ComputerName $ComputerName -ScriptBlock $block
        } else {
            &$block
        }
    } finally {
        Remove-Item -Recurse $tmp
        Set-Location $origloc
    }
}

write-output $PSScriptRoot
write-output "hello"