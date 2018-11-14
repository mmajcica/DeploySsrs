function New-DataSource()
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "CredentialRetrieval")]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "Password")]
    [CmdletBinding()]
    param
    (
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [string][parameter(Mandatory = $true)]$DataSourceName,
        [string]$Path = "/",
        [string][parameter(Mandatory = $true)]$ConnectString,
        [ValidateSet("SQL","SQLAZURE","OLEDB","OLEDB-MD","ORACLE","ODBC","XML","SHAREPOINTLIST","SAPBW","ESSBASE")][string][parameter(Mandatory = $true)]$Extension,
        [ValidateSet("Integrated","Prompt","None","Store")][string][parameter(Mandatory = $true)]$CredentialRetrieval,
        [string]$UserName,
        [string]$Password,
        [switch]$DisposeProxy,
        [switch]$Hidden,
        [switch]$WindowsCredentials,
        [switch]$ImpersonateUser,
        [switch]$Overwrite
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        try
        {
            $Definition = New-Object -TypeName SSRS.ReportingService2010.DataSourceDefinition
            $Definition.ConnectString = $ConnectString
            $Definition.Extension = $Extension
            $Definition.CredentialRetrieval = $CredentialRetrieval

            if ($CredentialRetrieval -eq "Store")
            {
                $Definition.UserName = $UserName
                $Definition.Password = $Password
            }

            $Definition.ImpersonateUserSpecified = $ImpersonateUser
            $Definition.WindowsCredentials = $WindowsCredentials

            $properties = $null

            if ($Hidden)
            {
                $hiddenProperty = New-Object -TypeName SSRS.ReportingService2010.Property
                $hiddenProperty.Name = 'Hidden'
                $hiddenProperty.Value = $Hidden
                
                $properties = @($hiddenProperty)
            }

            return $Proxy.CreateDataSource($DataSourceName, $Path, $Overwrite, $Definition, $properties)
        }
        finally
        {
            if ($DisposeProxy -and $Proxy)
            {
                $Proxy.Dispose()
            }
        }
    }
    END { }
}

function Get-ReportingServicePolicy()
{
    [CmdletBinding()]
    param
    (
        [string]$GroupUserName,
        [string[]]$Roles
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        [SSRS.ReportingService2010.Role[]]$ssrsRoles = @()

        foreach($role in $Roles)
        {
            $reportingRole = New-Object SSRS.ReportingService2010.Role
            $reportingRole.Name = $role
            
            $ssrsRoles += $reportingRole
        }

        $policy = New-Object SSRS.ReportingService2010.Policy
        $policy.GroupUserName = $GroupUserName
        $policy.Roles = $ssrsRoles

        return $policy
    }
    END { }
}

function Set-Policy()
{
    [CmdletBinding()]
    param
    (
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [string][parameter(Mandatory = $true)]$Path,
        [SSRS.ReportingService2010.Policy[]]$Policies,
        [switch]$DisposeProxy
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        try
        {
            $Proxy.SetPolicies($Path, $Policies)
        }
        finally
        {
            if ($DisposeProxy -and $Proxy)
            {
                $Proxy.Dispose()
            }
        }
    }
    END { }
}

function Get-Configuration()
{
    [OutputType([Folder])]
    [CmdletBinding()]
    param
    (
        [System.IO.FileInfo][parameter(Mandatory = $true)]$FilePath
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        if ($FilePath.Extension -eq ".json")
        {
            return GetJsonFolderItems -Folder (Get-Content -Path $FilePath | ConvertFrom-Json)
        }
        elseif ($FilePath.Extension -eq ".xml")
        {
            $Folder = (Select-Xml -Path $FilePath -XPath /Folder).Node

            return GetXmlFolderItems -Folder $Folder
        }
        else
        {
            throw "Invalid configuration file type."
        }        
    }
    END { }
}

