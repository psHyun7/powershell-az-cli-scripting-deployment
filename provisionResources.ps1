# TODO: set variables
$studentName = "sung"
$rgName = "$studentName-lc0820-ps-rg"
$vmName = "$studentName-lc0820-ps-vm"
$vmSize = "Standard_B2s"
$vmImage = $(az vm image list --query "[? contains(urn, 'Ubuntu')] | [0].urn")
$vmAdminUsername = "student"
$vmAdminPassword = "LaunchCode-@zure1"
$kvName = "$studentName-lc0820-ps-kv"
$kvSecretName = "ConnectionStrings--Default"
$kvSecretValue = "server=localhost;port=3306;database=coding_events;user=coding_events;password=launchcode"

# TODO: provision RG
az group create -n $rgName
az configure --default group=$rgName

# TODO: provision VM
$vmData = $(az vm create -n $vmName --size $vmSize --image $vmImage --admin-username $vmAdminUsername --admin-password $vmAdminPassword --authentication-type password --assign-identity --generate-ssh-keys)
$vmDataJson = $vmData | ConvertFrom-Json
az configure --default vm=$vmName

# TODO: capture the VM systemAssignedIdentity
$vmId = $vmDataJson.identity.systemAssignedIdentity

# Capturing VM Public IP
$vmIp = $vmDataJson.publicIpAddres

# TODO: open vm port 443
az vm open-port --port 443

# provision KV
az keyvault create -n $kvName --enable-soft-delete false --enabled-for-deployment true

# TODO: create KV secret (database connection string)
az keyvault secret set --vault-name $kvName --description "connection string" --name $kvSecretName --value $kvSecretValue

# TODO: set KV access-policy (using the vm ``systemAssignedIdentity``)
az keyvault set-policy --name $kvName --object-id $vmId --secret-permissions list get

# Edit Config file
$configFileDir = Read-Host "Please Enter the absolute path of appsettings.json"
$appSetting = Get-Content $configFileDir\appsettings.json | ConvertFrom-Json
$appSetting.KeyVaultName = $kvName
$appSetting.ServerOrigin = "https://$vmIp"
$appSetting | ConvertTo-Json | Set-Content $configFileDir\appsettings.json

# Committ and Push changed config file Before Deployment
Set-Location $configFileDir
git add .
git commit -m "Powershell Automation Pre-Deployment Commit"
git push

# Configure VM and Deploy
az vm run-command invoke --command-id RunShellScript --scripts @vm-configuration-scripts/1configure-vm.sh

az vm run-command invoke --command-id RunShellScript --scripts @vm-configuration-scripts/2configure-ssl.sh

az vm run-command invoke --command-id RunShellScript --scripts @deliver-deploy.sh


# TODO: print VM public IP address to STDOUT or save it as a file
az vm run-command invoke --command-id RunShellScript --scripts "echo $vmIp | tee ~/home/student/ip_address.txt"