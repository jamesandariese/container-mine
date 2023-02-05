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
        [Parameter()][AllowEmptyString()][string] $Dockerfile,
        [Parameter()][AllowEmptyString()][string] $RootAuthorizedKeys,
        [Parameter()][string] $OutputPath = ".",
        [Parameter()][string] $Name = "linux"
    )
    $origloc = Get-Location
 
    $dockerctx = $DockerContext
    if ($dockerctx -eq "") {
        $dockerctx = $origloc
    }

    $dockerfile = $Dockerfile
    if ($dockerfile -eq "") {
	$dockerfile = "${dockerctx}\Dockerfile"
    }

    if (-not (test-path -pathtype leaf $dockerfile)) {
        Write-Error "$dockerfile does not exist.  cannot convert it into a VM!"
        return
    }

    $tmp = ""
    while ($true) {
        try {
            $tmp = New-Item -Path $OutputPath\.temp-$(Get-Random) -itemtype directory
            break
        } catch {}
    }

    $buildId = (New-Guid).Guid

    try {
	&{
            $cmimage="container-mine-base:$buildId"
            $bdimage="container-mine-build:$buildId"
            $output="container-mine-$buildId.vhdx"

            docker build --build-arg "ROOT_AUTHORIZED_KEYS=${RootAuthorizedKeys}" -f $dockerfile --progress plain -t $cmimage $dockerctx
	        docker build -f $PSScriptRoot\Dockerfile.builder --build-arg "BASE_IMAGE=$cmimage" --progress plain -t $bdimage $PSScriptRoot

            $wip = (docker create $bdimage) 2>&1
            if (Test-Path ${OutputPath}\${Name}.VHDX) {
                Remove-Item -Force "${OutputPath}\${Name}.VHDX"
            }
	    docker cp ${wip}:/mkimage.vhdx ${OutputPath}/${Name}.VHDX
        } | foreach-object {"$_"} | write-host
    } finally {
        Remove-Item -Recurse $tmp
        Set-Location $origloc
    }
}

