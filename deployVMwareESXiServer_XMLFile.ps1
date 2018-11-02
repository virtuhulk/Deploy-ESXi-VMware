#############################################################################################################################################################################################################################
#Version : 1.1																																				  																 
#Author : J. DUCOMMUN																																	       
#Date : 31/10/2018																																	           
#   Configure for each ESXi :																									 			  				   
#    - Configure HostName																																	   	
#    - Configure NtpServer, restart NTP Service, Enable auto start																										 			  				   
#    - Configure DNS Servers, search domain and Domain DNS																							          		           
#    - Configure vswitch0 with two nic card
#    - Configure Managment Network with One vmnic active and the other one passive																													                   
#    - Deconfigure VMotion on Managment Network																							               
#    - Create VMkernel for VMotion	
#    - Configure VMotion		
#    		- IP
#    		- Netmask
#    		- vlan
#    - Configure VMotion on VMotion vmkernel
#    - Configure VMotion with One vmnic active and the other one passive
#    - Delete the default VM Network
#    - Create vSwitch and VM Network
#    - Enable SSH
#    - Start SSH Service when host startup
#    - Disable SSH Shell alert		
#
#
#If protocol iSCSI used :
#    - Create new vswith for iscsi with 2 vmnic card
#    - Configure Jumbo Frame MTU 9000 on vswitch
#    - Configure ISCSI :
#    		- Create VMkernel for ISCSI1, configure IP, MTU 9000, vlan
#    		- Create VMkernel for ISCSI2, configure IP, MTU 9000, vlan
#    		- Configure VMnic card, one for ISCSI1 and the other one for ISCSI2																				       
#    - Create ISCSI Software Adapter Initiator
#    - 	Disable ACK Delayed on ISCSI Software Adapter
# The script can configure ISCSI Dynamic hba, it's in comment line
#					 					   
#																																		   
################################################################################################################################################################################################################################
 

[xml]$s = Get-Content "C:\scripts\config_file.xml"

Import-Module VMware.PowerCLI


