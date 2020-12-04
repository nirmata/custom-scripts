# Enable needed Windows features
Write-Host "Enabling Hyoer-V. Do NOT Reboot!"
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
Write-Host "Enabling Containers Do NOT Reboot!!"
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart

# Install Docker Enterprise
Write-Host "Installing Docker. Do NOT Reboot!!"
Install-Module DockerMsftProvider -Force
Install-Package Docker -ProviderName DockerMsftProvider -Force -RequiredVersion 19.03

# Open Needed Firewall ports
Write-Host "Updating Firewall for Docker"
netsh advfirewall firewall add rule name="docker_in_tcp" dir=in action=allow protocol=tcp localport=80,443,2376,9099,10250,10254,30000-32767
netsh advfirewall firewall add rule name="docker_out_tcp" dir=out action=allow protocol=tcp localport=80,443,2376,9099,10250,10254,30000-32767

# Note 4789 is for VXLAN
Write-Host "Updating Firewall for VXLAN"
netsh advfirewall firewall add rule name="docker_in_udp" dir=in action=allow protocol=tcp localport=4789,8472,30000-32767
netsh advfirewall firewall add rule name="docker_out_udp" dir=out action=allow protocol=tcp localport=4789,8472,30000-32767


Write-Host "You must now reboot. Running Restart-Computer"
Restart-Computer -Force
