# Deploy-ESXi-VMware
#Version : 1.1																																				  																 
#Author : J. DUCOMMUN																																	       
#Date : Nov. 11 2018																																	           
# Configure for each ESXi :	
#																								 			  				   
# Configure HostName																																	   	
# Configure NtpServer, restart NTP Service, Enable auto start																										 			  				   
# Configure DNS Servers, search domain and Domain DNS																							          		           
# Configure vswitch0 with two nic card
# Configure Managment Network with One vmnic active and the other one passive																													                   
# Deconfigure VMotion on Managment Network																							               
# Create VMkernel for VMotion	
# Configure VMotion		
#    		- IP
#    		- Netmask
#    		- vlan
# Configure VMotion on VMotion vmkernel
# Configure VMotion with One vmnic active and the other one passive
# Create new vswith for iscsi with 2 vmnic card
# Configure Jumbo Frame MTU 9000 on vswitch
# Configure ISCSI :
#    		- Create VMkernel for ISCSI1, configure IP, MTU 9000, vlan
#    		- Create VMkernel for ISCSI2, configure IP, MTU 9000, vlan
#    		- Configure VMnic card, one for ISCSI1 and the other one for ISCSI2																				       
# Create ISCSI Software Adapter Initiator
# Disable ACK Delayed on ISCSI Software Adapter
# (disabled) The script can configure ISCSI Dynamic hba, it's in comment line
# Delete the default VM Network
# Create vSwitch and VM Network
# Enable SSH
# Start SSH Service when host startup
# Disable SSH Shell alert	
