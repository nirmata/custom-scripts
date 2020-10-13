Param(

    [parameter(Mandatory = $false)] $BaseDir="c:\k",
    [parameter(Mandatory = $false)] $ClusterCIDR="10.244.0.0/16",
    [parameter(Mandatory = $false)] $ServiceCIDR="10.96.0.0/12",
    [parameter(Mandatory = $false)] $InterfaceName="Ethernet",
    [parameter(Mandatory = $false)] $Release = "1.15.12",
    [parameter(Mandatory = $false)] $NanosServerImageTag = "10.0.17763.802",
    [parameter(Mandatory = $false)] $ServerCoreImageTag = "1809",

    [parameter(Mandatory = $false)] [switch] $Reset=$false
)


$Global:BaseDir=$BaseDir
$Global:Release= $Release
$Global:LogDir=[io.Path]::combine($Global:Dir,"log")
$Global:GithubSDNRepository = 'Microsoft/SDN'
$Global:GithubSDNBranch = 'master'
$Global:NanosServerImageTag = $NanosServerImageTag
$Global:NanoServerImageName = "mcr.microsoft.com/windows/nanoserver"
$Global:ServerCoreImageTag = $ServerCoreImageTag
$Global:ServercoreImageName = "mcr.microsoft.com/windows/servercore"
$Global:NetworkName="vxlan0"
$Global:NetworkMode="overlay"
$Global:ServiceCidr= $ServiceCIDR
$Global:CniPath=$Global:BaseDir
# $Global:ManagementIp="10.10.1.161"
$Global:InterfaceName=$InterfaceName
$Global:ClusterCidr=$ClusterCIDR
$Global:KubeletFeatureGates="RotateKubeletClientCertificate=true"
$Global:KubeproxyFeatureGates="WinOverlay=true"
# Docker is installed ?
function IsDockerInstalledAndRunning() 
{
    $serviceName="docker"
    $service= Get-Service $serviceName -ErrorAction SilentlyContinue
    if(!$service)
    {
      write-host("service $($service.Name) not found")
      exit
    }
    # docker is running
    if($service.Status -ne "Running")
    {
      write-host("service $($service.Name) is not Running (Status: $($service.Status))")
      exit
    }
    write-host("service $($service.Name) is Running")
}


function InstallDockerImages()
{   
    # Nano Server
    $nanoServerImage = $Global:NanoServerImageName +":"+ $Global:NanosServerImageTag
    if (!(docker images $nanoServerImage -q))
    {
        docker pull $nanoServerImage
        if (!($LASTEXITCODE -eq 0))
        {
            throw "Failed to pull $nanoServerImage"
        }
    }
    write-host "Run container with image $nanoServerImage"
    # run image
    docker container run $nanoServerImage | out-null
    if (!($LASTEXITCODE -eq 0))
    {
        throw "Failed to run image $nanoServerImage"
    }
    # set it to latest
    docker tag $nanoServerImage $($NanoServerImageName+":latest")
    write-host "Tag image $nanoServerImage to image $($NanoServerImageName+":latest")"
    

    # Server Core
    $serverCoreImage = $Global:ServercoreImageName +":"+ $Global:ServerCoreImageTag
    if (!(docker images $serverCoreImage -q))
    {
        docker pull $serverCoreImage
        if (!($LASTEXITCODE -eq 0))
        {
            throw "Failed to pull $serverCoreImage"
        }
    }
    write-host "Run container with image $serverCoreImage"
    # run image
    docker container run $serverCoreImage | out-null
    if (!($LASTEXITCODE -eq 0))
    {
        throw "Failed to run image $serverCoreImage"
    }
    # set it to latest
    docker tag $serverCoreImage $($ServercoreImageName+":latest")
    write-host "Tag image $serverCoreImage to image $($ServercoreImageName+":latest")"
}

function InstallPauseImage() 
{
    # Prepare POD infra Images
    $infraPodImage=docker images kubeletwin/pause -q
    if (!$infraPodImage)
    {
        Write-Host "No infrastructure container image found. Building kubeletwin/pause image"
        pushd
        cd $Global:BaseDir
        DownloadFile -Url "https://github.com/$Global:GithubSDNRepository/raw/$Global:GithubSDNBranch/Kubernetes/windows/Dockerfile" -Destination $Global:BaseDir\Dockerfile
        docker build -t kubeletwin/pause .
        popd
    }
}

function InstallKubernetesBinaries()
{

    Param(
        [parameter(Mandatory = $true)] $Release,
            $DestinationPath
        ) 

        $existingPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)

        # For current shell Path update
        $env:path += ";$DestinationPath\kubernetes\node\bin"
        # For Persistent across reboot
        [Environment]::SetEnvironmentVariable("Path", $existingPath + ";$DestinationPath\kubernetes\node\bin", [EnvironmentVariableTarget]::Machine)
    
        $env:KUBECONFIG = $(GetKubeConfig)
        [Environment]::SetEnvironmentVariable("KUBECONFIG", $(GetKubeConfig), [EnvironmentVariableTarget]::Machine)
    
        $Url = "https://dl.k8s.io/v${Release}/kubernetes-node-windows-amd64.tar.gz"
        if ($Source.Url)
        {
            $Url = $Source.Url
        }
    
        DownloadAndExtractTarGz -url $Url -dstPath $DestinationPath        
}

function DownloadAndExtractTarGz($url, $dstPath)
{
    $tmpTarGz = New-TemporaryFile | Rename-Item -NewName { $_ -replace 'tmp$', 'tar.gz' } -PassThru
    $tmpTar = New-TemporaryFile | Rename-Item -NewName { $_ -replace 'tmp$', 'tar' } -PassThru
    DownloadFile -Url $url -Destination $tmpTarGz.FullName -Force
    #Invoke-WebRequest $url -o $tmpTarGz.FullName
    Expand-GZip $tmpTarGz.FullName $tmpTar.FullName
    Expand-7Zip $tmpTar.FullName $dstPath
    Remove-Item $tmpTarGz.FullName,$tmpTar.FullName
}

