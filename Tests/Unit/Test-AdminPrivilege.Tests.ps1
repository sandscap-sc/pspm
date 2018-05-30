#region Initialize
$script:moduleName = 'pspm'
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Requires Pester 4.1.0 or higher
Import-Module Pester -Force -MinimumVersion '4.1.0'

# Import test target module
Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath 'pspm.psd1') -Force
#endregion Initialize

#region Testing
# Begin Test
try {
    InModuleScope 'pspm' {
        Describe 'Test-AdminPrivilege' {

            Context 'Administrator' {
                Mock IsWindows {$true}

                Mock New-Object {
                    (New-Object -TypeName psobject) | Add-Member -MemberType ScriptMethod -Name IsInRole -Value {$true} -PassThru
                } -ParameterFilter {$TypeName -eq 'Security.Principal.WindowsPrincipal'}

                It 'return $true' {
                    Test-AdminPrivilege | Should -Be $true
                }
            }

            Context 'Not Administrator' {
                Mock IsWindows {$true}

                Mock New-Object {
                    (New-Object -TypeName psobject) | Add-Member -MemberType ScriptMethod -Name IsInRole -Value {$false} -PassThru
                } -ParameterFilter {$TypeName -eq 'Security.Principal.WindowsPrincipal'}

                It 'return $false' {
                    Test-AdminPrivilege | Should -Be $false
                }
            }

            Context 'Not Windows' {
                Mock IsWindows {$false}
                
                It 'return $true' {
                    Test-AdminPrivilege | Should -Be $true
                }
            }
        }
    }
}
finally {
    Remove-Module -Name $script:moduleName -Force
}
#endregion Testing