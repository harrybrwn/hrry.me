# Create list of OK IPs
:if ([:len [/ip firewall address-list find where list=minecraft address=131.0.72.0/22]]=0) do={/ip firewall address-list add list=minecraft address=131.0.72.1 comment="Test address for minecraft server"} else={:put "already in address list"}
# Add Firewall filters to block all NATed packages not in the 'minecraft' list.
:if ([:len [/ip firewall filter find where dst-port="25565"]]=0) do={/ip firewall filter add action=drop chain=forward comment="Drop dstnat packets from in my allowed list" src-address-list=!minecraft connection-nat-state=dstnat dst-port=25565 in-interface-list=WAN log=yes log-prefix=NOT_MC protocol=tcp} else={:put "Filter already exists"}
# Open up NAT to the servers port.
:if ([:len [/ip firewall nat find where dst-port="25565"]]=0) do={/ip firewall nat add action=dst-nat chain=dstnat dst-port=25565 in-interface-list=WAN protocol=tcp to-addresses=10.0.0.8 to-ports=25565 comment="Forward minecraft server"} else={:put "nat rule already exists"}
# Remove NAT rule if needed.
/ip firewall nat remove [find where dst-port="25565"]

# Testing
#:if ([:len [/ip firewall address-list find where list=minecraft address=]]=0) do={/ip firewall address-list add list=minecraft address= comment="Testing Mobile Address"}
#/ip firewall address-list remove [find where list=minecraft address=]