function Publish-SsrsFolder()
{
    [CmdletBinding()]
    param
    (
        [Folder][parameter(Mandatory = $true)]$Folder,
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [string]$FilesFolder,
        [switch]$Overwrite
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }    
    }
    PROCESS
    {
        if ($Folder.Parent)
        {
            Write-Verbose "Processing folder '$($Folder.Name)'"
            
            $fullPath = New-SsrsFolder -Proxy $Proxy -FolderName $Folder.Name -Parent $Folder.Path() -Hidden:$Folder.Hidden
    
            Write-Verbose "Folder created. Full SSRS path of the object is '$fullPath'."

            $currentFolder = "$($Folder.Path().TrimEnd('/'))/$($Folder.Name)"

            Write-Verbose "Current folder '$($Folder.Name)' and it's path '$($Folder.Path())'"
        }
        else
        {
            $currentFolder = "/"

            Write-Verbose "Current folder is the root folder"
        }
        
        Set-SecurityPolicy -Proxy $Proxy -Folder $currentFolder -Name $Folder.Name -RoleAssignments $Folder.RoleAssignments -InheritParentSecurity:$Folder.InheritParentSecurity -Overwrite

        foreach($folder in $Folder.Folders)
        {
            Publish-SsrsFolder -Folder $folder -Proxy $Proxy -FilesFolder $FilesFolder -Overwrite:$Overwrite
        }
    }
    END { }
}

function Publish-DataSource()
{
    [CmdletBinding()]
    param
    (
        [Folder][parameter(Mandatory = $true)]$Folder,
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [switch]$Overwrite
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }    
    }
    PROCESS
    {
        if ($Folder.Parent)
        {            
            $currentFolder = "$($Folder.Path().TrimEnd('/'))/$($Folder.Name)"
        }
        else
        {
            $currentFolder = "/"
        }

        [SsrsDataSource[]]$dataSources = $null

        foreach($dataSource in $Folder.DataSources)
        {
            $ds = New-DataSource -Proxy $Proxy `
                            -DataSourceName $dataSource.Name `
                            -ConnectString $dataSource.ConnectionString `
                            -Extension $dataSource.Extension `
                            -Path $currentFolder `
                            -CredentialRetrieval $dataSource.CredentialRetrieval `
                            -UserName $dataSource.UserName `
                            -Password $dataSource.Password `
                            -Hidden:$dataSource.Hidden `
                            -WindowsCredentials:$dataSource.WindowsCredentials `
                            -ImpersonateUser:$dataSource.ImpersonateUser `
                            -Overwrite:$Overwrite `
                
            $ds | Out-String | Write-Verbose

            Set-SecurityPolicy -Proxy $Proxy -Folder $currentFolder -Name $dataSource.Name -RoleAssignments $dataSource.RoleAssignments -InheritParentSecurity:$dataSource.InheritParentSecurity -Overwrite:$Overwrite

            $dataSources += [SsrsDataSource]::new($ds.Name, $ds.Path, $ds.ID)
        }        

        foreach($folder in $Folder.Folders)
        {
            $dataSources += Publish-DataSource -Folder $folder -Proxy $Proxy -Overwrite:$Overwrite
        }

        return $dataSources
    }
    END { }
}

function Publish-DataSet()
{
    [CmdletBinding()]
    param
    (
        [Folder][parameter(Mandatory = $true)]$Folder,
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [string]$FilesFolder,
        [switch]$Overwrite
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }    
    }
    PROCESS
    {
        if ($Folder.Parent)
        {            
            $currentFolder = "$($Folder.Path().TrimEnd('/'))/$($Folder.Name)"
        }
        else
        {
            $currentFolder = "/"
        }

        [SsrsDataSet[]]$dataSets = $null

        foreach($dataSet in $Folder.DataSets)
        {
            $rsdPath = Join-Path $FilesFolder $dataSet.FileName

            if (Test-Path -LiteralPath $rsdPath -PathType Leaf)
            {
                New-SsrsDataSet -Proxy $Proxy `
                                -RsdPath $rsdPath `
                                -Path $currentFolder `
                                -Name $dataSet.Name `
                                -Hidden:$dataSet.Hidden `
                                -Overwrite:$Overwrite `
                    | Out-String | Write-Verbose
                
                Set-SecurityPolicy -Proxy $Proxy -Folder $currentFolder -Name $dataSet.Name -RoleAssignments $dataSet.RoleAssignments -InheritParentSecurity:$dataSet.InheritParentSecurity -Overwrite:$Overwrite
            
                $dataSets += [SsrsDataSet]::new($dataSet.Name, "$($currentFolder.TrimEnd('/'))/$($dataSet.Name)")
            }
            else
            {
                Write-Warning "File $($dataSet.FileName) has not be found in the path $FilesFolder."    
            }
        }

        foreach($folder in $Folder.Folders)
        {
            $dataSets += Publish-DataSet -Folder $folder -FilesFolder $FilesFolder -Proxy $Proxy -Overwrite:$Overwrite
        }

        return $dataSets
    }
    END { }
}