function DownloadFile()
{
    param(
    [parameter(Mandatory = $true)] $Url,
    [parameter(Mandatory = $true)] $Destination,
    [switch] $Force
    )

    if (!$Force.IsPresent -and (Test-Path $Destination))
    {
        Write-Host "[DownloadFile] File $Destination already exists."
        return
    }

    $secureProtocols = @() 
    $insecureProtocols = @([System.Net.SecurityProtocolType]::SystemDefault, [System.Net.SecurityProtocolType]::Ssl3) 
    foreach ($protocol in [System.Enum]::GetValues([System.Net.SecurityProtocolType])) 
    { 
        if ($insecureProtocols -notcontains $protocol) 
        { 
            $secureProtocols += $protocol 
        } 
    } 
    [System.Net.ServicePointManager]::SecurityProtocol = $secureProtocols
    
    try {
        (New-Object System.Net.WebClient).DownloadFile($Url,$Destination)
        Write-Host "Downloaded [$Url] => [$Destination]"
    } catch {
        Write-Error "Failed to download $Url"
	    throw
    }
}

function Expand-GZip($infile, $outfile = ($infile -replace '\.gz$',''))
{
    # From https://social.technet.microsoft.com/Forums/en-US/5aa53fef-5229-4313-a035-8b3a38ab93f5/unzip-gz-files-using-powershell?forum=winserverpowershell
    $input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
    $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
    $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)
    try {
        if (!$input -or !$output -or !$gzipStream)
        {
            throw "Failed to Unzip the archive"
        }
        $buffer = New-Object byte[](1024)
        while($true){
            $read = $gzipstream.Read($buffer, 0, 1024)
            if ($read -le 0){break}
            $output.Write($buffer, 0, $read)
        }
    } finally {
        $gzipStream.Close()
        $output.Close()
        $input.Close()
    }
}

function Install-7Zip()
{
    # ask to install 7zip, if it's not already installed
    if (-not (Get-Command Expand-7Zip -ErrorAction Ignore)) {
        Install-Package -Scope CurrentUser -Force 7Zip4PowerShell -Verbose
        if(-not $?) {
            Write-Error "Failed to install package"
            Exit 1
        }
    }
}
function GetKubeConfig()
{
    return [io.Path]::Combine($Global:BaseDir, "kubeconfig");
}

function DownloadFlannelBinaries()
{
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string] $Release = "0.11.0",
        [string] $DestinationPath = "c:\flannel"
    )

    Write-Host "Downloading Flannel binaries"
    DownloadFile -Url  "https://github.com/coreos/flannel/releases/download/v${Release}/flanneld.exe" -Destination $DestinationPath\flanneld.exe 
}

function DownloadCniBinaries($NetworkMode, $CniPath)
{
    CreateDirectory $CniPath
    Write-Host "Downloading CNI binaries for $NetworkMode to $CniPath"
    CreateDirectory $CniPath\config
    DownloadAndExtractTarGz "https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-windows-amd64-v0.8.2.tgz" "$CniPath"

    DownloadFile -Url "https://github.com/$Global:GithubSDNRepository/raw/$Global:GithubSDNBranch/Kubernetes/flannel/$NetworkMode/cni/config/cni.conf" -Destination $CniPath\config\cni.conf
}

