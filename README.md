# Windows Machine File Copy Task (WinRM)
### Overview
The task is used to copy application files and other artifacts that are required to install the application on Windows Machines like PowerShell scripts, PowerShell-DSC modules etc. The task provides the ability to copy files to Windows Machines. The tasks uses WinRM for the data transfer.


> This task defers from the original task that ships with VSTS/TFS by the fact that this implementation uses WinRM for the file transfer instead of robocopy on which the original task is based on.
In certain situations, due to the network restrictions, mounting the drive and using the necessary protocols is not possible. Thus, for such scenarios, where WinRM is enabled, this task will solve the issue.

### Requirements

The only requirement is PowerShell V5 installed both on the build server and on the machine on which you are trying to copy the files to.

### The different parameters of the task are explained below:

*	**Source**: The source of the files. As described above using pre-defined system variables like $(Build.Repository.LocalPath) make it easy to specify the location of the build on the Build Automation Agent machine. The variables resolve to the working folder on the agent machine, when the task is run on it. Wild cards like **\\*.zip are not supported. Probably you are going to copy something from your artifacts folder that was generated in previous steps of your build/release, at example '$(System.ArtifactsDirectory)\\Something'.
* **Machines**: Specify comma separated list of machine FQDNs/ip addresses along with port(optional). For example dbserver.fabrikam.com, dbserver_int.fabrikam.com:5988,192.168.34:5933.
* **Admin Login**: Domain/Local administrator of the target host. Format: &lt;Domain or hostname&gt;\\&lt; Admin User&gt;.  
* **Password**:  Password for the admin login. It can accept variable defined in Build/Release definitions as '$(passwordVariable)'. You may mark variable type as 'secret' to secure it.  
*	**Destination Folder**: The folder in the Windows machines where the files will be copied to. An example of the destination folder is c:\\FabrikamFibre\\Web.
*	**Use SSL**: In case you are using secure WinRM, HTTPS for transport, this is the setting you will need to flag.
*	**Clean Target**: Checking this option will clean the destination folder prior to copying the files to it.
*	**Copy Files in Parallel**: Checking this option will copy files to all the target machines in parallel, which can speed up the copying process.


## Contributing

Feel free to notify any issue in the issues section of this GitHub repository.
In order to build this task, you will need Node.js and gulp installed. Once cloned the repository, just run 'gulp package' and in the newly created folder called dist you will find a new version of the extension.