function Publish-Reports()
{
    [CmdletBinding()]
    param
    (
        [Folder][parameter(Mandatory = $true)]$Folder,
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [string]$FilesFolder,
        [SsrsDataSource[]]$DataSources,
        [SsrsDataSet[]]$DataSets,
        [bool]$ReferenceDataSources,
        [bool]$ReferenceDataSets,
        [switch]$Overwrite
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }    
    }
    PROCESS
    {
        if ($Folder.Parent)
        {            
            $currentFolder = "$($Folder.Path().TrimEnd('/'))/$($Folder.Name)"
        }
        else
        {
            $currentFolder = "/"
        }

        foreach($report in $Folder.Reports)
        {
            $rdlPath = Join-Path $FilesFolder $report.FileName

            if (Test-Path -LiteralPath $rdlPath -PathType Leaf)
            {
                New-SsrsReport -Proxy $Proxy `
                            -RdlPath $rdlPath `
                            -Path $currentFolder `
                            -Name $report.Name `
                            -DataSources $DataSources `
                            -ReferenceDataSources $ReferenceDataSources `
                            -DataSets $DataSets `
                            -ReferenceDataSets $ReferenceDataSets `
                            -Hidden:$report.Hidden `
                            -Overwrite:$Overwrite `
                    | Out-String | Write-Verbose

                Set-SecurityPolicy -Proxy $Proxy -Folder $currentFolder -Name $report.Name -RoleAssignments $report.RoleAssignments -InheritParentSecurity:$report.InheritParentSecurity -Overwrite:$Overwrite
            }
            else
            {
                Write-Warning "File $($report.FileName) has not be found in the path $FilesFolder. Skipping the deployment."
            }
        }

        foreach($folder in $Folder.Folders)
        {
            Publish-Reports -Folder $folder -FilesFolder $FilesFolder -Proxy $Proxy -DataSources $DataSources -ReferenceDataSources $ReferenceDataSources -DataSets $DataSets -ReferenceDataSets $ReferenceDataSets -Overwrite:$Overwrite
        }
    }
    END { }
}

function Set-SecurityPolicy()
{
    [CmdletBinding()]
    param
    (
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [string][parameter(Mandatory = $true)]$Folder,
        [string][parameter(Mandatory = $true)]$Name,
        [RoleAssignment[]]$RoleAssignments,
        [switch]$InheritParentSecurity,
        [switch]$Overwrite,
        [switch]$DisposeProxy
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        # if the item needs to be overwritten and it exists
        if ($Overwrite -and (Test-SsrsItem $Proxy $Folder))
        {
            # check if parent security needs to be inherited and if not already so
            if ($InheritParentSecurity -and -not (Test-InheritParentSecurity $Proxy $Folder))
            {
                Set-InheritParentSecurity $Proxy $Folder
            }
            else
            {
                if ($RoleAssignments)
                {
                    $policies = [SSRS.ReportingService2010.Policy[]]@()

                    foreach($group in $RoleAssignments)
                    {
                        $policy = Get-ReportingServicePolicy -GroupUserName $group.Name -Roles $group.Roles

                        $policies += $policy
                    }

                    if ($policies)
                    {
                        Set-Policy -Proxy $Proxy -Path $Folder -Policies $policies
                    }
                }
            }
        }
        else
        {
            
        }
    }
    END
    {
        if ($DisposeProxy -and $Proxy)
            {
                $Proxy.Dispose()
            }
    }
}

