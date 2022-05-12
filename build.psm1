function New-LinuxVHDXDockerfile()
{
    param(
        [string] $Dockerfile = "Dockerfile"
    )
    Copy-Item $PSScriptRoot\Dockerfile.example $Dockerfile
}

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

    try {
	&{
            docker build -f $PSScriptRoot\Dockerfile.appliance --progress plain --iidfile $tmp\guestfs-iid.txt $PSScriptRoot
            docker build -f $dockerctx\$Dockerfile --progress plain --iidfile $tmp\iid.txt $dockerctx

            $guestfs = (get-content $tmp\guestfs-iid.txt)
            $wip = (docker create (Get-Content $tmp\iid.txt)) 2>&1
            
	    docker export $wip -o $tmp\wip.tar 2>&1
            docker rm $wip 2>&1
	    
            docker run --device /dev/kvm -v "${PSScriptRoot}:/src" -v "${tmp}:/work" -w /work -ti $guestfs bash /src/builddisk.sh
            docker run --device /dev/kvm -v "${PSScriptRoot}:/src" -v "${tmp}:/work" -w /work -ti $guestfs qemu-img convert wip.qcow2 -O vpc wip.vhd
            if (Test-Path ${OutputPath}\${Name}.VHDX) {
                Remove-Item -Force "${OutputPath}\${Name}.VHDX"
            }
        } | foreach-object {"$_"}| write-host

        Convert-VHD "${tmp}\wip.vhd" "${OutputPath}\${Name}.VHDX" -VHDType Dynamic -Passthru
    } finally {
        Remove-Item -Recurse $tmp
        Set-Location $origloc
    }
}