function CreateDirectory($Path)
{
    if (!(Test-Path $Path))
    {
        md $Path
    }
}
function GetLogDir()
{
    return [io.Path]::Combine($Global:BaseDir, "logs");
}
function GetKubeFlannelPath()
{
    return "c:\etc\kube-flannel"
}
function InstallFlannelD()
{
    param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string] $DestinationPath = "c:\flannel",
    [Parameter(Mandatory = $true)][string] $InterfaceIpAddress
    )
    
    Write-Host "Installing FlannelD Service"
    $logDir = [io.Path]::Combine($(GetLogDir), "flanneld");
    CreateDirectory $logDir
    $log = [io.Path]::Combine($logDir, "flanneldsvc.log");

    DownloadFile -Url  "https://github.com/$Global:GithubSDNRepository/raw/$Global:GithubSDNBranch/Kubernetes/flannel/$Global:NetworkMode/net-conf.json" -Destination $(GetFlannelNetConf)
    CreateDirectory $(GetKubeFlannelPath)
    copy $Global:BaseDir\net-conf.json $(GetKubeFlannelPath)

    $flanneldArgs = @(
        "$DestinationPath\flanneld.exe",
        "--kubeconfig-file=$(GetKubeConfig)",
        "--iface=$InterfaceIpAddress",
        "--ip-masq=1",
        "--kube-subnet-mgr=1"
    )

    $service = Get-Service FlannelD -ErrorAction SilentlyContinue
    if (!$service)
    {
        $nodeName = (hostname).ToLower()
        CreateService -ServiceName FlannelD -CommandLine $flanneldArgs `
            -LogFile "$log" -EnvVaribles @{NODE_NAME = "$nodeName";}    
    }
}
function GetFlannelNetConf()
{
    return [io.Path]::Combine($Global:BaseDir, "net-conf.json")
}
function CreateService()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $ServiceName,
        [parameter(Mandatory=$true)] [string[]] $CommandLine,
        [parameter(Mandatory=$true)] [string] $LogFile,
        [parameter(Mandatory=$false)] [Hashtable] $EnvVaribles = $null
    )
    $binary = CreateSCMService -ServiceName $ServiceName -CommandLine $CommandLine -LogFile $LogFile -EnvVaribles $EnvVaribles
    # remove service, if it exists nope!
    New-Service -name $ServiceName -binaryPathName $binary `
        -displayName $ServiceName -startupType Automatic    `
        -Description "$ServiceName Kubernetes Service" 

    Write-Host @" 
    ++++++++++++++++++++++++++++++++
    Successfully created the service
    ++++++++++++++++++++++++++++++++
    Service [$ServiceName]
    Cmdline [$binary] 
    Env     [$($EnvVaribles | ConvertTo-Json -Depth 10)]
    Log     [$LogFile]
    ++++++++++++++++++++++++++++++++
"@
}

function CreateSCMService()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $ServiceName,
        [parameter(Mandatory=$true)] [string[]] $CommandLine,
        [parameter(Mandatory=$true)] [string] $LogFile,
        [parameter(Mandatory=$false)] [Hashtable] $EnvVaribles = $null
    )
    $Binary = $CommandLine[0].Replace("\", "\\");
    $Arguments = ($CommandLine | Select -Skip 1).Replace("\", "\\").Replace('"', '\"')
    $SvcBinary = "$Global:BaseDir\${ServiceName}Svc.exe"
    $LogFile = $LogFile.Replace("\", "\\")

    $envSrc = "";
    if ($EnvVaribles)
    {
        foreach ($key in $EnvVaribles.Keys)
        {
            $value = $EnvVaribles[$key];
            $envSrc += @"
            m_process.StartInfo.EnvironmentVariables["$key"] = "$value";
"@
        }
    }

    Write-Host "Create a SCMService Binary for [$ServiceName] [$CommandLine] => [$SvcBinary]"
    # reference: https://msdn.microsoft.com/en-us/magazine/mt703436.aspx
    $svcSource = @"
        using System;
        using System.IO;
        using System.ServiceProcess;
        using System.Diagnostics;
        using System.Runtime.InteropServices;
        using System.ComponentModel;

        public enum ServiceType : int {                                       
            SERVICE_WIN32_OWN_PROCESS = 0x00000010,
            SERVICE_WIN32_SHARE_PROCESS = 0x00000020,
        };                                                                    
        
        public enum ServiceState : int {                                      
            SERVICE_STOPPED = 0x00000001,
            SERVICE_START_PENDING = 0x00000002,
            SERVICE_STOP_PENDING = 0x00000003,
            SERVICE_RUNNING = 0x00000004,
            SERVICE_CONTINUE_PENDING = 0x00000005,
            SERVICE_PAUSE_PENDING = 0x00000006,
            SERVICE_PAUSED = 0x00000007,
        };                                                                    
          
        [StructLayout(LayoutKind.Sequential)]
        public struct ServiceStatus {
            public ServiceType dwServiceType;
            public ServiceState dwCurrentState;
            public int dwControlsAccepted;
            public int dwWin32ExitCode;
            public int dwServiceSpecificExitCode;
            public int dwCheckPoint;
            public int dwWaitHint;
        };     

        public class ScmService_$ServiceName : ServiceBase {
            private ServiceStatus m_serviceStatus;
            private Process m_process;
            private StreamWriter m_writer = null;
            public ScmService_$ServiceName() {
                ServiceName = "$ServiceName";
                CanStop = true;
                CanPauseAndContinue = false;
                
                m_writer = new StreamWriter("$LogFile");
                Console.SetOut(m_writer);
                Console.WriteLine("$Binary $ServiceName()");
            }

            ~ScmService_$ServiceName() {
                if (m_writer != null) m_writer.Dispose();
            }

            [DllImport("advapi32.dll", SetLastError=true)]
            private static extern bool SetServiceStatus(IntPtr handle, ref ServiceStatus serviceStatus);

            protected override void OnStart(string [] args) {
                EventLog.WriteEntry(ServiceName, "OnStart $ServiceName - $Binary $Arguments");
                m_serviceStatus.dwServiceType = ServiceType.SERVICE_WIN32_OWN_PROCESS; // Own Process
                m_serviceStatus.dwCurrentState = ServiceState.SERVICE_START_PENDING;
                m_serviceStatus.dwWin32ExitCode = 0;
                m_serviceStatus.dwWaitHint = 2000;
                SetServiceStatus(ServiceHandle, ref m_serviceStatus);

                try
                {
                    m_process = new Process();
                    m_process.StartInfo.UseShellExecute = false;
                    m_process.StartInfo.RedirectStandardOutput = true;
                    m_process.StartInfo.RedirectStandardError = true;
                    m_process.StartInfo.FileName = "$Binary";
                    m_process.StartInfo.Arguments = "$Arguments";
                    m_process.EnableRaisingEvents = true;
                    m_process.OutputDataReceived  += new DataReceivedEventHandler((s, e) => { Console.WriteLine(e.Data); });
                    m_process.ErrorDataReceived += new DataReceivedEventHandler((s, e) => { Console.WriteLine(e.Data); });

                    m_process.Exited += new EventHandler((s, e) => { 
                        Console.WriteLine("$Binary exited unexpectedly " + m_process.ExitCode);
                        if (m_writer != null) m_writer.Flush();
                        m_serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
                        SetServiceStatus(ServiceHandle, ref m_serviceStatus);
                    });

                    $envSrc;
                    m_process.Start();
                    m_process.BeginOutputReadLine();
                    m_process.BeginErrorReadLine();
                    m_serviceStatus.dwCurrentState = ServiceState.SERVICE_RUNNING;
                    Console.WriteLine("OnStart - Successfully started the service ");
                } 
                catch (Exception e)
                {
                    Console.WriteLine("OnStart - Failed to start the service : " + e.Message);
                    m_serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
                }
                finally
                {
                    SetServiceStatus(ServiceHandle, ref m_serviceStatus);
                    if (m_writer != null) m_writer.Flush();
                }
            }

            protected override void OnStop() {
                Console.WriteLine("OnStop $ServiceName");
                try 
                {
                    m_serviceStatus.dwCurrentState = ServiceState.SERVICE_STOPPED;
                    if (m_process != null)
                    {
                        m_process.Kill();
                        m_process.WaitForExit();
                        m_process.Close();
                        m_process.Dispose();
                        m_process = null;
                    }
                    Console.WriteLine("OnStop - Successfully stopped the service ");
                } 
                catch (Exception e)
                {
                    Console.WriteLine("OnStop - Failed to stop the service : " + e.Message);
                    m_serviceStatus.dwCurrentState = ServiceState.SERVICE_RUNNING;
                }
                finally
                {
                    SetServiceStatus(ServiceHandle, ref m_serviceStatus);
                    if (m_writer != null) m_writer.Flush();
                }
            }

            public static void Main() {
                System.ServiceProcess.ServiceBase.Run(new ScmService_$ServiceName());
            }
        }
"@

    Add-Type -TypeDefinition $svcSource -Language CSharp `
        -OutputAssembly $SvcBinary -OutputType ConsoleApplication   `
        -ReferencedAssemblies "System.ServiceProcess" -Debug:$false

    return $SvcBinary
}

function Get-MgmtIpAddress()
{
  Param (
      [Parameter(Mandatory=$false)] [String] $InterfaceName = "Ethernet"
      )
    $na = Get-NetAdapter | ? Name -Like "vEthernet ($InterfaceName*" | ? Status -EQ Up
    return (Get-NetIPAddress -InterfaceAlias $na.ifAlias -AddressFamily IPv4).IPAddress
}

function SetGlobals()
{
    if ((Get-NetAdapter -InterfaceAlias "vEthernet ($Global:InterfaceName)" -ErrorAction SilentlyContinue))   
    {
        $Global:ManagementIp = Get-InterfaceIpAddress -InterfaceName "vEthernet ($Global:InterfaceName)"
        $Global:ManagementSubnet = Get-MgmtSubnet -InterfaceName "vEthernet ($Global:InterfaceName)"
    }
    elseif ((Get-NetAdapter -InterfaceAlias "$Global:InterfaceName" -ErrorAction SilentlyContinue))        
    {
        $Global:ManagementIp = Get-InterfaceIpAddress -InterfaceName "$Global:InterfaceName"
        $Global:ManagementSubnet = Get-MgmtSubnet -InterfaceName "$Global:InterfaceName"
    }
    else {
        throw "$Global:InterfaceName doesn't exist"
    }
}
function GetCniConfigPath()
{
    return [io.Path]::Combine($(GetCniPath), "config");
}
function GetCniConfig()
{
    return [io.Path]::Combine($(GetCniConfigPath), "cni.conf");
}
function GetCniPath()
{
    return [io.Path]::Combine($Global:BaseDir, "cni");
}

function GetKubeDnsServiceIp()
{
    $svc = ConvertFrom-Json $(kubectl.exe get services -n kube-system -o json | Out-String)
    $svc.Items | foreach { $i = $_; if ($i.Metadata.Name -match "dns") { return $i.spec.ClusterIP } }
}

function Get-InterfaceIpAddress()
{
    Param (
        [Parameter(Mandatory=$false)] [String] $InterfaceName = "Ethernet"
    )
    return (Get-NetIPAddress -InterfaceAlias "$InterfaceName" -AddressFamily IPv4).IPAddress
}

function Get-MgmtSubnet
{
    Param (
        [Parameter(Mandatory=$false)] [String] $InterfaceName = "Ethernet"
    )
    $na = Get-NetAdapter -InterfaceAlias "$InterfaceName"  -ErrorAction Stop
    $addr = (Get-NetIPAddress -InterfaceAlias "$InterfaceName" -AddressFamily IPv4).IPAddress
    $mask = (Get-WmiObject Win32_NetworkAdapterConfiguration | ? InterfaceIndex -eq $($na.ifIndex)).IPSubnet[0]
    $mgmtSubnet = (ConvertTo-DecimalIP $addr) -band (ConvertTo-DecimalIP $mask)
    $mgmtSubnet = ConvertTo-DottedDecimalIP $mgmtSubnet
    return "$mgmtSubnet/$(ConvertTo-MaskLength $mask)"
}

function ConvertTo-DecimalIP
{
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [Net.IPAddress] $IPAddress
  )
  $i = 3; $DecimalIP = 0;
  $IPAddress.GetAddressBytes() | % {
    $DecimalIP += $_ * [Math]::Pow(256, $i); $i--
  }

  return [UInt32]$DecimalIP
}

function ConvertTo-DottedDecimalIP
{
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [Uint32] $IPAddress
  )

    $DottedIP = $(for ($i = 3; $i -gt -1; $i--)
    {
      $Remainder = $IPAddress % [Math]::Pow(256, $i)
      ($IPAddress - $Remainder) / [Math]::Pow(256, $i)
      $IPAddress = $Remainder
    })

    return [String]::Join(".", $DottedIP)
}

function ConvertTo-MaskLength
{
  param(
    [Parameter(Mandatory = $True, Position = 0)]
    [Net.IPAddress] $SubnetMask
  )
    $Bits = "$($SubnetMask.GetAddressBytes() | % {
      [Convert]::ToString($_, 2)
    } )" -replace "[\s0]"
    return $Bits.Length
}

function GetClusterCidr()
{
    return $Global:ClusterCidr
}
function GetServiceCidr()
{
    return $Global:ServiceCidr
}

function
Update-CNIConfig
{
    Param(
        $CNIConfig,
        $clusterCIDR,
        $KubeDnsServiceIP,
        $serviceCIDR,
        $InterfaceName,
        $NetworkName,
        [ValidateSet("overlay",IgnoreCase = $true)] [parameter(Mandatory = $true)] $NetworkMode
    )
        $jsonSampleConfig = '{
            "cniVersion": "0.2.0",
            "name": "<NetworkMode>",
            "type": "flannel",
            "capabilities": {
                "dns" : true
            },
            "delegate": {
               "type": "win-overlay",
                "Policies" : [
                  {
                    "Name" : "EndpointPolicy", "Value" : { "Type" : "OutBoundNAT", "ExceptionList": [ "<ClusterCIDR>", "<ServerCIDR>" ] }
                  },
                  {
                    "Name" : "EndpointPolicy", "Value" : { "Type" : "ROUTE", "DestinationPrefix": "<ServerCIDR>", "NeedEncap" : true }
                  }
                ]
              }
          }'
              #Add-Content -Path $CNIConfig -Value $jsonSampleConfig
          
              $configJson =  ConvertFrom-Json $jsonSampleConfig
              $configJson.name = $NetworkName
              $configJson.type = "flannel"
              $configJson.delegate.type = "win-overlay"
          
              $configJson.delegate.Policies[0].Value.ExceptionList[0] = $clusterCIDR
              $configJson.delegate.Policies[0].Value.ExceptionList[1] = $serviceCIDR
          
              $configJson.delegate.Policies[1].Value.DestinationPrefix  = $serviceCIDR
    
    if (Test-Path $CNIConfig) {
        Clear-Content -Path $CNIConfig
    }

    $outJson = (ConvertTo-Json $configJson -Depth 20)
    Write-Host "Generated CNI Config [$outJson]"

    Add-Content -Path $CNIConfig -Value $outJson
}

function
Update-NetConfig
{
    Param(
        $NetConfig,
        $clusterCIDR,
        $NetworkName,
        [ValidateSet("overlay",IgnoreCase = $true)] 
        [parameter(Mandatory = $true)] $NetworkMode
    )
    $jsonSampleConfig = '{
        "Network": "10.244.0.0/16",
        "Backend": {
          "name": "cbr0",
          "type": "vxlan"
        }
      }
    '
    $configJson =  ConvertFrom-Json $jsonSampleConfig
    $configJson.Network = $clusterCIDR
    $configJson.Backend.name = $NetworkName
    if (Test-Path $NetConfig) {
        Clear-Content -Path $NetConfig
    }
    $outJson = (ConvertTo-Json $configJson -Depth 20)
    Add-Content -Path $NetConfig -Value $outJson
    Write-Host "Generated net-conf Config [$outJson]"
}

function InstallKubelet()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $KubeConfig,
        [parameter(Mandatory=$true)] [string] $CniDir,
        [parameter(Mandatory=$true)] [string] $CniConf,
        [parameter(Mandatory=$true)] [string] $KubeDnsServiceIp,
        [parameter(Mandatory=$true)] [string] $NodeIp,
        [parameter(Mandatory = $false)] $KubeletFeatureGates = "",
        [parameter(Mandatory = $false)] [switch] $IsContainerd = $false
    )

    Write-Host "Installing Kubelet Service"
    $kubeletConfig = [io.Path]::Combine($Global:BaseDir, "kubelet.conf")
    $logDir = [io.Path]::Combine($(GetLogDir), "kubelet")
    CreateDirectory $logDir 
    $log = [io.Path]::Combine($logDir, "kubeletsvc.log");

    $kubeletArgs = GetKubeletArguments -KubeConfig $KubeConfig  `
                    -KubeletConfig $kubeletConfig `
                    -CniDir $CniDir -CniConf $CniConf   `
                    -KubeDnsServiceIp $KubeDnsServiceIp `
                    -NodeIp $NodeIp -KubeletFeatureGates $KubeletFeatureGates `
                    -LogDir $logDir -IsContainerd:$IsContainerd

    CreateService -ServiceName Kubelet -CommandLine $kubeletArgs -LogFile "$log"

    # Open firewall for 10250. Required for kubectl exec pod <>
    if (!(Get-NetFirewallRule -Name KubeletAllow10250 -ErrorAction SilentlyContinue ))
    {
        New-NetFirewallRule -Name KubeletAllow10250 -Description "Kubelet Allow 10250" -Action Allow -LocalPort 10250 -Enabled True -DisplayName "KubeletAllow10250" -Protocol TCP -ErrorAction Stop
    }
}
function GetKubeletArguments()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $KubeConfig,
        [parameter(Mandatory=$true)] [string] $KubeletConfig,
        [parameter(Mandatory=$true)] [string] $LogDir,
        [parameter(Mandatory=$true)] [string] $CniDir,
        [parameter(Mandatory=$true)] [string] $CniConf,
        [parameter(Mandatory=$true)] [string] $KubeDnsServiceIp,
        [parameter(Mandatory=$true)] [string] $NodeIp,
        [parameter(Mandatory = $false)] $KubeletFeatureGates = "",
        [parameter(Mandatory = $false)] [switch] $IsContainerd = $false
    )

    $kubeletArgs = @(
        $((get-command kubelet.exe -ErrorAction Stop).Source),
        "--node-labels=node-role.kubernetes.io/agent=,kubernetes.io/role=agent",
        "--hostname-override=$(hostname)",
        '--v=6',
        '--pod-infra-container-image=kubeletwin/pause',
        '--resolv-conf=""',
        # '--allow-privileged=true',
        '--enable-debugging-handlers', # Comment for Config
        "--cluster-dns=$KubeDnsServiceIp", # Comment for Config
        '--cluster-domain=cluster.local', # Comment for Config
        "--kubeconfig=$KubeConfig",
        '--hairpin-mode=promiscuous-bridge', # Comment for Config
        '--image-pull-progress-deadline=20m',
        '--cgroups-per-qos=false',
        "--log-dir=$LogDir",
        '--logtostderr=false',
        '--enforce-node-allocatable=""',
        '--network-plugin=cni',
        "--cni-bin-dir=$CniDir",
        "--cni-conf-dir=$CniConf",
        "--node-ip=$NodeIp"
    )

    if ($KubeletFeatureGates -ne "")
    {
        $kubeletArgs += "--feature-gates=$KubeletFeatureGates"
    }

    $KubeletConfiguration = @{
        Kind = "KubeletConfiguration";
        apiVersion = "kubelet.config.k8s.io/v1beta1";
        ClusterDNS = @($KubeDnsServiceIp);
        ClusterDomain = "cluster.local";
        EnableDebuggingHandlers = $true;
        #ResolverConfig = "";
        HairpinMode = "promiscuous-bridge";
        # CgroupsPerQOS = $false;
        # EnforceNodeAllocatable = @("")
    }


    ConvertTo-Json -Depth 10 $KubeletConfiguration | Out-File -FilePath $KubeletConfig

    #$kubeletArgs += "--config=$KubeletConfig"  # UnComment for Config

    return $kubeletArgs
}

