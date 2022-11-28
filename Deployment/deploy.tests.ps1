# Current working directory
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# System-under-test
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".tests.", ".functions.")

# Dot sourcing for Pester, functions below will run as though typed at the command prompt
. "$here\$sut"

Describe -Name 'Should fail to upload to S3' {
    # Dot source our functions + scrub/add/mock any module dependencies here
    BeforeAll {
        . $PSScriptRoot\deploy.functions.ps1    
    }

    Context "when supplied source filepath is invalid" {
        It "throws expected exception" {
            WriteToS3Bucket -relativePath $null `
            | Should -Not -HaveParameter $relativePath
        }
    }

    Context "when stated bucket does not exist" {
        Mock Test-S3Bucket {
            return $false
        }

        It "throws expected exception" {
            WriteToS3Bucket -relativePath 'BadDrive:\BadDirectory' `
            | Should -Throw -ExpectedMessage 'Invalid file path!'
        }
    }
}