#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.Synopsis
   Armazena numa variável as VMs que estão num host para uma eventual manutenção e depois as move de volta 
.DESCRIPTION
   Armazena numa variável as VMs que estão num host para uma eventual manutenção e depois as move de volta 
.EXAMPLE
   
.EXAMPLE
   Inserir posteriormente
.CREATEDBY
    Juliano Alves de Brito Ribeiro (find me at julianoalvesbr@live.com or https://github.com/julianoabr or https://youtube.com/@powershellchannel)
.VERSION INFO
    0.2
.VERSION NOTES
    
.VERY IMPORTANT
    “Todos os livros científicos passam por constantes atualizações. 
    Se a Bíblia, que por muitos é considerada obsoleta e irrelevante, 
    nunca precisou ser atualizada quanto ao seu conteúdo original, 
    o que podemos dizer dos livros científicos de nossa ciência?” 
.VERSION IMPROVEMENTS
    Improvements for Next Version
    * show the number of vms and clear host
    * disable anti affinity rules
    * put host in maintenance mode if drs is enabled

#>

Clear-Host

#VALIDATE MODULE
$moduleExists = Get-Module -Name Vmware.VimAutomation.Core

if ($moduleExists){
    
    Write-Host "VMware.VimAutomation.Core is already loaded." -ForegroundColor White -BackgroundColor DarkGreen
    
}#if validate module
else{
    
    Write-Host -NoNewline "VMware.VimAutomation.Core is not loaded." -ForegroundColor DarkBlue -BackgroundColor White
    Write-Host -NoNewline "I need this module to work" -ForegroundColor DarkCyan -BackgroundColor White
    
    Import-Module -Name Vmware.VimAutomation.Core -WarningAction SilentlyContinue -ErrorAction Stop -Verbose
    
}#else validate module


function Pause-PSScript
{

   Read-Host 'Press [ENTER] to continue' | Out-Null

}


function DisplayStart-Sleep ($totalSeconds)
{

$currentSecond = $totalSeconds

while ($currentSecond -gt 0) {
    
    Write-Host "Script is running. Wait more $currentSecond seconds..." -ForegroundColor White -BackgroundColor DarkGreen
    
    Start-Sleep -Seconds 1 # Pause for 1 second
    
    $currentSecond--
    }

Write-Host "Countdown complete! Let's continue..." -ForegroundColor White -BackgroundColor DarkBlue

}#end of Function Display Start-Sleep


#VALIDATE IF OPTION IS NUMERIC
function isNumeric ($x) {
    $x2 = 0
    $isNum = [System.Int32]::TryParse($x, [ref]$x2)
    return $isNum
} #end function is Numeric

#FUNCTION CONNECT TO VCENTER
function Connect-ToVcenterServer
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateSet('Menu','Automatic')]
        $methodToConnect = 'Menu',
               
        [Parameter(Mandatory=$true,
                   Position=1)]
        [System.String[]]$VCServerList,
                
        [Parameter(Mandatory=$false,
                   Position=2)]
        [ValidateSet('subdomain.domain','subdomain2.domain','subdomain3.domain','subdomain4.domain')]
        [System.String]$vCentersuffix,

        [Parameter(Mandatory=$false,
                   Position=3)]
        [ValidateSet('80','443')]
        [System.String]$port = '443'
    )

#VALIDATE IF YOU ARE CONNECTED TO ANY VCENTER 
if ((Get-Datacenter) -eq $null)
    {
        Write-Host "You are not connected to any vCenter Server" -ForegroundColor White -BackgroundColor DarkMagenta
    }#enf of IF