function GetJsonFolderItems($Folder, [Folder]$Parent = $null)
{
    $f = [Folder]::new($folder.name, $Parent, $folder.hidden)

    foreach($group in $folder.security)
    {
        $f.RoleAssignments += [RoleAssignment]::new($group.name, $group.roles)
    }

    foreach($dataSource in $folder.dataSources)
    {
        $d = [DataSource]::new($dataSource.name,`
                               $dataSource.connectionString,`
                               $dataSource.extension,`
                               $dataSource.credentialRetrieval,`
                               $dataSource.userName,`
                               $dataSource.password,`
                               $dataSource.windowsCredentials,`
                               $dataSource.impersonateUser,`
                               $dataSource.inheritParentSecurity,`
                               $dataSource.hidden)

        foreach($group in $dataSource.security)
        {
            $d.RoleAssignments += [RoleAssignment]::new($group.name, $group.roles)
        }

        $f.DataSources += $d
    }

    foreach($dataSet in $folder.dataSets)
    {
        $ds += [DataSet]::new($dataSet.name, $dataSet.fileName, $dataSet.inheritParentSecurity, $dataSet.hidden)

        foreach($group in $dataSet.security)
        {
            $ds.RoleAssignments += [RoleAssignment]::new($group.name, $group.roles)
        }

        $f.DataSets += $ds
    }

    foreach($report in $folder.reports)
    {
        $r += [Report]::new($report.name, $report.fileName, $report.inheritParentSecurity, $report.hidden)

        foreach($group in $report.security)
        {
            $r.RoleAssignments += [RoleAssignment]::new($group.name, $group.roles)
        }

        $f.Reports += $r
    }

    foreach($subFolder in $folder.folders)
    {
        $f.Folders += GetJsonFolderItems -Folder $subFolder -Parent $f
    }

    return $f
}

function GetXmlFolderItems($Folder, [Folder]$Parent = $null)
{
    $f = [Folder]::new($folder.name, $Parent, [System.Convert]::ToBoolean($folder.inheritParentSecurity), [System.Convert]::ToBoolean($folder.hidden))

    foreach($group in $folder.security.security)
    {
        $f.RoleAssignments += [RoleAssignment]::new($group.name, $group.roles.role)
    }

    foreach($dataSource in $folder.dataSources.dataSource)
    {
        $d = [DataSource]::new($dataSource.name,`
                               $dataSource.connectionString,`
                               $dataSource.extension,`
                               $dataSource.credentialRetrieval,`
                               $dataSource.userName,`
                               $dataSource.password,`
                               [System.Convert]::ToBoolean($dataSource.windowsCredentials),`
                               [System.Convert]::ToBoolean($dataSource.impersonateUser),`
                               [System.Convert]::ToBoolean($dataSource.inheritParentSecurity),`
                               [System.Convert]::ToBoolean($dataSource.hidden))
        
        foreach($group in $dataSource.security.security)
        {
            $d.RoleAssignments += [RoleAssignment]::new($group.name, $group.roles.role)
        }

        $f.DataSources += $d
    }

    foreach($dataSet in $folder.DataSets.dataSet)
    {
        $ds = [DataSet]::new($dataSet.name, $dataSet.fileName, [System.Convert]::ToBoolean($dataSet.inheritParentSecurity), [System.Convert]::ToBoolean($dataSet.hidden))

        foreach($group in $dataSet.security.security)
        {
            $ds.RoleAssignments += [RoleAssignment]::new($group.name, $group.roles.role)
        }

        $f.DataSets += $ds
    }

    foreach($report in $folder.Reports.report)
    {
        
        $r =  [Report]::new($report.name, $report.fileName, [System.Convert]::ToBoolean($report.inheritParentSecurity), [System.Convert]::ToBoolean($report.hidden))

        foreach($group in $report.security.security)
        {
            $r.RoleAssignments += [RoleAssignment]::new($group.name, $group.roles.role)
        }

        $f.Reports += $r
    }

    foreach($subFolder in $folder.folders.folder)
    {
        $f.Folders += GetXmlFolderItems -Folder $subFolder -Parent $f
    }

    return $f
}

function Test-SsrsItem()
{
    [CmdletBinding()]
    param
    (
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [string][parameter(Mandatory = $true)]$Path,
        [switch]$DisposeProxy
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        try
        {
            $item = $Proxy.GetItemType($path)

            if ($item -eq "Unknown")
            {
                return $false
            }

            return $true
        }
        finally
        {
            if ($DisposeProxy -and $Proxy)
            {
                $Proxy.Dispose()
            }
        }
    }
    END { }
}

function Test-InheritParentSecurity()
{
    [CmdletBinding()]
    param
    (
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [string][parameter(Mandatory = $true)]$Path,
        [switch]$DisposeProxy
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        try
        {
            $InheritParent = $true

            $Proxy.GetPolicies($path, [ref]$InheritParent) | Out-Null

            return $InheritParent
        }
        finally
        {
            if ($DisposeProxy -and $Proxy)
            {
                $Proxy.Dispose()
            }
        }
    }
    END { }
}

