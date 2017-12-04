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
        [string][parameter(Mandatory = $true)]$FilePath,
        [ConfigurationSource][parameter(Mandatory = $true)]$ConfigurationSource

    )
    BEGIN
    {
        Write-Verbose "Entering script $($MyInvocation.MyCommand.Name)"
        Write-Verbose "Parameter Values"
        $PSBoundParameters.Keys | ForEach-Object { Write-Verbose "$_ = '$($PSBoundParameters[$_])'" }
    }
    PROCESS
    {
        if ($ConfigurationSource -eq [ConfigurationSource]::JSON)
        {
            return GetJsonFolderItems -Folder (Get-Content -Path $FilePath | ConvertFrom-Json)
        }

        $Folder = (Select-Xml -Path $FilePath -XPath /Folder).Node

        return GetXmlFolderItems -Folder $Folder
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
        }
        else
        {
            $currentFolder = "/"
        }

        write-verbose "Current folder $($Folder.Name) and it's path $($Folder.Path())"

        

        $policies = [SSRS.ReportingService2010.Policy[]]@()

        foreach($group in $Folder.RoleAssignments)
        {
            $policy = Get-ReportingServicePolicy -GroupUserName $group.Name -Roles $group.Roles

            $policies += $policy
        }

        if ($policies)
        {
            Set-Policy -Proxy $Proxy -Path $currentFolder -Policies $policies
        }

        foreach($dataSource in $Folder.DataSources)
        {
            New-DataSource -Proxy $Proxy `
                            -DataSourceName $dataSource.Name `
                            -ConnectString $dataSource.ConnectionString `
                            -Extension $dataSource.Extension `
                            -Path $currentFolder `
                            -CredentialRetrieval $dataSource.CredentialRetrieval `
                            -UserName $dataSource.UserName `
                            -Password $dataSource.Password `
                            -Hidden:$dataSource.Hidden `
                            -Overwrite:$Overwrite `
                | Out-String | Write-Verbose
        }

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
            }
            else
            {
                Write-Warning "File $($dataSet.FileName) has not be found in the path $FilesFolder."    
            }
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
                            -Hidden:$report.Hidden `
                            -Overwrite:$Overwrite `
                    | Out-String | Write-Verbose
            }
            else
            {
                Write-Warning "File $($report.FileName) has not be found in the path $FilesFolder."    
            }
        }

        foreach($folder in $Folder.Folders)
        {
            Publish-SsrsFolder -Folder $folder -Proxy $Proxy -FilesFolder $FilesFolder -Overwrite:$Overwrite
        }
    }
    END { }
}

enum ConfigurationSource
{
    JSON
    XML
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
        $f.DataSources += [DataSource]::new($dataSource.name, $dataSource.connectionString, $dataSource.extension, $dataSource.credentialRetrieval, $dataSource.userName, $dataSource.password, $dataSource.hidden)
    }

    foreach($dataSet in $folder.dataSets)
    {
        $f.DataSets += [DataSet]::new($dataSet.name, $dataSet.fileName, $dataSet.hidden)
    }

    foreach($report in $folder.reports)
    {
        $f.Reports += [Report]::new($report.name, $report.fileName, $report.hidden)
    }

    foreach($subFolder in $folder.folders)
    {
        $f.Folders += GetJsonFolderItems -Folder $subFolder -Parent $f
    }

    return $f
}
function GetXmlFolderItems($Folder, [Folder]$Parent = $null)
{
    $f = [Folder]::new($folder.name, $Parent, [System.Convert]::ToBoolean($folder.hidden))

    foreach($group in $folder.security.security)
    {
        $f.RoleAssignments += [RoleAssignment]::new($group.name, $group.roles.role)
    }

    foreach($dataSource in $folder.dataSources.dataSource)
    {
        $f.DataSources += [DataSource]::new($dataSource.name, $dataSource.connectionString, $dataSource.extension, $dataSource.credentialRetrieval, $dataSource.userName, $dataSource.password, [System.Convert]::ToBoolean($dataSource.hidden))
    }

    foreach($dataSet in $folder.dataSets.dataSet)
    {
        $f.DataSets += [DataSet]::new($dataSet.name, $dataSet.fileName, [System.Convert]::ToBoolean($dataSet.hidden))
    }

    foreach($report in $folder.reports.report)
    {
        $f.Reports += [Report]::new($report.name, $report.fileName, [System.Convert]::ToBoolean($report.hidden))
    }

    foreach($subFolder in $folder.folders.folder)
    {
        $f.Folders += GetXmlFolderItems -Folder $subFolder -Parent $f
    }

    return $f
}

