#this script searches for a tag with value of date and if hte date is today and the VM is shutdown the script will sen the VM to a pipeline with terraform for deletion 
#you need to provide value for hte following $organizationName $projectName $pipelineId refName $patToken


param(
    [Parameter(Mandatory=$true)]
    [string]$patToken
)
 
# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process
 
# Connect to Azure with system-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity).context
 
# Set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
 
# Define today's date in the format 'yyyy-MM-dd'
$todayDate = (Get-Date).ToString('yyyy-MM-dd')
 
# Hardcoded variables
$organizationName = "Your org name"
$projectName = "Your project name"
$pipelineId = "Your pipeline ID"
 
# Get all VMs in the subscription
$vms = Get-AzVM
 
foreach ($vm in $vms) {
    $resourceGroupName = $vm.ResourceGroupName
 
    # Check if the VM has the 'ScheduledDeletionDate' tag
    if ($vm.Tags.ContainsKey('ScheduledDeletionDate')) {
        $deletionDate = $vm.Tags['ScheduledDeletionDate']
       
        # If the tag value matches today's date, trigger the pipeline
        if ($deletionDate -eq $todayDate) {
            $vmName = $vm.Name
            $vmNameWithSuffix = "$vmName.tfstate"
 
            # Define the URL for the pipeline run
            $uri = "https://dev.azure.com/$organizationName/$projectName/_apis/pipelines/$pipelineId/runs?api-version=7.1-preview.1"
 
            # Define the headers
            $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            $headers.Add("Content-Type", "application/json")
            $headers.Add("Authorization", "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$patToken")))
 
            # Define the body for the pipeline run request
            $body = @"
{
  `"resources`": {
    `"repositories`": {
      `"self`": {
        `"refName`": `"refs/heads/master`"
      }
    }
  },
  `"variables`": {
    `"test`": {
      `"value`": `"$vmNameWithSuffix`"
    }
  }
}
"@
 
            # Trigger the pipeline run
            try {
                $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
                Write-Output "Pipeline triggered for VM: $vmName in Resource Group: $resourceGroupName"
                Write-Output $response
            } catch {
                Write-Error "Error triggering pipeline for VM ${vmName} in Resource Group ${resourceGroupName}: $_"
            }
        }
    }
}
 