function Set-InheritParentSecurity()
{
    [CmdletBinding()]
    param
    (
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [string][parameter(Mandatory = $true)]$Path,
        [switch]$DisposeProxy
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        try
        {
            $Proxy.InheritParentSecurity($path) | Out-Null
        }
        finally
        {
            if ($DisposeProxy -and $Proxy)
            {
                $Proxy.Dispose()
            }
        }
    }
    END { }
}

function New-SsrsFolder()
{
    [CmdletBinding()]
    param
    (
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [string][parameter(Mandatory = $true)]$FolderName,
        [string]$Parent = "/",
        [switch]$DisposeProxy,
        [switch]$Hidden
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }

        if ($Parent -ne "/" -and $Parent.EndsWith("/"))
        {
            $Parent = $Parent.TrimEnd("/")
        }
    }
    PROCESS
    {
        try
        {
            # in case the path doesn't exist, create path
            if ($Parent -ne "/" -and -not (Test-SsrsItem $Proxy $Parent))
            {
                $path = $Parent -split '/'
                $name = $path[-1]
                $folder =  "/"

                if ($path.Count -gt 2)
                {
                    $folder = "/" + ($path[1..($path.Count - 2)] -join '/')
                }

                New-SsrsFolder -Proxy $Proxy -FolderName $name -Parent $folder -Hidden:$Hidden
            }

            $properties = $null
            
            if ($Hidden)
            {
                $hiddenProperty = New-Object -TypeName SSRS.ReportingService2010.Property
                $hiddenProperty.Name = 'Hidden'
                $hiddenProperty.Value = $Hidden
                
                $properties = @($hiddenProperty)
            }

            $folder = $Proxy.CreateFolder($FolderName, $Parent, $properties)
        }
        catch [System.Management.Automation.MethodInvocationException]
        {
            if ($_.Exception.Message.Contains("Microsoft.ReportingServices.Diagnostics.Utilities.ItemAlreadyExistsException"))
            {
                Write-Verbose "The folder '$FolderName' already exsists."

                $folder = @{}
                $folder.Path = (Join-Path -Path $Parent -ChildPath $FolderName).Replace("\","/")
            }
            else
            {
                throw $_.Exception
            }
        }
        finally
        {
            if ($DisposeProxy -and $Proxy)
            {
                $Proxy.Dispose()
            }
        }

        return $folder.Path
    }
    END { }
}

function Format-SsrsUrl()
{
	[CmdletBinding()]
	param
	(
		[string][parameter(Mandatory = $true)]$Url
	)
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
	PROCESS 
	{
        if (-not $Url.EndsWith('.asmx'))
        {    
            if (-not $Url.EndsWith('/'))
            {
                $Url += '/'
            }
            
            $Url += 'ReportService2010.asmx'
        }

        $uri = $Url -as [System.Uri] 

		if (-not ($uri.AbsoluteURI -ne $null -and $uri.Scheme -match '[http|https]'))
		{
			throw "Provided Url address is not a valid."
        }

		return $uri.AbsoluteURI
	}
	END { }
}

function Get-SsrsItem()
{
    [CmdletBinding()]
    param
    (
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [string]$Path = '/',
        [ValidateSet("Component", "Model", "LinkedReport", "Site", "DataSet", "Folder","DataSource","Report", "Resource")][parameter(Mandatory = $true)][string]$Type,
        [switch]$DisposeProxy
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        try
        {
            $items = $Proxy.ListChildren($Path, $true)

            $return = @()

            foreach($item in $items)
            {
                if ($item.TypeName -eq $Type)
                {
                    $return += $item
                }
            }

            return $return
        }
        finally
        {
            if ($DisposeProxy -and $Proxy)
            {
                $Proxy.Dispose()
            }
        }
    }
    END { }
}

function New-XmlNamespaceManager ($XmlDocument, $DefaultNamespacePrefix)
{
	$NsMgr = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList $XmlDocument.NameTable
	$DefaultNamespace = $XmlDocument.DocumentElement.GetAttribute('xmlns')

	if ($DefaultNamespace -and $DefaultNamespacePrefix)
    {
		$NsMgr.AddNamespace($DefaultNamespacePrefix, $DefaultNamespace)
	}

	return ,$NsMgr
}

