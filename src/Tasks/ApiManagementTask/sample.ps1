write-host "`n Starting sample.ps1"


#Import local variables
$apiManagementRg = Get-VstsInput -Name apiManagementRg -Require #RG Name
$apiManagementName = Get-VstsInput -Name apiManagementName -Require #APIM Name
$apiUrl = Get-VstsInput -Name apiUrl -Require #Url of swagger 
$specificationFormat = Get-VstsInput -Name specificationFormat -Require
$apiUrlSuffix = Get-VstsInput -Name apiUrlSuffix -Require


write-host "apiManagementRg: $apiManagementRg"
write-host "apiManagementName: $apiManagementName"
write-host "apiUrl: $apiUrl"
write-host "specificationFormat: $specificationFormat"
write-host "apiUrlSuffix: $apiUrlSuffix"


#Import Azure helper module
Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_ -DisableNameChecking
Initialize-Azure

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {

    #check if APIM exist 
    $apim=Get-AzureRmApiManagement -ResourceGroupName $apiManagementRg
    if(!$apim)
    {
        Write-Warning "Api Management/Resource Group do not exsit"
        break
    }


    $ApiMgmtContext = New-AzureRmApiManagementContext `
        -ResourceGroupName "$apiManagementRg"`
        -ServiceName "$apiManagementName"`
        -ErrorAction Stop -Verbose
    
    $ApiID = (Get-AzureRmApiManagementApi -Context $ApiMgmtContext| Where-Object {$_.path -eq $apiUrlSuffix}).ApiId
    $APIName = (Get-AzureRmApiManagementApi -Context $ApiMgmtContext| Where-Object {$_.path -eq $apiUrlSuffix}).Name   
    
    if ($ApiID -eq $null) 
    {
        try {            
            write-host "Importing API"

            #$newapi = Import-AzureRmApiManagementApi -Context $ApiMgmtContext -SpecificationFormat $Specificationformat -SpecificationUrl $apiUrl -Path $apiUrlSuffix
            $newapi = Import-AzureRmApiManagementApi -Context $ApiMgmtContext -SpecificationFormat $Specificationformat -SpecificationUrl $apiUrl -Path $apiUrlSuffix -ErrorAction Stop -Verbose

            write-host "Imported API"
        }
        catch {
            throw $_.Exception.Message
            Break
        }
        write-host "New API Imported"
    }
    else {
            try {                
                write-host "`n Updating " $APIName
                $update = Import-AzureRmApiManagementApi -Context $ApiMgmtContext `
                    -SpecificationFormat  $Specificationformat `
                    -Specificationurl $apiUrl `
                    -Path  $apiUrlSuffix `
                    -ApiId $ApiID -ErrorAction Stop  -Verbose                    

                    write-host "`n Updated " $APIName
            }
            catch {
                throw $_.Exception.Message
                Break
            }

    }
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