ForEach ($Server in $s.ESXi.Host) {
 
	$VMhost =$Server.VMhost
	$Username =$Server.Username
	$Password =$Server.Password
	$hostname = $Server.HostName
	$mgtnic1 =$s.Esxi.Parameters.mgtnic1
	$mgtnic2 =$s.Esxi.Parameters.mgtnic2
	$vmotion_name =$s.Esxi.Parameters.vmotion_name
	$vmotionvlan =$s.Esxi.Parameters.vmotionvlan
	$vmotionIP =$Server.vmotionIP
	$vmosubnet =$s.Esxi.Parameters.vmosubnet
	$dnspri =$s.Esxi.Parameters.dnspri
	$dnsalt =$s.Esxi.Parameters.dnsalt
	$domainname =$s.Esxi.Parameters.domainname
	$ntpone =$s.Esxi.Parameters.ntpone
	$ntptwo =$s.Esxi.Parameters.ntptwo
	$iscsinic1 =$s.Esxi.CustomParameters.iscsinic1
	$iscsinic2 =$s.Esxi.CustomParameters.iscsinic2
	$iscsi1 =$s.Esxi.CustomParameters.iscsi1_name
	$iscsi2 =$s.Esxi.CustomParameters.iscsi2_name
	$iscsiIP1 =$Server.iscsiIP1
	$iscsiIP2 =$Server.iscsiIP2
	$iscsisubnet =$s.Esxi.CustomParameters.iscsisubnet
	$protocol = $s.Esxi.CustomParameters.protocol
	$VMSwitch1 = $s.Esxi.CustomParameters.Name
	
	
	$SecurePassword = ConvertTo-SecureString $Passsword  -AsPlainText -Force
	Connect-VIServer $VMhost -username $Username -password $SecurePassword
	
	#Configure Hostname of ESXi
	Write-host "Configuring hostname of ESXi $hostname.$domainname"
	$vmHostNetworkInfo = Get-VmHostNetwork -Host $VMhost
	Set-VmHostNetwork -Network $vmHostNetworkInfo -DomainName $domainname -HostName $hostname -DnsFromDhcp $false
	
	
    get-virtualswitch -VMHost $VMhost -name vSwitch0 | set-virtualswitch -nic $mgtnic1,$mgtnic2 -confirm:$false
	Get-VirtualPortGroup -VMHost $vmhost -Name "Management Network" | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive $mgtnic1 -MakeNicStandby $mgtnic2 -FailbackEnabled:$false  -confirm:$false
	#désactiver vmotion sur Management Network
	Get-VMHostNetworkAdapter | where{$_.portgroupname -eq "Management Network"} | set-VMhostNetworkAdapter -vmotionenabled:$false -confirm:$false

    
	if($protocol -eq "iSCSI"){
		#Creating vSwitch1 for iSCSI
		if ((get-virtualswitch -VMHost $VMhost -name $VMSwitch1 -ErrorAction SilentlyContinue) -eq $null) {
	 
			Write-host "Creating VSS Switch $VMSwitch1"
			new-virtualswitch -host $VMhost -name $VMSwitch1 | set-virtualswitch -nic $iscsinic1,$iscsinic2 -MTU 9000 -confirm:$false
			
		} else {
			Write-host "VSS Switch $VMSwitch1 already exists"
			Get-virtualswitch -host $VMhost -name $VMSwitch1 | set-virtualswitch -nic $iscsinic1,$iscsinic2 -MTU 9000 -confirm:$false
		}
	 
	 
		#Creating iSCSI1 VMkernel Ports
		if ((Get-VirtualPortGroup -VMHost $vmhost -Name $iscsi1 -ErrorAction SilentlyContinue) -eq $null) {
			Write-host "Creating VMkernel port $iscsi1"    
			new-vmhostnetworkadapter -vmhost $VMhost -PortGroup $iscsi1 -VirtualSwitch $VMSwitch1 -IP $iscsiIP1 -SubnetMask $iscsisubnet -MTU 9000 -confirm:$false
			Get-VirtualPortGroup -VMHost $vmhost -Name $iscsi1 | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive $iscsinic1 -MakeNicUnused $iscsinic2 -FailbackEnabled:$false
	 
		} else {
	 
			Write-host "VMkernel port $iscsi1 already exists"
		}
	 
	 
		#Creating iSCSI2 VMkernel Ports
	 
		if ((Get-VirtualPortGroup -VMHost $vmhost -Name $iscsi2 -ErrorAction SilentlyContinue) -eq $null) {
	 
			Write-host "Creating VMkernel port $iscsi2"
			new-vmhostnetworkadapter -vmhost $VMhost -PortGroup $iscsi2 -VirtualSwitch $VMSwitch1 -IP $iscsiIP2 -SubnetMask $iscsisubnet -MTU 9000  -confirm:$false
			Get-VirtualPortGroup -VMHost $vmhost -Name $iscsi2 | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive $iscsinic2 -MakeNicUnused $iscsinic1 -FailbackEnabled:$false 
	 
		} else {
	 
			Write-host "VMkernel port $iscsi2 already exists"
	 
		}

		#Create Software iSCSI Adapter

		get-vmhoststorage $VMhost | set-vmhoststorage -softwareiscsienabled $True

	 

		#Get Software iSCSI adapter HBA number and put it into an array

		$HBA = Get-VMHostHba -VMHost $VMHost -Type iSCSI | %{$_.Device}

	 
		#Set your VMKernel numbers, Use ESXCLI to create the iSCSI Port binding in the iSCSI Software Adapter,

		$vmk1number = Get-VirtualPortGroup -VMHost $vmhost -Name $iscsi1 | Get-vmhostnetworkadapter | %{$_.NAME}

		$vmk2number = Get-VirtualPortGroup -VMHost $vmhost -Name $iscsi2 | Get-vmhostnetworkadapter | %{$_.NAME}

		$esxcli = Get-EsxCli -VMhost $VMhost

		$Esxcli.iscsi.networkportal.add($HBA, $Null, $vmk1number)

		$Esxcli.iscsi.networkportal.add($HBA, $Null, $vmk2number)
		
		#Setup the Discovery iSCSI IP addresses on the iSCSI Software Adapter

		#$hbahost = get-vmhost $VMhost | get-vmhosthba -type iscsi

		#new-iscsihbatarget -iscsihba $hbahost -address "192.168.0.1"
		#new-iscsihbatarget -iscsihba $hbahost -address "192.168.0.2"

		#This section will get host information needed  
		$HostView = Get-VMHost $VMhost | Get-View  
		$HostStorageSystemID = $HostView.configmanager.StorageSystem  
		$HostiSCSISoftwareAdapterHBAID = ($HostView.config.storagedevice.HostBusAdapter | where {$_.Model -match "iSCSI Software"}).device  
	  
		#Disable Delayed ASK  
		$options = New-Object VMWare.Vim.HostInternetScsiHbaParamValue[] (1)  
	  
		$options[0] = New-Object VMware.Vim.HostInternetScsiHbaParamValue  
		$options[0].key = "DelayedAck"  
		$options[0].value = $false  
	   
		#This section applies the options above to the host you got the information from.  
		$HostStorageSystem = Get-View -ID $HostStorageSystemID  
		$HostStorageSystem.UpdateInternetScsiAdvancedOptions($HostiSCSISoftwareAdapterHBAID, $null, $options)
	}

    # Enable SSH
    get-vmhost $VMhost | get-vmhostservice | where-object {$_.key -eq "TSM-SSH"} | start-vmhostservice -confirm:$false
    get-vmhost $VMhost | get-vmhostservice | where-object {$_.key -eq "TSM-SSH"} | set-vmhostservice -policy "On" -confirm:$false
    # Disable alert shell
    Get-VMHost $VMhost | Get-AdvancedSetting UserVars.SuppressShellWarning | Set-AdvancedSetting -Value 1  -confirm:$false

    #Creating vMotion VMkernel Ports
 
    if ((Get-VirtualPortGroup -VMHost $vmhost -Name $vmotion_name -ErrorAction SilentlyContinue) -eq $null) {
 
        Write-host "Creating VMkernel port $vmotion_name"
        new-vmhostnetworkadapter -vmhost $VMhost -PortGroup $vmotion_name -VirtualSwitch vswitch0 -IP $vmotionip1 -SubnetMask $vmosubnet -VMotionEnabled:$true
        Get-VirtualPortGroup -VMHost $vmhost -Name $vmotion_name | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive $mgtnic2 -MakeNicStandby $mgtnic1
		Get-VirtualPortGroup -VMHost $vmhost -Name $vmotion_name | Set-VirtualPortGroup -vlanid $vmotionvlan
    } else {
 
        Write-host "VMkernel port $vmotion_name already exists"
 
    }
	 #Configure VLAN on vswitch
	Write-host "Delete default port group VM Network"
		
	if ((Get-VirtualPortGroup -VMHost $vmhost -Name "VM Network") -eq $null){
		Write-host "VM Network port group do not exist"
	}else{
		Write-host "VM Network port group will be deleted"
		Get-VirtualPortGroup -VMHost $vmhost -Name "VM Network" | Remove-VirtualPortGroup  -confirm:$false
	}
	
	
	
	ForEach ($vswitch in $s.Esxi.vSwitchName){
		$vSwitchName = $vswitch.Name
		[string]$nics = $vswitch.nics
		ForEach ($VMPort in $vSwitch.VMPort) {
			$vlanName = $VMPort.vlanName
			$vlanID = $VMPort.vlanID
			
			if ((get-virtualswitch -VMHost $VMhost -name $vSwitchName -ErrorAction SilentlyContinue) -eq $null) {
			Write-host "if vswitch do not exist create VSS Switch $vSwitchName"
			new-virtualswitch -host $VMhost -name $vSwitchName | set-virtualswitch -nic $nics -MTU 1500 -confirm:$false
			Write-host "Creating Vlan port $vlanName"
			Get-VirtualSwitch -Name "$vSwitchName" | New-VirtualPortGroup -Name $vlanName -VLanId $vlanID
			} else{
				Write-host "vswitch $vSwitchName exist"
				if ((Get-VirtualPortGroup -VMHost $vmhost -Name $VMPort.vlanName -ErrorAction SilentlyContinue) -eq $null) {
					Write-host "Creating Vlan port $vlanName"
					Get-VirtualSwitch -Name "$vSwitchName" | New-VirtualPortGroup -Name $vlanName -VLanId $vlanID
				} else {
				Write-host "VMkernel port $vlanName already exists"
				}
			}
		}
	}
		
	#Configuration DNS
	Write-Host "Configuring DNS and Domain Name on $VMhost" -ForegroundColor Green
	Get-VMHostNetwork -VMHost $VMhost | Set-VMHostNetwork -DomainName $domainname -SearchDomain $domainname -DNSAddress $dnspri , $dnsalt -Confirm:$false

	Write-Host "Configuring NTP Servers on $VMhost" -ForegroundColor Green
	Add-VMHostNTPServer -NtpServer $ntpone , $ntptwo -VMHost $VMhost -Confirm:$false

	Write-Host "Configuring NTP Client Policy on $VMhost" -ForegroundColor Green
	Get-VMHostService -VMHost $VMhost | where{$_.Key -eq "ntpd"} | Set-VMHostService -policy "on" -Confirm:$false

	Write-Host "Restarting NTP Client on $VMhost" -ForegroundColor Green
	Get-VMHostService -VMHost $VMhost | where{$_.Key -eq "ntpd"} | Restart-VMHostService -Confirm:$false	
	
	Disconnect-VIServer $VMhost  -confirm:$false
}