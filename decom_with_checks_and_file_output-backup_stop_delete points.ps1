#This is a script that will check for a specific tag and will shutdown the system with that tag and will add a tag with the date +14 day
#so the system ca be deleted, also the script will create a file in a provided by you storage account with the vms that will be shutdown
#and will stop and delete all backups
# you need to provide values for $tagName $tagValue $storageAccountName $storageAccountKey $containerName
 
 
# Login to Azure (if not already logged in)
Connect-AzAccount
 
# Define the tag name and value to be used
$tagName = "Set tag name"
$tagValue = "Set tag value"
 
# Define Storage Account
$storageAccountName = "Provide storage account name"
$storageAccountKey = "Provide storage account key"
$containerName = "Provide container name"
 
# Get all VMs with the specified tag
$vmsWithTag = Get-AzVM | Where-Object { $_.Tags[$tagName] -eq $tagValue }
 
# Prepare the array to hold data for the CSV
$vmData = @()
 
# Specify a path in the Cloud Shell home directory
$fileName = "$(Get-Date -Format 'yyyyMMdd')_VMDeletionSchedule.csv"
$filePath = "$HOME/$fileName"
 
# Function to delete backup for a VM
function Delete-BackupForVM {
    param (
        [string]$vmName,
        [string]$vaultName
    )
 
    $vault = Get-AzRecoveryServicesVault -Name $vaultName
    Set-AzRecoveryServicesVaultContext -Vault $vault
 
    $container = Get-AzRecoveryServicesBackupContainer -ContainerType "AzureVM" -FriendlyName $vmName
    if ($container -ne $null) {
        $backupItem = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType "AzureVM"
        if ($backupItem -ne $null) {
            Disable-AzRecoveryServicesBackupProtection -Item $backupItem -RemoveRecoveryPoints:$true -Force
            Write-Output "Backup deleted for VM: $vmName"
        } else {
            Write-Output "No backup item found for VM: $vmName"
        }
    } else {
        Write-Output "No backup container found for VM: $vmName"
    }
}
 
# Check all VMs
foreach ($vm in $vmsWithTag) {
    $vmName = $vm.Name
    $resourceGroupName = $vm.ResourceGroupName
    $vmStatus = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Status
    $alreadyTaggedAndStopped = $vmStatus.Statuses[1].Code -eq "PowerState/deallocated" -and $vm.Tags.ContainsKey("ScheduledDeletionDate")
 
    if ($alreadyTaggedAndStopped) {
        Write-Output "Skipping VM: $vmName as it is already stopped and tagged for deletion."
    } else {
        Write-Output "Processing VM: $vmName in Resource Group: $resourceGroupName"
 
        # Stop the VM
        Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force -AsJob
       
        # Find the Recovery Services Vault name associated with the VM
        $vault = Get-AzRecoveryServicesVault | Where-Object {
            Set-AzRecoveryServicesVaultContext -Vault $_
            $container = Get-AzRecoveryServicesBackupContainer -ContainerType "AzureVM" -FriendlyName $vmName -ErrorAction SilentlyContinue
            return $container -ne $null
        }
 
        if ($vault -ne $null) {
            $vaultName = $vault.Name
            # Delete the backup for the VM(calling the function)
            Delete-BackupForVM -vmName $vmName -vaultName $vaultName
        } else {
            Write-Output "No associated Recovery Services Vault found for VM: $vmName"
        }
 
        # Add deletion tag
        $deletionDate = (Get-Date).AddDays(14).ToString('yyyy-MM-dd')
        $newTags = @{}
        if ($vm.Tags) {
            $vm.Tags.GetEnumerator() | ForEach-Object { $newTags[$_.Key] = $_.Value }
        }
        $newTags["ScheduledDeletionDate"] = $deletionDate
        Set-AzResource -ResourceId $vm.Id -Tag $newTags -Force
 
        # Add to CSV data
        $vmData += [PSCustomObject]@{
            VMName = $vmName
            ScheduledDeletionDate = $deletionDate
        }
    }
}
 
# Create the CSV file
$vmData | Export-Csv -Path $filePath -NoTypeInformation
 
# Validate that storage parameters are proper
if (-not [String]::IsNullOrWhiteSpace($storageAccountName) -and -not [String]::IsNullOrWhiteSpace($storageAccountKey) -and -not [String]::IsNullOrWhiteSpace($containerName)) {
    $context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
    Set-AzStorageBlobContent -File $filePath -Container $containerName -Blob $fileName -Context $context
    Write-Output "File uploaded to Blob Storage: $fileName"
} else {
    Write-Output "Storage account details are not correctly specified."
}
 