else{
        
        $previousvCenterConnected = $global:DefaultVIServer.Name

        Write-Host "You're connected to vCenter:$previousvCenterConnected" -ForegroundColor White -BackgroundColor Green
        
        Write-Host -NoNewline "I will disconnect you before continuing." -ForegroundColor White -BackgroundColor Red
            
        Disconnect-VIServer -Server * -Confirm:$false -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

}#end of else validate if you are connected. 
    

    if ($methodToConnect -eq 'Automatic'){
                
        $Script:workingServer = $vCenterList + '.' + $vCentersuffix
        
        $vcInfo = Connect-VIServer -Server $Script:WorkingServer -Port $Port -WarningAction Continue -ErrorAction Stop
    
    }#end of If Method to Connect
    else{
        
        $workingLocationNum = ""
        
        $tmpWorkingLocationNum = ""
        
        $Script:WorkingServer = ""
        
        $i = 0

        #MENU SELECT VCENTER
        foreach ($vcServer in $vcServerList){
	   
                $vcServerValue = $vcServer
	    
                Write-Output "            [$i].- $vcServerValue ";	
	            $i++	
                }#end foreach	
                Write-Output "            [$i].- Exit this script ";

                while(!(isNumeric($tmpWorkingLocationNum)) ){
	                $tmpWorkingLocationNum = Read-Host "Type vCenter Number that you want to connect to"
                }#end of while

                    $workingLocationNum = ($tmpWorkingLocationNum / 1)

                if(($WorkingLocationNum -ge 0) -and ($WorkingLocationNum -le ($i-1))  ){
	                $Script:WorkingServer = $vcServerList[$WorkingLocationNum]
                }
                else{
            
                    Write-Host "Exit selected, or Invalid choice number. End of Script " -ForegroundColor Red -BackgroundColor White
            
                    Exit;
                }#end of else

        #Connect to Vcenter
        $Script:vcInfo = Connect-VIServer -Server $Script:WorkingServer -Port $port -WarningAction Continue -ErrorAction Continue
  
    
    }#end of Else Method to Connect

}#End of Function Connect to Vcenter

function Generate-ClusterList{

Write-Host "SELECT THE VCENTER CLUSTER THAT YOU WANT TO WORK" -ForegroundColor DarkBlue -BackgroundColor White

Write-Output "`n"

#CREATE CLUSTER LIST
    $vCClusterList = @()
        
    $vCClusterList = (VMware.VimAutomation.Core\Get-Cluster | Select-Object -ExpandProperty Name| Sort-Object)

    $tmpWorkingClusterNum = ""
        
    $Script:WorkingCluster = ""
        
    $counter = 0
        
    #CREATE CLUSTER MENU LIST
    foreach ($vCCluster in $vCClusterList){
	   
        $vCClusterValue = $vCCluster
	    
        Write-Output "            [$counter].- $vCClusterValue ";	
	    
        $counter++	
        
     }#end foreach	
        
     Write-Output "            [$counter].- Exit this script ";

     while(!(isNumeric($tmpWorkingClusterNum)) ){
	    
        $tmpWorkingClusterNum = Read-Host "Type the Vcenter Cluster Number that you select a Host to work"
        
     }#end of while

     $workingClusterNum = ($tmpWorkingClusterNum / 1)

     if(($workingClusterNum -ge 0) -and ($workingClusterNum -le ($counter-1))  ){
	        
        $Script:WorkingCluster = $vCClusterList[$workingClusterNum]
      
      }
      else{
            
        Write-Host "Exit selected, or Invalid choice number. End of Script " -ForegroundColor Red -BackgroundColor White
            
        Exit;
      }#end of else
    
}#end of Function generate Cluster List

function Generate-HostList{
 [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [System.String]$privWorkingCluster
      
    )

Write-Host "SELECT THE HOST THAT YOU WANT TO WORK" -ForegroundColor DarkBlue -BackgroundColor White

Write-Output "`n"

#CREATE CLUSTER LIST
        $esxiHostList = @()
        
        $esxiHostList = (VMware.VimAutomation.Core\Get-Cluster -Name $privWorkingCluster | Get-VMHost | Select-Object -ExpandProperty Name | Sort-Object)

        $tmpWorkingHostNum = ""
        
        $Script:WorkingHost = ""
        
        $esxicounter = 0
        
        #CREATE CLUSTER MENU LIST
        foreach ($esxiHost in $esxiHostList){
	   
            $esxiHostValue = $esxiHost
	    
        Write-Output "            [$esxicounter].- $esxiHostValue ";	
	    
        $esxicounter++	
        
        }#end foreach	
        
        Write-Output "            [$esxicounter].- Exit this script ";

        while(!(isNumeric($tmpWorkingHostNum)) ){
	    
            $tmpWorkingHostNum = Read-Host "Type the Host Number that you want to move the VMs"
        
        }#end of while

            $workingHostNum = ($tmpWorkingHostNum / 1)

        if(($workingHostNum -ge 0) -and ($workingHostNum -le ($esxicounter-1))  ){
	        
            $Script:WorkingHost = $esxiHostList[$workingHostNum]
        }
        else{
            
            Write-Host "Exit selected, or Invalid choice number. End of Script " -ForegroundColor Red -BackgroundColor White
            
            Exit;
        }#end of else
        
        Write-Host "You chooose: $script:workingHost to work" -ForegroundColor White -BackgroundColor DarkBlue

}#end of Function generate Cluster List