class Folder
{
    [ValidateNotNullOrEmpty()][string]$Name
    [Folder]$Parent
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
        $this.Hidden = $false
    }

    Folder($Name, [Folder]$Parent, $Hidden)
    {
        $this.Name = $Name
        $this.Parent = $Parent
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
    [ValidateNotNullOrEmpty()][boolean]$Hidden

    Report([string]$Name, [string]$FileName)
    {
        $this.Name = $Name
        $this.FileName = $FileName
        $this.Hidden = $false
    }

    Report([string]$Name, [string]$FileName, [boolean]$Hidden)
    {
        $this.Name = $Name
        $this.FileName = $FileName
        $this.Hidden = $Hidden
    }
}

class DataSet
{
    [ValidateNotNullOrEmpty()][string]$Name
    [ValidateNotNullOrEmpty()][string]$FileName
    [ValidateNotNullOrEmpty()][boolean]$Hidden

    DataSet([string]$Name, [string]$FileName)
    {
        $this.Name = $Name
        $this.FileName = $FileName
        $this.Hidden = $false
    }

    DataSet([string]$Name, [string]$FileName, [boolean]$Hidden)
    {
        $this.Name = $Name
        $this.FileName = $FileName
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
    [ValidateNotNullOrEmpty()][boolean]$Hidden

    DataSource([string]$Name, [string]$ConnectionString, [string]$Extension, [string]$CredentialRetrieval, [string]$UserName, [string]$Password, [boolean]$Hidden)
    {
        $this.Name = $Name
        $this.ConnectionString = $ConnectionString
        $this.Extension = $Extension
        $this.CredentialRetrieval = $CredentialRetrieval
        $this.UserName = $UserName
        $this.Password = $Password
        $this.Hidden = $Hidden
    }

    DataSource([string]$Name, [string]$ConnectionString, [string]$Extension, [string]$CredentialRetrieval, [string]$UserName, [string]$Password)
    {
        $this.Name = $Name
        $this.ConnectionString = $ConnectionString
        $this.Extension = $Extension
        $this.CredentialRetrieval = $CredentialRetrieval
        $this.UserName = $UserName
        $this.Password = $Password
        $this.Hidden = $false
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
        [ValidateScript({Test-Path $_ -PathType 'Leaf'})][parameter(Mandatory = $true)][string]$RdlPath,    
        [string]$Path = "/",
        [parameter(Mandatory = $true)][string]$Name,
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
            [xml]$Definition = Get-Content -Path $RdlPath
            $NsMgr = New-XmlNamespaceManager $Definition d
            $rawDefinition = Get-Content -Encoding Byte -Path $RdlPath

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

            Write-Verbose "Creating report $Name"
            $warnings = $null
            
            $report = $Proxy.CreateCatalogItem("Report", $Name, $Path, $Overwrite, $rawDefinition, $properties, [ref]$warnings)

            if ($warnings)
            {
                $warnings.Message | Write-Warning
            }

            $DataSources = @()
            $dss = Get-SsrsItem -Proxy $Proxy -Type DataSource
            $nodes = $Definition.SelectNodes('d:Report/d:DataSources/d:DataSource/d:DataSourceReference/..', $NsMgr)

            foreach($node in $nodes)
            {
                $ds = $dss | Where-Object { $_.Name -eq $node.DataSourceReference } | Select-Object -First 1
                
                if ($ds)
                {
                    $Reference = New-Object -TypeName SSRS.ReportingService2010.DataSourceReference
                    $Reference.Reference = $ds.Path

                    $DataSource = New-Object -TypeName SSRS.ReportingService2010.DataSource
                    $DataSource.Item = $Reference
                    $DataSource.Name = $node.Name

                    $DataSources += $DataSource
                }
                else
                {
                    Write-Warning "The reference for datasource $($node.Name) can not be found."
                }
            }

            if ($DataSources)
            {  
                $Proxy.SetItemDataSources($report.Path, $DataSources)
            }

            $References = @()
            $dss = Get-SsrsItem -Proxy $Proxy -Type DataSet
            $nodes = $Definition.SelectNodes('d:Report/d:DataSets/d:DataSet/d:SharedDataSet/d:SharedDataSetReference/../..', $NsMgr)

            foreach($node in $nodes)
            {
                $ds = $dss | Where-Object { $_.Name -eq $node.SharedDataSet.SharedDataSetReference } | Select-Object -First 1

                if ($ds)
                {
                    $Reference = New-Object -TypeName SSRS.ReportingService2010.ItemReference
                    $Reference.Reference = $ds.Path
                    $Reference.Name = $node.Name
            
                    $References += $Reference
                }
                else
                {
                    Write-Warning "The reference for dataset $($node.Name) can not be found."
                }
            }

            if ($References)
            {
                $Proxy.SetItemReferences($report.Path, $References)
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