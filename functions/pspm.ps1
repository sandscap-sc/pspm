function pspm {
    [CmdletBinding(DefaultParameterSetName = 'Json')]
    param
    (
        # Parameter help description
        [Parameter(Mandatory, Position = 0)]
        [string]
        $Command = 'install',

        # Parameter help description
        [Parameter(position = 1, ParameterSetName = 'ModuleName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('Global', 'CurrentUser')]
        [string]
        $Scope,

        [Parameter()]
        [alias('g')]
        [switch]
        $Global,

        [Parameter()]
        [alias('s')]
        [switch]
        $Save,

        [Parameter()]
        [switch]$Clean
    )

    #region Initialize
    $script:ModuleRoot = Split-Path -Parent $PSScriptRoot
    $script:CurrentDir = Convert-Path .
    $script:ModuleDir = (Join-path $CurrentDir '\Modules')
    $script:UserPSModulePath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) 'WindowsPowerShell\Modules'
    $script:GlobalPSModulePath = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
    #endregion

    #region Scope parameter
    if ($Global) {
        $Scope = 'Global'
    }

    if ($Scope) {
        if ($Clean) {
            Write-Warning ("You can't use '-Clean' with '-Scope'")
            $Clean = $false
        }

        if ($Scope -eq 'Global') {
            #Check for Admin Credentials
            $local:currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            if (-Not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                throw [System.InvalidOperationException]::new('Administrator rights are required to install modules in "{0}"' -f $GlobalPSModulePath)
                return
            }

            $ModuleDir = $GlobalPSModulePath
        }
        elseif ($Scope -eq 'CurrentUser') {
            $ModuleDir = $UserPSModulePath
        }
    }
    #endregion

    Write-Host ('Modules will be saved in "{0}"' -f $ModuleDir)
    if (-Not (Test-Path $ModuleDir)) {
        New-Item -Path $ModuleDir -ItemType Directory
    }
    elseif ($Clean) {
        Get-ChildItem -Path $ModuleDir -Directory | Remove-Item -Recurse -Force
    }

    if ($PSCmdlet.ParameterSetName -eq 'ModuleName') {
        $targetModule = getModule -Version $Name -Path $ModuleDir

        if ($targetModule) {
            Write-Host ('{0}@{1}: Importing module.' -f $targetModule.Name, $targetModule.ModuleVersion)
            Import-Module (Join-path $ModuleDir $targetModule.Name) -Force -Global

            if ($Save) {
                if (Test-Path (Join-path $CurrentDir '\package.json')) {
                    $PackageJson = Get-Content -Path (Join-path $CurrentDir '\package.json') -Raw | ConvertFrom-Json
                    if (-Not $PackageJson.dependencies) {
                        $PackageJson | Add-Member -NotePropertyName 'dependencies' -NotePropertyValue ([PSCustomObject]@{})
                    }
                }
                else {
                    $PackageJson = [PSCustomObject]@{
                        dependencies = [PSCustomObject]@{}
                    }
                }

                $PackageJson.dependencies | Add-Member -NotePropertyName $targetModule.Name -NotePropertyValue ([string]$targetModule.ModuleVersion) -Force
                $PackageJson | ConvertTo-Json | Format-Json | Out-File -FilePath (Join-path $CurrentDir '\package.json') -Force -Encoding utf8
            }
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Json') {
        if (Test-Path (Join-path $CurrentDir '\package.json')) {
            $PackageJson = Get-Content -Path (Join-path $CurrentDir '\package.json') -Raw | ConvertFrom-Json
            
            $PackageJson.dependencies | Get-Member -MemberType NoteProperty | `
                ForEach-Object {
                $moduleName = $_.Name
                $version = $PackageJson.dependencies.($_.Name)

                try {
                    $targetModule = getModule -Name $moduleName -Version $version -Path $ModuleDir -ErrorAction Stop
                
                    if ($targetModule) {
                        Write-Host ('{0}@{1}: Importing module.' -f $targetModule.Name, $targetModule.ModuleVersion)
                        Import-Module (Join-path $ModuleDir $targetModule.Name) -Force -Global
                    }
                }
                catch {
                    Write-Error ('{0}: {1}' -f $moduleName, $_.Exception.Message)
                }
            }
        }
        else {
            Write-Error ('Cloud not find package.json in the current directory')
            return
        }
    }
}