function StartKubelet()
{
    $srv = Get-Service Kubelet -ErrorAction SilentlyContinue
    if (!$srv)
    {
        throw "Kubelet Service not installed"
    }

    if ($srv.Status -ne "Running")
    {
        Start-Service Kubelet -ErrorAction Stop
        WaitForServiceRunningState -ServiceName Kubelet  -TimeoutSeconds 5
    }
}

function WaitForServiceRunningState($ServiceName, $TimeoutSeconds)
{
    $startTime = Get-Date
    while ($true)
    {
        Write-Host "Waiting for service [$ServiceName] to be running"
        $timeElapsed = $(Get-Date) - $startTime
        if ($($timeElapsed).TotalSeconds -ge $TimeoutSeconds)
        {
            throw "Service [$ServiceName] failed to stay in Running state in $TimeoutSeconds seconds"
        }
        if ((Get-Service $ServiceName).Status -eq "Running")
        {
            break;
        }
        Start-Service -Name $ServiceName -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep 1
    }
}

function WaitForNodeRegistration($TimeoutSeconds)
{
    $startTime = Get-Date
    while ($true)
    {
        $timeElapsed = $(Get-Date) - $startTime
        if ($($timeElapsed).TotalSeconds -ge $TimeoutSeconds)
        {
            throw "Fail to register node with master] in $TimeoutSeconds seconds"
        }
        if (IsNodeRegistered)
        {
            break;
        }
        Write-Host "Waiting for the node [$(hostname)] to be registered with $Global:MasterIp"
        Start-Sleep 1
    }
}

