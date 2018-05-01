[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try
{
    $url = Get-VstsInput -Name "url" -Require
    $ssrsFilePath = Get-VstsInput -Name "ssrsFilePath" -Require  
    $rdlFilesFolder = Get-VstsInput -Name "rdlFilesFolder" -Require
    $authScheme = Get-VstsInput -Name "authscheme" -Require
    $username = Get-VstsInput -Name "username"
    $password = Get-VstsInput -Name "password"
    $overwrite = Get-VstsInput -Name "overwrite" -AsBool
    $referenceDataSources = Get-VstsInput -Name "referenceDataSources" -AsBool
    $referenceDataSets = Get-VstsInput -Name "referenceDataSets" -AsBool

    Import-Module -Name $PSScriptRoot\ps_modules\ssrs.psm1

    $url = Format-SsrsUrl -Url $url

    if ($authScheme -eq "windowsAuthentication")
    {
        $proxy = New-WebServiceProxy -Uri $url -Namespace SSRS.ReportingService2010 -UseDefaultCredential -Class "SSRS"
    }
    else
    {
        $securePassword = ConvertTo-SecureString -String $password -asPlainText -Force
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $securePassword
        
        $proxy = New-WebServiceProxy -Uri $url -Namespace SSRS.ReportingService2010 -Credential $credential -Class "SSRS"
    }

    if(-not (Test-Path $rdlFilesFolder -PathType Container))
    {
        throw "Provided files folder path $rdlFilesFolder is not valid."
    }

    if(Test-Path $ssrsFilePath -PathType Leaf)
    {
        $folder = Get-Configuration -FilePath $ssrsFilePath
    }
    else
    {
        throw "Provided configuration file path $ssrsFilePath is not valid."
    }

    Publish-SsrsFolder -Folder $folder -Proxy $proxy -FilesFolder $rdlFilesFolder -Overwrite:$overwrite
    $dataSources = Publish-DataSource -Folder $folder -Proxy $proxy -Overwrite:$overwrite
    $dataSets = Publish-DataSet -Folder $folder -Proxy $proxy -FilesFolder $rdlFilesFolder -Overwrite:$overwrite
    Publish-Reports -Folder $folder -Proxy $proxy -FilesFolder $rdlFilesFolder -DataSources $dataSources -ReferenceDataSources $referenceDataSources -DataSets $dataSets -ReferenceDataSets $referenceDataSets -Overwrite:$overwrite
}
finally
{
    if ($proxy)
    {
        $proxy.Dispose()
    }

    Trace-VstsLeavingInvocation $MyInvocation
}
