# Deploy SSRS Task

## Overview

This extension will add a Build/Release task in your TFS/VSTS instance that will allow you to deploy Microsoft SQL Server Reporting Services reports, datasources and datasets.
Aside of deploying reports, datasources and datasets it will also enable you to supply a configuration in form of xml or json file where you are going to specify folders structure and the reports that are going to be deployed in them. Optionally, in the configuration file, you will be able to specify security that needs to be applied on the deployed objects. Objects that you can manage and deploy are folders, data sources, datasets and reports.

## Requirements

For this task to run you will need at least PowerShell v5 installed on your agent server.

## Parameters

Different parameters of the task are explained below:

* **ReportService2010 endpoint URL**: The Report Server Web service ReportService2010 endpoint URL. E.g. `http://your.server/ReportServer/ReportService2010.asmx?wsdl`
* **Authentication**: Select the authentication mode for connecting to the SQL Server. In Windows authentication mode, the administrator's account, as specified in the Machines section, is used to connect to the SQL Server. In SQL Server Authentication mode, the SQL login and Password have to be provided in the parameters below.
* **Username**:  Provide the SQL login to connect to the SQL Server. The option is only available if SQL Server Authentication mode has been selected.
* **Password**: Provide the Password of the SQL login. The option is only available if SQL Server Authentication mode has been selected.
* **Report Files Path**: Path of the folder containing RDL and/or RSD files or on a UNC path like, `\\BudgetIT\Web\Deploy\`. The UNC path should be accessible to the machine's administrator account. Environment variables are also supported, like `$env:windir`, `$env:systemroot`, `$env:windir\FabrikamFibre\DB`. Wildcards can be used. For example, `**/*.rdl` for RDL files present in all sub folders.
* **SSRS configuration file**: Location of the XML or JSON configuration file.
* **SSIS folder Name**: Folder name in the SSIS Package Store.
* **Reference DataSources**: If selected the DataSources in the configuration file will be referenced in the Reports, by matching the DataSource DataSourceReference value.
* **Reference DataSets**: If selected the DataSets in the configuration file will be referenced in the Reports, by matching the DataSets SharedDataSetReference value.
* **Overwrite existing objects**: If selected overwrites objects in the same path that already do exists.

## Example of the configuration file

Considering that there is no official way to specify the path where a report should be deployed, a custom configuration file is provided to the task to indicate the right location.
Aside of the path itself, you can specify the permissions for both folders that we previously indicated as for the report and datasets themselves.

Folders and the inside objects are listed in the configuration file as hierarchical tree structure.

Folders may be cleaned up to remove old or renamed reports during the deployment by specifying the CleanExistingItems configuration property on the folder configuration. 
Note: The CleanExistingItems config property will only delete files when cleaning a folder and will preserve any existing subfolders under the current directory.

Following an example of the configuration file.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Folder xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
  xmlns:xsd="http://www.w3.org/2001/XMLSchema" Name="Root">
  <Folders>
    <Folder Name="Folder">
      <Folders>
        <Folder Name="Datasources" Hidden="true">
          <DataSources>
            <DataSource ConnectionString="Data Source={{Server}}\{{Instance}};Initial Catalog=MyDB" Name="MyDB" Extension="SQL" CredentialRetrieval="Integrated" />
            <DataSource ConnectionString="Data Source={{Server}};Initial Catalog=MetaData" Name="MetaData" Extension="SQL" CredentialRetrieval="Store" UserName="user" Password="password" WindowsCredentials="True" />
          </DataSources>
        </Folder>
        <Folder Name="Admin Reports" Hidden="true" CleanExistingItems="true">
          <Reports>
            <Report Name="Error Report" Hidden="true" FileName="Error Report.rdl" />
            <Report Name="Error Report for Export" Hidden="true" FileName="Error Report for Export.rdl" />
          </Reports>
          <Security>
            <Security Name="Administrator">
              <Roles>
                <Role>Browser</Role>
                <Role>Content Manager</Role>
              </Roles>
            </Security>
          </Security>
        </Folder>
        <Folder Name="User Reports">
          <Reports>
            <Report Name="Users report" Hidden="false" FileName="UserReport.rdl" />
          </Reports>
          <Folders>
            <Reports>
              <Report Name="Other report" Hidden="false" FileName="OtherReport.rdl" />
            </Reports>
          </Folders>
        </Folder>
      </Folders>
      <Security>
        <Security Name="Users">
          <Roles>
            <Role>Browser</Role>
          </Roles>
        </Security>
        <Security Name="Administrator">
          <Roles>
            <Role>Browser</Role>
            <Role>Content Manager</Role>
          </Roles>
        </Security>
      </Security>
    </Folder>
  </Folders>
</Folder>
```

```json
{
    "Name": "Root",
    "Folders": [
        {
            "Name": "Folder",
            "Folders": [
                {
                    "Name": "Datasources",
                    "Hidden": true,
                    "DataSources": [
                        {
                            "ConnectionString": "Data Source={{Server}}\\{{Instance}};Initial Catalog=MyDB",
                            "Name": "MyDB",
                            "Extension": "SQL",
                            "CredentialRetrieval": "Integrated"
                        },
                        {
                            "ConnectionString": "Data Source={{Server}};Initial Catalog=MetaData",
                            "Name": "MetaData",
                            "Extension": "SQL",
                            "CredentialRetrieval": "Store",
                            "UserName": "user",
                            "Password": "password",
                            "WindowsCredentials": "True"
                        }
                    ]
                },
                {
                    "Name": "Admin Reports",
                    "Hidden": true,
                    "CleanExistingItems": true,
                    "Reports": [
                        {
                            "Name": "Error Report",
                            "Hidden": true,
                            "FileName": "Error Report.rdl"
                        },
                        {
                            "Name": "Error Report for Export",
                            "Hidden": true,
                            "FileName": "Error Report for Export.rdl"
                        }
                    ],
                    "Security": [
                        {
                            "Name": "Administrator",
                            "Roles": [
                                "Browser",
                                "Content Manager"
                            ]
                        }
                    ]
                },
                {
                    "Name": "User Reports",
                    "Reports": [
                        {
                            "Name": "Users report",
                            "Hidden": false,
                            "FileName": "UserReport.rdl"
                        }
                    ],
                    "Folders": [
                        {
                            "Name": "Reports",
                            "Hidden": false,
                            "Reports": [
                                {
                                    "Name": "Other report",
                                    "Hidden": false,
                                    "FileName": "OtherReport.rdl"
                                }
                            ]
                        }
                    ]
                }
            ]
        }
    ],
    "Security": [
        {
            "Name": "Users",
            "Roles": [
                "Browser"
            ]
        },
        {
            "Name": "Administrator",
            "Roles": [
                "Browser",
                "Content Manager"
            ]
        }
    ]
}
```

Values that you see in double curly braces are placeholders that are going to be substituted in the release just before the deployment.

Following is an example of how will this configuration file translate in SSRS.

![Example](images/ssrs-deployed.png)

### More information about the configuration file and various options

Datasources are to be specified in a configuration file and they are not importable as .rds files. This is so that they can easily be manipulated on per environment basis.
Not all of the authentication types are implemented for datasources. Prompt credentials are not supported.

The same configuration can also be expressed as a json file with the equivalent structure.

## Release notes

* 3.1.9 - Task version now in the release notes. Fixing a bug ImpersonateUserSpecified. [#55](https://github.com/mmajcica/DeploySsrs/issues/55)
* 1.20.227.2 - Wrong property used for getting SharedDataSetReference name bug fixed. [#38](https://github.com/mmajcica/DeploySsrs/issues/38)
* 1.0.7 - Add support for cleaning folder contents during deploy. [#37](https://github.com/mmajcica/DeploySsrs/issues/37)
* 1.0.6 - Applying rights on report level bug fix. [#32](https://github.com/mmajcica/DeploySsrs/issues/32)
* 1.0.5 - Fixed issues with parsing certain JSON configuration. [#25](https://github.com/mmajcica/DeploySsrs/issues/25)
* 1.0.4 - Fixed an issue with loading the configuration file and Unicode. [#15](https://github.com/mmajcica/DeploySsrs/issues/15)
* 1.0.3 - Fixed an issue with Groups and Roles security. [#11](https://github.com/mmajcica/DeploySsrs/issues/11)
* 1.0.2 - Fixed an issue with Dataset references. [PR1](https://github.com/mmajcica/DeploySsrs/pull/1)
* 1.0.1 - Initial release

## Contributing

Feel free to notify any issue in the issues section of this GitHub repository.

[![Build Status](https://dev.azure.com/mummy/Azure%20DevOps%20Extensions/_apis/build/status/mmajcica.DeploySsrs?branchName=master)](https://dev.azure.com/mummy/Azure%20DevOps%20Extensions/_build/latest?definitionId=44&branchName=master)