function IsNodeRegistered()
{
    kubectl.exe get nodes/$($(hostname).ToLower())
    return (!$LASTEXITCODE)
}

function CreateExternalNetwork
{
    Param([ValidateSet("overlay",IgnoreCase = $true)] 
    [parameter(Mandatory = $true)] $NetworkMode,
    [parameter(Mandatory = $true)] $InterfaceName)

    # Open firewall for Overlay traffic
    New-NetFirewallRule -Name OverlayTraffic4789UDP -Description "Overlay network traffic UDP" -Action Allow -LocalPort 4789 -Enabled True -DisplayName "Overlay Traffic 4789 UDP" -Protocol UDP -ErrorAction SilentlyContinue
    # Create a Overlay network to trigger a vSwitch creation. Do this only once
    if(!(Get-HnsNetwork | ? Name -EQ "External"))
    {
        New-HNSNetwork -Type $NetworkMode -AddressPrefix "192.168.255.0/30" -Gateway "192.168.255.1" -Name "External" -AdapterName "$InterfaceName" -SubnetPolicies @(@{Type = "VSID"; VSID = 9999; }) 
    }
}

function StartFlanneld()
{
    $service = Get-Service -Name FlannelD -ErrorAction SilentlyContinue
    if (!$service)
    {
        throw "FlannelD service not installed"
    }
    Start-Service FlannelD -ErrorAction Stop
    WaitForServiceRunningState -ServiceName FlannelD  -TimeoutSeconds 30
}
function WaitForNetwork($NetworkName)
{
    $startTime = Get-Date
    $waitTimeSeconds = 60

    # Wait till the network is available
    while ($true)
    {
        $timeElapsed = $(Get-Date) - $startTime
        if ($($timeElapsed).TotalSeconds -ge $waitTimeSeconds)
        {
            throw "Fail to create the network[($NetworkName)] in $waitTimeSeconds seconds"
        }
        if ((Get-HnsNetwork | ? Name -EQ $NetworkName.ToLower()))
        {
            break;
        }
        Write-Host "Waiting for the Network ($NetworkName) to be created by flanneld"
        Start-Sleep 5
    }
}

