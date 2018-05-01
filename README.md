# Deploy SSRS Task
### Overview
This extension will add a Build/Release task in your TFS/VSTS instance that will allow you to deploy Microsoft SQL Server Reporting Services reports and datasets.
Aside of deploying reports and datasets it will also enable you to supply a configuration in form of an xml or json file in which you will be able to specify the folders in which the reports are going to be deployed. Optionally, in the configuration file, you will be able to specify security that needs to be applied on the deployed objects. Objects that you can manage and deploy are folders, data sources, datasets and reports. 

### Requirements

For this task to run you will need at least PowerShell v5 installed on your agent server.

### The different parameters of the task are explained below:

* **ISPAC file(s)**: Specify the location of your Integration Service packages (ISPAC files). Wildcards can be used. For example, `**\\*.ispac` for all ispac files in all sub folders."
* **Server Name**: Provide the SQL Server name like, machinename\\FabriakmSQL,1433 or localhost or .\\SQL2012R2. Specifying localhost will connect to the Default SQL Server instance on the machine.
* **Authentication**: Select the authentication mode for connecting to the SQL Server. In Windows authentication mode, build service account, is used to connect to the SQL Server. In SQL Server Authentication mode, the SQL login and Password have to be provided in the parameters below.
* **SQL User name**:  Provide the SQL login to connect to the SQL Server. The option is only available if SQL Server Authentication mode has been selected.  
* **SQL Password**: Provide the Password of the SQL login. The option is only available if SQL Server Authentication mode has been selected.
* **Shared Catalog**: If not selected, prior the deployment of your packages, the catalog will be dropped. If marked as shared (e.g. in case it is used by other applications), the catalog will not be dropped and extra checks will be made during the deployment. In case you marked your catalog as shared but no catalog is present on the server, a new catalog will be created with a catalog password equal to 'P@ssw0rd'
* **Catalog Password**: Catalog password protects the database master key that is used for encrypting the catalog data. Save the password in a secure location. It is recommended that you also back up the database master key. This option is only available if Shared Catalog is not set.
* **SSIS folder Name**: Folder name in the SSIS Package Store.
* **Environment configuration file**: Path to the configuration file. Wildcards are not allowed.

### Example of the configuration file

Following an example of the configuration file.

```
<?xml version="1.0" encoding="UTF-8" ?>
<environments>
	<environment>
		<name>MyEnv</name>
		<description>My Environments</description>
		<ReferenceOnProjects>
			<Project Name="BusinessDataVault" />
			<Project Name="Configuration" />
		</ReferenceOnProjects>
		<variables>
			<variable>
				<name>CLIENTToDropbox</name>
				<type>Boolean</type>
				<value>1</value>
				<sensitive>false</sensitive>
				<description></description>
			</variable>
			<variable>
				<name>InitialCatalog</name>
				<type>String</type>
				<value>DV</value>
				<sensitive>false</sensitive>
				<description>Initial Catalog</description>
			</variable>
			<variable>
				<name>MaxFilesToLoad</name>
				<type>Int32</type>
				<value>5</value>
				<sensitive>false</sensitive>
				<description>Max Files To Load by dispatcher </description>
			</variable>
		</variables>
	</environment>
</environments>
```

As you can see, you need to define an environment element which contains name and description. In ReferenceOnProjects element you will need to list all of the projects on which the current environment needs to be reference to. Under variables you need to enlist all of the variables that you would like to be added to your environment. Variable elements are following:
* name - The name of the variable
* type - The type of the variable. A string matching any of the enum elements in System.TypeCode
* value - The value of the variable
* sensitive - true to the variable that is sensitive; otherwise, false. Sensitive values are encrypted in the catalog and appear as a NULL value when viewed with Transact-SQL or SQL Server Management Studio.
* description - For maintainability, the description of the variable.

The same values can be passed in also as a json file with the following structure:

```
[
  {
    "name": "MyEnv",
    "description": "My Environments",
    "referenceOnProjects": [
      {
        "name": "BusinessDataVault"
      },
      {
        "name": "Configuration"
      }
    ],
    "variables": [
      {
        "name": "CLIENTToDropbox",
        "type": "Boolean",
        "value": "1",
        "sensitive": "false",
        "description": ""
      },
      {
        "name": "MaxFilesToLoad",
        "type": "Int32",
        "value": "31",
        "sensitive": "false",
        "description": "Max Files To Load by dispatcher"
      }
    ]
  }
]
```

## Contributing

Feel free to notify any issue in the issues section of this GitHub repository. In order to build this task, you will need Node.js and gulp installed. Once cloned the repository, just run 'npm install' then 'gulp package' and in the newly created folder called _packages you will find a new version of the extension.