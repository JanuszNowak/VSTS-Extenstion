
 function ConvertTo-IPv4MaskString {
  <#
  .SYNOPSIS
  Converts a number of bits (0-32) to an IPv4 network mask string (e.g., "255.255.255.0").

  .DESCRIPTION
  Converts a number of bits (0-32) to an IPv4 network mask string (e.g., "255.255.255.0").

  .PARAMETER MaskBits
  Specifies the number of bits in the mask.
  #>
  param(
    [parameter(Mandatory=$true)]
    [ValidateRange(0,32)]
    [Int] $MaskBits
  )
  $mask = ([Math]::Pow(2, $MaskBits) - 1) * [Math]::Pow(2, (32 - $MaskBits))
  $bytes = [BitConverter]::GetBytes([UInt32] $mask)
  (($bytes.Count - 1)..0 | ForEach-Object { [String] $bytes[$_] }) -join "."
}

    write-host "`n Starting sample.ps1"

    #Import local variables
    $resourceGroupName = Get-VstsInput -Name resourceGroupName -Require
    $resourceName = Get-VstsInput -Name resourceName -Require
    $ipListUrl = Get-VstsInput -Name ipListUrl -Require
    $operationType = Get-VstsInput -Name operationType -Require
    $variableValue = Get-VstsInput -Name variableValue -Require

write-host "resourceGroupName: $resourceGroupName"
write-host "resourceName: $resourceName"
write-host "ipListUrl: $ipListUrl"
write-host "operationType: $operationType"
#Import Azure helper module
Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_ -DisableNameChecking
Initialize-Azure

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
Trace-VstsEnteringInvocation $MyInvocation
try {
    $WebAppConfig = Get-AzureRMResource -ResourceName $resourceName -ResourceType Microsoft.Web/sites/config -ResourceGroupName $resourceGroupName -ApiVersion 2016-08-01
   
    write-host "ipSecurityRestrictions before change:"
    $WebAppConfig.Properties.ipSecurityRestrictions

    #$WebAppConfig.Properties.ipSecurityRestrictions = @([PSCustomObject] @{ ipAddress = '127.0.0.1' ; subnetMask = '255.0.0.0' })

    write-host "operationType: $operationType"

    
    $iplist =  @()

    if($operationType -eq "RemoveAll")
    {

    }
    ElseIf($operationType -eq "SetFromUrl")
    {    
        [xml]$doc = (New-Object System.Net.WebClient).DownloadString( $ipListUrl)

        foreach($node in $doc.SelectNodes("//*/IpRange"))
        {        
            $ip=$node.Subnet.split('/')[0]
            $mask=ConvertTo-IPv4MaskString $node.Subnet.split('/')[1] -OutVariable $mask
            $iplist+=[pscustomobject]@{ipAddress=$ip;subnetMask=$mask}            
        }
    }
    ElseIf($operationType -eq "SetFromVariable")
    {
        [xml]$doc=$variableValue
    
        foreach($node in $doc.SelectNodes("//*/IpRange"))
        {        
            $ip=$node.Subnet.split('/')[0]
            $mask=ConvertTo-IPv4MaskString $node.Subnet.split('/')[1] -OutVariable $mask
            $iplist+=[pscustomobject]@{ipAddress=$ip;subnetMask=$mask}            
        }
    }

    write-host "new ip list $iplist"
    
    $WebAppConfig.Properties.ipSecurityRestrictions =  $iplist
   
    Set-AzureRmResource -ResourceId $WebAppConfig.ResourceId -Properties $WebAppConfig.Properties -ApiVersion 2016-08-01 -Force
    
    
    $WebAppConfig = Get-AzureRMResource -ResourceName $resourceName -ResourceType Microsoft.Web/sites/config -ResourceGroupName $resourceGroupName -ApiVersion 2016-08-01
   
    write-host "ipSecurityRestrictions after change:"
    $WebAppConfig.Properties.ipSecurityRestrictions

} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