function New-SsrsReport()
{
    [CmdletBinding()]
	param
	(
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [ValidateScript({Test-Path $_ -PathType 'Leaf'})][parameter(Mandatory = $true)][System.IO.FileInfo]$RdlPath,    
        [string]$Path = "/",
        [string]$Name,
        [SsrsDataSource[]]$DataSources,
        [SsrsDataSet[]]$DataSets,
        [bool]$ReferenceDataSources = $true,
        [bool]$ReferenceDataSets = $true,
        [switch]$Hidden,
        [switch]$Overwrite,
        [switch]$DisposeProxy
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS 
    {
        try
        {
            [xml]$Definition = Get-Content -Encoding UTF8 -Path $RdlPath
            $NsMgr = New-XmlNamespaceManager $Definition d

            $descriptionNode = $Definition.SelectSingleNode('d:Report/d:Description', $NsMgr)

            $properties = $null

            if ($Hidden)
            {
                $hiddenProperty = New-Object -TypeName SSRS.ReportingService2010.Property
                $hiddenProperty.Name = 'Hidden'
                $hiddenProperty.Value = $Hidden

                $properties = @($hiddenProperty)
            }

            if($descriptionNode -and $descriptionNode.Value)
            {
                $descriptionProperty = New-Object -TypeName SSRS.ReportingService2010.Property
                $descriptionProperty.Name = 'Description'
                $descriptionProperty.Value = $DescriptionNode.Value
                
                if ($properties)
                {
                    $properties += $descriptionProperty
                }
                else
                {
                    $properties = @($descriptionProperty)
                }
            }

            if (-not $Name)
            {
                $Name = $RdlPath.BaseName
            }

            if ($ReferenceDataSources -and $Datasources)
            {
                $nodes = $Definition.SelectNodes('d:Report/d:DataSources/d:DataSource/d:DataSourceReference/..', $NsMgr)

                foreach ($node in $nodes)
                {
                    $Datasources | Where-Object { $_.Name -eq $node.Name } | ForEach-Object { $node.DataSourceReference = $_.Path.ToString() ; $node.ChildNodes[2].InnerText = $_.Id }
                }
            }

            if ($ReferenceDataSets -and $DataSets)
            {
                $nodes = $Definition.SelectNodes('d:Report/d:DataSets/d:DataSet/d:SharedDataSet/d:SharedDataSetReference/..', $NsMgr)

                foreach($node in $nodes)
                {
                    @($Datasets | Where-Object { $_.Name -eq $node.ParentNode.Name }) | ForEach-Object { $node.SharedDataSetReference = $_.Path }
                }
            }

            $rawDefinition = [System.Text.Encoding]::UTF8.GetBytes($Definition.OuterXml)

            Write-Verbose "Creating report $Name"
            $warnings = $null
            
            $report = $Proxy.CreateCatalogItem("Report", $Name, $Path, $Overwrite, $rawDefinition, $properties, [ref]$warnings)

            if ($warnings)
            {
                $warnings.Message | Write-Warning
            }

            if ($ReferenceDataSources -and $Datasources)
            {
                [SSRS.ReportingService2010.DataSource[]]$RefDataSources = $null
                
                $nodes = $Definition.SelectNodes('d:Report/d:DataSources/d:DataSource/d:DataSourceReference/..', $NsMgr)

                foreach($node in $nodes)
                {
                    $ds = $Datasources | Where-Object { $_.Name -eq $node.Name } | Select-Object -First 1
                    
                    if ($ds)
                    {
                        $Reference = New-Object -TypeName SSRS.ReportingService2010.DataSourceReference
                        $Reference.Reference = $ds.Path

                        $DataSource = New-Object -TypeName SSRS.ReportingService2010.DataSource
                        $DataSource.Item = $Reference
                        $DataSource.Name = $node.Name

                        $RefDataSources += $DataSource
                    }
                    else
                    {
                        Write-Warning "The reference for datasource $($node.Name) can not be found."
                    }
                }

                if ($RefDataSources)
                {  
                    $Proxy.SetItemDataSources($report.Path, $RefDataSources)
                }
            }

            if ($ReferenceDataSets -and $DataSets)
            {
                [SSRS.ReportingService2010.ItemReference[]]$References = $null
                $nodes = $Definition.SelectNodes('d:Report/d:DataSets/d:DataSet/d:SharedDataSet/d:SharedDataSetReference/..', $NsMgr)

                foreach($node in $nodes)
                {
                    $ds = $DataSets | Where-Object { $_.Name -eq $node.ParentNode.Name } | Select-Object -First 1

                    if ($ds)
                    {
                        $Reference = New-Object -TypeName SSRS.ReportingService2010.ItemReference
                        $Reference.Reference = $ds.Path
                        $Reference.Name = $ds.Name
                
                        $References += $Reference
                    }
                    else
                    {
                        Write-Warning "The reference for dataset $($node.ParentNode.Name) can not be found."
                    }
                }

                if ($References)
                {
                    $Proxy.SetItemReferences($report.Path, $References)
                }
            }

            return $report
        }
        finally
        {
            if ($DisposeProxy -and $Proxy)
            {
                $Proxy.Dispose()
            }
        }
    }
    END { }
}

function New-SsrsDataSet()
{
    [CmdletBinding()]
	param
    (
        [System.Web.Services.Protocols.SoapHttpClientProtocol][parameter(Mandatory = $true)]$Proxy,
        [ValidateScript({Test-Path $_ -PathType 'Leaf'})][parameter(Mandatory = $true)][string]$RsdPath,
        [string]$Path = "/",
        [parameter(Mandatory = $true)][string]$Name,
        [switch]$Hidden,
        [switch]$DisposeProxy,
        [switch]$Overwrite
    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        try
        { 
            $RawDefinition = Get-Content -Encoding Byte -Path $RsdPath
            [xml]$Rsd = Get-Content -Path $RsdPath

            $properties = $null
            
            if ($Hidden)
            {
                $hiddenProperty = New-Object -TypeName SSRS.ReportingService2010.Property
                $hiddenProperty.Name = 'Hidden'
                $hiddenProperty.Value = $Hidden
                
                $properties = @($hiddenProperty)
            }

            $warnings = $null
        
            $results = $Proxy.CreateCatalogItem("DataSet", $Name, $Path, $Overwrite, $RawDefinition, $properties, [ref]$warnings)

            if ($warnings)
            {
                Write-Warning $warnings.Message
            }

            $dss = Get-SsrsItem -Proxy $Proxy -Type DataSource
            $ds = $dss | Where-Object { $_.Name -eq $Rsd.SharedDataSet.DataSet.Query.DataSourceReference } | Select-Object -First 1

            if ($ds)
            {
                $Reference = New-Object -TypeName SSRS.ReportingService2010.ItemReference
                $Reference.Reference = $ds.Path
                $Reference.Name = 'DataSetDataSource'

                $Proxy.SetItemReferences($results.Path, @($Reference))
            }
            else
            {
                Write-Warning "The reference for datasource $($Rsd.SharedDataSet.DataSet.Query.DataSourceReference) can not be found."
            }

            return $results
        }
        catch [System.Management.Automation.MethodInvocationException]
        {
            if ($_.Exception.Message.Contains("Microsoft.ReportingServices.Diagnostics.Utilities.ItemAlreadyExistsException"))
            {
                Write-Warning "The DataSet $Name already exsists in folder $Path. Use -Overwrite switch for replacing it with the current DataSet."
            }
            else
            {
                throw $_.Exception
            }
        }
        finally
        {
            if ($DisposeProxy -and $Proxy)
            {
                $Proxy.Dispose()
            }
        }
    }
    END { }
}

class Folder
{
    [ValidateNotNullOrEmpty()][string]$Name
    [Folder]$Parent
    [boolean]$InheritParentSecurity
    [ValidateNotNullOrEmpty()][boolean]$Hidden

    [Folder[]]$Folders
    [DataSource[]]$DataSources
    [DataSet[]]$DataSets
    [Report[]]$Reports
    [RoleAssignment[]]$RoleAssignments


    Folder($Name, [Folder]$Parent)
    {
        $this.Name = $Name
        $this.Parent = $Parent
        $this.InheritParentSecurity = $false
        $this.Hidden = $false
    }

    Folder($Name, [Folder]$Parent, $InheritParentSecurity, $Hidden)
    {
        $this.Name = $Name
        $this.Parent = $Parent
        $this.InheritParentSecurity = $InheritParentSecurity
        $this.Hidden = $Hidden
    }

    [string]Path()
    {
        if ($this.Parent -and $this.Parent.Name -ne "root")
        {
            return "$($this.Parent.Path().TrimEnd('/'))/$($this.Parent.Name)"
        }

        return "/"
    }
}

class Report
{
    [ValidateNotNullOrEmpty()][string]$Name
    [ValidateNotNullOrEmpty()][string]$FileName
    [boolean]$InheritParentSecurity
    [ValidateNotNullOrEmpty()][boolean]$Hidden
    [RoleAssignment[]]$RoleAssignments

    Report([string]$Name, [string]$FileName)
    {
        $this.Name = $Name
        $this.FileName = $FileName
        $this.InheritParentSecurity = $false
        $this.Hidden = $false
    }

    Report([string]$Name, [string]$FileName, $InheritParentSecurity, [boolean]$Hidden)
    {
        $this.Name = $Name
        $this.FileName = $FileName
        $this.InheritParentSecurity = $InheritParentSecurity
        $this.Hidden = $Hidden
    }
}

class DataSet
{
    [ValidateNotNullOrEmpty()][string]$Name
    [ValidateNotNullOrEmpty()][string]$FileName
    [boolean]$InheritParentSecurity
    [ValidateNotNullOrEmpty()][boolean]$Hidden
    [RoleAssignment[]]$RoleAssignments

    DataSet([string]$Name, [string]$FileName)
    {
        $this.Name = $Name
        $this.FileName = $FileName
        $this.InheritParentSecurity = $false
        $this.Hidden = $false
    }

    DataSet([string]$Name, [string]$FileName, $InheritParentSecurity, [boolean]$Hidden)
    {
        $this.Name = $Name
        $this.FileName = $FileName
        $this.InheritParentSecurity = $InheritParentSecurity
        $this.Hidden = $Hidden
    }
}

class DataSource
{
    [ValidateNotNullOrEmpty()][string]$ConnectionString
    [ValidateNotNullOrEmpty()][string]$Name
    [ValidateNotNullOrEmpty()][string]$Extension
    [ValidateNotNullOrEmpty()][string]$CredentialRetrieval
    [string]$UserName
    [string]$Password
    [boolean]$WindowsCredentials
    [boolean]$ImpersonateUser
    [boolean]$InheritParentSecurity
    [ValidateNotNullOrEmpty()][boolean]$Hidden
    [RoleAssignment[]]$RoleAssignments

    DataSource([string]$Name, [string]$ConnectionString, [string]$Extension, [string]$CredentialRetrieval, [string]$UserName, [string]$Password, [boolean]$WindowsCredentials, [boolean]$ImpersonateUser)
    {
        $this.Name = $Name
        $this.ConnectionString = $ConnectionString
        $this.Extension = $Extension
        $this.CredentialRetrieval = $CredentialRetrieval
        $this.UserName = $UserName
        $this.Password = $Password
        $this.WindowsCredentials = $WindowsCredentials
        $this.ImpersonateUser = $ImpersonateUser
        $this.InheritParentSecurity = $false
        $this.Hidden = $false
    }
    DataSource([string]$Name, [string]$ConnectionString, [string]$Extension, [string]$CredentialRetrieval, [string]$UserName, [string]$Password, [boolean]$WindowsCredentials, [boolean]$ImpersonateUser, $InheritParentSecurity, [boolean]$Hidden)
    {
        $this.Name = $Name
        $this.ConnectionString = $ConnectionString
        $this.Extension = $Extension
        $this.CredentialRetrieval = $CredentialRetrieval
        $this.UserName = $UserName
        $this.Password = $Password
        $this.WindowsCredentials = $WindowsCredentials
        $this.ImpersonateUser = $ImpersonateUser
        $this.InheritParentSecurity = $InheritParentSecurity
        $this.Hidden = $Hidden
    }
}

class RoleAssignment
{
    [ValidateNotNullOrEmpty()][string]$Name
    [ValidateNotNullOrEmpty()][string[]]$Roles

    RoleAssignment([string]$Name, [string[]]$Roles)
    {
        $this.Name = $Name
        $this.Roles = $Roles
    }

    [string] ToString() { return "$($this.Name)" }
}

class SsrsDataSource
{
    [ValidateNotNullOrEmpty()][string]$Id
    [ValidateNotNullOrEmpty()][string]$Path
    [ValidateNotNullOrEmpty()][string]$Name

    SsrsDataSource([string]$Name, [string]$Path, [string]$Id)
    {
        $this.Id = $Id
        $this.Name = $Name
        $this.Path = $Path
    }

    [string] ToString() { return "$($this.Name)" }
}

class SsrsDataSet
{
    [ValidateNotNullOrEmpty()][string]$Path
    [ValidateNotNullOrEmpty()][string]$Name

    SsrsDataSet([string]$Name, [string]$Path)
    {
        $this.Name = $Name
        $this.Path = $Path
    }

    [string] ToString() { return "$($this.Name)" }
}