function GetSourceVip($NetworkName)
{
    $sourceVipJson = [io.Path]::Combine($Global:BaseDir,  "sourceVip.json")
    $sourceVipRequest = [io.Path]::Combine($Global:BaseDir,  "sourceVipRequest.json")

    $hnsNetwork = Get-HnsNetwork | ? Name -EQ $NetworkName.ToLower()
    $subnet = $hnsNetwork.Subnets[0].AddressPrefix

    $ipamConfig = @"
        {"cniVersion": "0.2.0", "name": "vxlan0", "ipam":{"type":"host-local","ranges":[[{"subnet":"$subnet"}]],"dataDir":"/var/lib/cni/networks"}}
"@

    $ipamConfig | Out-File $sourceVipRequest

    pushd  
    $env:CNI_COMMAND="ADD"
    $env:CNI_CONTAINERID="dummy"
    $env:CNI_NETNS="dummy"
    $env:CNI_IFNAME="dummy"
    $env:CNI_PATH=$(GetCniPath) #path to host-local.exe

    cd $env:CNI_PATH
    Get-Content $sourceVipRequest | .\host-local.exe | Out-File $sourceVipJson
    $sourceVipJSONData = Get-Content $sourceVipJson | ConvertFrom-Json 

    Remove-Item env:CNI_COMMAND
    Remove-Item env:CNI_CONTAINERID
    Remove-Item env:CNI_NETNS
    Remove-Item env:CNI_IFNAME
    Remove-Item env:CNI_PATH
    popd

    return $sourceVipJSONData.ip4.ip.Split("/")[0]
}

