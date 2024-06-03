# This is an azure PowerShell automation created to shutdown VMs with grace period of 14 days, also it will create a csv file and send it to a blob storage, then will send this VMs for detention to a pipeline.
The Vms are supposed to be deployed with terraform and the state file must be located in a blob storage in Azure the state file must be as follows VMname.tfstate
This automation can be used as runbook, you can use the following method for authentication [Link](https://learn.microsoft.com/en-us/azure/automation/enable-managed-identity-for-automation#authenticate-access-with-system-assigned-managed-identity)



## There are tree scripts avaliable 

### decom_with_checks_and_file_output-backup_stop.ps1
This script will search for a specific tag and if the tag is configured on the VM, it will be stopped and the backup disabled. The VM will receive new tag with the date 14 days from now so it can be deleted after that grace period
For this script you need to provide the following values

$tagName

$tagValue

$storageAccountName 

$storageAccountKey 

$containerName 

$vaultName


### decom_with_checks_and_file_output-backup_stop_delete points.ps1
This script will search for a specific tag and if the tag is configured on the VM, it will be stopped and the backup disabled, also all recovery points will be deleted. The VM will receive new tag with the date 14 days from now so it can be deleted after that grace period
For this script you need to provide the following values

$tagName

$tagValue

$storageAccountName 

$storageAccountKey 

$containerName 


### find_system_by_tag_and_status_and_pass_ it_to_pipeline.ps1
this script searches for a tag with value of date and if the date is today and the VM is shutdown the script will sent the VM to a pipeline with terraform for deletion
you need to provide value for the following

$organizationName 

$projectName 

$pipelineId 

refName 

$patToken


![GitHub Logo](/decommission.png)