##############################################################
#MAIN SCRIPT

#DEFINE VCENTER LIST
$vcServerList = @();

#ADD OR REMOVE VCs        
$tmpVCServerList = ('server1','server2','server3','server4','server5') | Sort-Object

#SELECT TYPE OF CONNECTIONS
Do
{
 
 $tmpMethodToConnect = Read-Host -Prompt "Type (menu) if you want to choose vCenter to Connect from a Menu. 
 Type (automatic) if you want to Type the vCenter Name to Connect"

    if ($tmpMethodToConnect -notmatch "^(?:menu\b|automatic\b)"){
    
        Write-Host "You typed an invalid word. Type only (menu) or (automatic)" -ForegroundColor White -BackgroundColor Red
    
    }
    else{
    
        Write-Host "You typed a valid word. I will continue =D" -ForegroundColor White -BackgroundColor DarkBlue
    
    }
    
}While ($tmpMethodToConnect -notmatch "^(?:menu\b|automatic\b)")#end of while choose method to connect


if ($tmpMethodToConnect -match "^\bautomatic\b$"){

    [System.String]$tmpVC = Read-Host "Write the name of vCenter that you want to connect"

    $tmpDNSSuffix = ""

    [System.String]$tmpDNSSuffix = Read-Host "If necessary type DNS Suffix of vCenter that you want to connect"

    if ($tmpDNSSuffix -like $null){
        
        Connect-ToVcenterServer -VCServerList $tmpVC -methodToConnect Automatic -port 443 -Verbose
              
            
    }#end of IF
    else{
    
        Connect-ToVcenterServer -VCServerList $tmpVC -methodToConnect Automatic -vCentersuffix $tmpDNSSuffix -port 443 -Verbose
    
    }#end of Else
    

}#end of IF
else{
    
    Connect-ToVcenterServer -VCServerList $tmpVCServerList -methodToConnect Menu -port 443 -Verbose
    
}#end of Else

#call function to choose cluster
Generate-ClusterList

#call function to choose Host
Generate-HostList -privWorkingCluster $script:WorkingCluster


$hostObj = Get-VMHost -Name $Script:workingHost

$vmSourceList = @()

$vmSourceList = $hostObj | Get-VM | Where-Object -FilterScript {$PSItem.Name -notlike 'VCLS*'} | Select-Object -ExpandProperty Name | Sort-Object

[System.Int32]$countVM = $vmSourceList.Count

Write-Host "I found: $countVM VMS in Host $script:WorkingHost" -ForegroundColor White -BackgroundColor DarkBlue

Write-Host "I found the following VMs in Host $script:WorkingHost" -ForegroundColor White -BackgroundColor DarkBlue

$vmSourceList

#FOR TEST PURPOSE ONLY
#$sourceVM = 'test-vm'

Pause-PSScript

$counterVM = 0

foreach ($sourceVM in $vmSourceList)
{
    
    $counterVM++

    $vmObj = Get-VM -Name $sourceVM -Verbose

    $hostDestinationObj = Get-VMHost -Name $script:WorkingHost -Verbose

    Write-Progress -Activity "vMotion Progress" -PercentComplete (($counterVM*100)/$countVM) -Status "$(([math]::Round((($counterVM)/$countVM * 100),0))) %"

    Move-VM -VM $vmObj -Destination $hostDestinationObj -Confirm:$false -RunAsync -Verbose

        
}#end of foreach