function InstallKubeProxy()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $KubeConfig,
        [parameter(Mandatory=$true)] [string] $NetworkName,
        [parameter(Mandatory=$false)] [string] $SourceVip,
        [parameter(Mandatory=$true)] [string] $ClusterCIDR,
        [parameter(Mandatory = $false)] $ProxyFeatureGates = ""
    )

    $kubeproxyConfig = [io.Path]::Combine($Global:BaseDir, "kubeproxy.conf")
    $logDir = [io.Path]::Combine($(GetLogDir), "kube-proxy")
    CreateDirectory $logDir
    $log = [io.Path]::Combine($logDir, "kubproxysvc.log");

    Write-Host "Installing Kubeproxy Service"
    $proxyArgs = GetProxyArguments -KubeConfig $KubeConfig  `
                    -KubeProxyConfig $kubeproxyConfig `
                    -NetworkName $NetworkName   `
                    -SourceVip $SourceVip `
                    -ClusterCIDR $ClusterCIDR `
                    -ProxyFeatureGates $ProxyFeatureGates `
                    -LogDir $logDir
    
    CreateService -ServiceName Kubeproxy -CommandLine $proxyArgs `
        -LogFile "$log" 
}

function GetProxyArguments()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $KubeConfig,
        [parameter(Mandatory=$true)] [string] $KubeProxyConfig,
        [parameter(Mandatory=$true)] [string] $LogDir,
        [parameter(Mandatory=$true)] [string] $NetworkName,
        [parameter(Mandatory=$false)] [string] $SourceVip,
        [parameter(Mandatory=$true)] [string] $ClusterCIDR,
        [parameter(Mandatory = $false)] $ProxyFeatureGates = ""
    )

    $proxyArgs = @(
        (get-command kube-proxy.exe -ErrorAction Stop).Source,
        "--hostname-override=$(hostname)" # Comment for config
        '--v=4'
        '--proxy-mode=kernelspace'
        "--kubeconfig=$KubeConfig" # Comment for config
        "--network-name=$NetworkName" # Comment for config
        "--cluster-cidr=$ClusterCIDR" # Comment for config
        "--log-dir=$LogDir"
        '--logtostderr=false'
    )

    if ($ProxyFeatureGates -ne "")
    {
        $proxyArgs += "--feature-gates=$ProxyFeatureGates"
    }

    $KubeproxyConfiguration = @{
        Kind = "KubeProxyConfiguration";
        apiVersion = "kubeproxy.config.k8s.io/v1alpha1";
        hostnameOverride = $(hostname);
        clusterCIDR = $ClusterCIDR;
        clientConnection = @{
            kubeconfig = $KubeConfig
        };
        winkernel = @{
            networkName = $NetworkName;
        };
    }

    if ($SourceVip)
    {
        $proxyArgs +=  "--source-vip=$SourceVip" # Comment out for config

        $KubeproxyConfiguration.winkernel += @{
            sourceVip = $SourceVip;
        }
    }
    ConvertTo-Json -Depth 10 $KubeproxyConfiguration | Out-File -FilePath $KubeProxyConfig
    #$proxyArgs += "--config=$KubeProxyConfig" # UnComment for Config
    
    return $proxyArgs
}
function StartKubeProxy()
{
    $service = Get-Service Kubeproxy -ErrorAction SilentlyContinue
    if (!$service)
    {
        throw "Kubeproxy service not installed"
    }
    if ($srv.Status -ne "Running")
    {
        Start-Service Kubeproxy -ErrorAction Stop
        WaitForServiceRunningState -ServiceName Kubeproxy  -TimeoutSeconds 5
    }
}

function GetKubeNodes()
{
    kubectl.exe get nodes
}

function RemoveKubeNode()
{
    kubectl.exe delete node (hostname).ToLower()
}

function CleanupOldNetwork($NetworkName, $ClearDocker = $true)
{
    $hnsNetwork = Get-HnsNetwork | ? Name -EQ $NetworkName.ToLower()

    if ($hnsNetwork)
    {
        if($ClearDocker) {
            # Cleanup all containers
            CleanupContainers
        }

        Write-Host "Cleaning up old HNS network found"
        Write-Host ($hnsNetwork | ConvertTo-Json -Depth 10) 
        Remove-HnsNetwork $hnsNetwork
    }
}
function RemoveExternalNetwork
{
    $network = (Get-HnsNetwork | ? Name -EQ "External")
    if ($network)
    {
        $network | remove-hnsnetwork
    }

}

function CleanupContainers()
{
    docker ps -aq | foreach {docker rm $_ -f} 
}
function UnInstallFlannelD()
{
    Write-Host "Uninstalling FlannelD Service"
    RemoveService -ServiceName FlannelD
    Remove-Item $(GetKubeFlannelPath) -Force -ErrorAction SilentlyContinue
}
function RemoveService()
{
    param
    (
        [parameter(Mandatory=$true)] [string] $ServiceName
    )
    $src = Get-Service -Name $ServiceName  -ErrorAction SilentlyContinue
    if ($src) {
        Stop-Service $src
        sc.exe delete $src;

        $wsrv = gwmi win32_service | ? Name -eq $ServiceName

        # Remove the temp svc binary
    }
}

function UninstallCNI()
{
    UnInstallFlannelD
}

function UninstallKubeProxy()
{
    Write-Host "Uninstalling Kubeproxy Service"
    RemoveService -ServiceName Kubeproxy
}
function UninstallKubelet()
{
    Write-Host "Uninstalling Kubelet Service"
    # close firewall for 10250
    $out = (Get-NetFirewallRule -Name KubeletAllow10250 -ErrorAction SilentlyContinue )
    if ($out)
    {
        Remove-NetFirewallRule $out
    }

    RemoveService -ServiceName Kubelet
}

function UninstallKubernetesBinaries()
{
    Param(
    $DestinationPath
    ) 
    Remove-Item Env:\KUBECONFIG -ErrorAction SilentlyContinue

    # For current shell Path update
    $existingPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    $existingPath = $existingPath.Replace($DestinationPath+'\kubernetes\node\bin;', "")
    # For Persistent across reboot
    [Environment]::SetEnvironmentVariable("Path", $existingPath, [EnvironmentVariableTarget]::Machine)
    Remove-Item $DestinationPath -Force -ErrorAction SilentlyContinue
}


if ($Reset.IsPresent)
{
    RemoveKubeNode
    CleanupContainers
    CleanupOldNetwork $Global:NetworkName
#    RemoveExternalNetwork
    UninstallCNI
    UninstallKubeProxy
    UninstallKubelet
    UninstallKubernetesBinaries -DestinationPath $Global:BaseDir
#    Remove-Item $Global:BaseDir -Recurse -ErrorAction SilentlyContinue
    exit
}


if (!(Test-Path $Global:BaseDir))
{
    write-host "directory $Global:BaseDir does not exits"
    write-host "create using command: mkdir $Global:BaseDir"
    exit
}

if (!(Test-Path (GetKubeConfig)))
{
    write-host "kubeconfig not found at $(GetKubeConfig)"
    exit
}

function Invoke-HNSRequest
{
    param
    (
        [ValidateSet('GET', 'POST', 'DELETE')]
        [parameter(Mandatory=$true)] [string] $Method,
        [ValidateSet('networks', 'endpoints', 'activities', 'policylists', 'endpointstats', 'plugins')]
        [parameter(Mandatory=$true)] [string] $Type,
        [parameter(Mandatory=$false)] [string] $Action = $null,
        [parameter(Mandatory=$false)] [string] $Data = $null,
        [parameter(Mandatory=$false)] [Guid] $Id = [Guid]::Empty
    )

    $hnsPath = "/$Type"

    if ($id -ne [Guid]::Empty)
    {
        $hnsPath += "/$id";
    }

    if ($Action)
    {
        $hnsPath += "/$Action";
    }

    $request = "";
    if ($Data)
    {
        $request = $Data
    }

    $output = "";
    $response = "";
    Write-Verbose "Invoke-HNSRequest Method[$Method] Path[$hnsPath] Data[$request]"

    $hnsApi = Get-VmComputeNativeMethods
    $hnsApi::HNSCall($Method, $hnsPath, "$request", [ref] $response);

    Write-Verbose "Result : $response"
    if ($response)
    {
        try {
            $output = ($response | ConvertFrom-Json);
        } catch {
            Write-Error $_.Exception.Message
            return ""
        }
        if ($output.Error)
        {
             Write-Error $output;
        }
        $output = $output.Output;
    }

    return $output;
}

function New-HnsNetwork
{
    param
    (
        [parameter(Mandatory=$false, Position=0)]
        [string] $JsonString,
        [ValidateSet('ICS', 'Internal', 'Transparent', 'NAT', 'Overlay', 'L2Bridge', 'L2Tunnel', 'Layered', 'Private')]
        [parameter(Mandatory = $false, Position = 0)]
        [string] $Type,
        [parameter(Mandatory = $false)] [string] $Name,
        [parameter(Mandatory = $false)] $AddressPrefix,
        [parameter(Mandatory = $false)] $Gateway,
        [HashTable[]][parameter(Mandatory=$false)] $SubnetPolicies, #  @(@{VSID = 4096; })

        [parameter(Mandatory = $false)] [switch] $IPv6,
        [parameter(Mandatory = $false)] [string] $DNSServer,
        [parameter(Mandatory = $false)] [string] $AdapterName,
        [HashTable][parameter(Mandatory=$false)] $AdditionalParams, #  @ {"ICSFlags" = 0; }
        [HashTable][parameter(Mandatory=$false)] $NetworkSpecificParams #  @ {"InterfaceConstraint" = ""; }
    )

    Begin {
        if (!$JsonString) {
            $netobj = @{
                Type          = $Type;
            };

            if ($Name) {
                $netobj += @{
                    Name = $Name;
                }
            }

            # Coalesce prefix/gateway into subnet objects.
            if ($AddressPrefix) {
                $subnets += @()
                $prefixes = @($AddressPrefix)
                $gateways = @($Gateway)

                $len = $prefixes.length
                for ($i = 0; $i -lt $len; $i++) {
                    $subnet = @{ AddressPrefix = $prefixes[$i]; }
                    if ($i -lt $gateways.length -and $gateways[$i]) {
                        $subnet += @{ GatewayAddress = $gateways[$i]; }

                        if ($SubnetPolicies) {
                            $subnet.Policies += $SubnetPolicies
                        }
                    }

                    $subnets += $subnet
                }

                $netobj += @{ Subnets = $subnets }
            }

            if ($IPv6.IsPresent) {
                $netobj += @{ IPv6 = $true }
            }

            if ($AdapterName) {
                $netobj += @{ NetworkAdapterName = $AdapterName; }
            }

            if ($AdditionalParams) {
                $netobj += @{
                    AdditionalParams = @{}
                }

                foreach ($param in $AdditionalParams.Keys) {
                    $netobj.AdditionalParams += @{
                        $param = $AdditionalParams[$param];
                    }
                }
            }

            if ($NetworkSpecificParams) {
                $netobj += $NetworkSpecificParams
            }

            $JsonString = ConvertTo-Json $netobj -Depth 10
        }

    }
    Process{
        return Invoke-HnsRequest -Method POST -Type networks -Data $JsonString
    }
}
function Get-VmComputeNativeMethods()
{
        $signature = @'
                     [DllImport("vmcompute.dll")]
                     public static extern void HNSCall([MarshalAs(UnmanagedType.LPWStr)] string method, [MarshalAs(UnmanagedType.LPWStr)] string path, [MarshalAs(UnmanagedType.LPWStr)] string request, [MarshalAs(UnmanagedType.LPWStr)] out string response);
'@

    # Compile into runtime type
    Add-Type -MemberDefinition $signature -Namespace VmCompute.PrivatePInvoke -Name NativeMethods -PassThru
}

SetGlobals
IsDockerInstalledAndRunning
InstallDockerImages
InstallPauseImage
Install-7Zip
InstallKubernetesBinaries -DestinationPath $Global:BaseDir -Release $Global:Release
DownloadFlannelBinaries -DestinationPath $Global:BaseDir
DownloadCniBinaries -NetworkMode $Global:NetworkMode -CniPath (GetCniPath)
InstallFlannelD -Destination $Global:BaseDir -InterfaceIpAddress $Global:ManagementIp
# CreateDirectory (GetCniConfig)
Update-CNIConfig -CNIConfig (GetCniConfig) `
-ClusterCIDR (GetClusterCidr) -KubeDnsServiceIP (GetKubeDnsServiceIp) `
-ServiceCidr (GetServiceCidr) -InterfaceName $InterfaceName `
-NetworkName $Global:NetworkName -NetworkMode $Global:NetworkMode
Update-NetConfig -NetConfig (GetFlannelNetConf) `
-ClusterCIDR (GetClusterCidr) `
-NetworkName $Global:NetworkName -NetworkMode $Global:NetworkMode
InstallKubelet -KubeConfig (GetKubeConfig) -CniDir (GetCniPath) `
-CniConf $(GetCniConfigPath) -KubeDnsServiceIp (GetKubeDnsServiceIp) `
-NodeIp $Global:ManagementIp -KubeletFeatureGates $Global:KubeletFeatureGates 
StartKubelet
WaitForNodeRegistration -TimeoutSeconds 30

# Install CNI & Flannel
CreateExternalNetwork -NetworkMode $Global:NetworkMode -InterfaceName $Global:InterfaceName
sleep 30
StartFlanneld 
WaitForNetwork $Global:NetworkName

# Install & Start KubeProxy
$sourceVip = GetSourceVip -NetworkName $Global:NetworkName
InstallKubeProxy -KubeConfig $(GetKubeConfig) `
        -NetworkName $Global:NetworkName -ClusterCIDR  (GetClusterCidr) `
        -SourceVip $sourceVip `
        -ProxyFeatureGates $Global:KubeproxyFeatureGates
StartKubeproxy
GetKubeNodes
Write-Host "Node $(hostname) successfully joined the cluster"
