# Enable dynamic installation of extensions without prompt
az config set extension.use_dynamic_install=yes_without_prompt

# Retrieve resource group and location
rg=$(az group list --query "[].name" -o tsv)
loc=$(az group list --query "[].location" -o tsv)

# Define admin credentials and repository URL
adminUser="cloud"
adminPass="Motdepassefort123!"
repo="https://github.com/CallmeVRM/azure-LB02.git"

sleep 5

# ============================================================
# Virtual Network (VNet) and Subnet Creation
# ============================================================

# Create VNet: front-vnet
az network vnet create -g $rg -l $loc -n front-vnet \
    --address-prefixes 10.1.0.0/16 \
    --subnet-name vm-subnet --subnet-prefixes 10.1.0.0/24

# Create VNet: app-vnet
az network vnet create -g $rg -l $loc -n app-vnet \
    --address-prefixes 10.2.0.0/16 \
    --subnet-name vm-subnet --subnet-prefixes 10.2.0.0/24

# Create VNet: data-vnet
az network vnet create -g $rg -l $loc -n data-vnet \
    --address-prefixes 10.3.0.0/16 \
    --subnet-name vm-subnet --subnet-prefixes 10.3.0.0/24

sleep 15

# ============================================================
# VNet Peering
# ============================================================

# Create VNet peering between front-vnet, app-vnet, and data-vnet
for pair in "front-vnet app-vnet" "app-vnet data-vnet" "front-vnet data-vnet"; do
    v1=$(echo $pair | awk '{print $1}')
    v2=$(echo $pair | awk '{print $2}')
    az network vnet peering create -g $rg -n ${v1}_to_${v2} \
        --vnet-name $v1 --remote-vnet $v2 --allow-vnet-access
    az network vnet peering create -g $rg -n ${v2}_to_${v1} \
        --vnet-name $v2 --remote-vnet $v1 --allow-vnet-access
done

# ============================================================
# Network Security Groups (NSG) and Rules
# ============================================================

# Create NSGs and allow all inbound traffic
for n in front app data; do
    az network nsg create -g $rg -n ${n}-nsg
    az network nsg rule create -g $rg --nsg-name ${n}-nsg \
        --name AllowAll --protocol "*" --direction Inbound \
        --priority 100 --source-address-prefixes '*' \
        --source-port-ranges '*' --destination-address-prefixes '*' \
        --destination-port-ranges "*" --access Allow
    az network vnet subnet update -g $rg --vnet-name ${n}-vnet \
        --name vm-subnet --network-security-group ${n}-nsg
done

# ============================================================
# Bastion Host Setup
# ============================================================

# Create public IP for Bastion
az network public-ip create -g $rg -l $loc -n bastion-pub-ip --sku Standard --zone 1

# Create AzureBastionSubnet
az network vnet subnet create -g $rg --vnet-name front-vnet \
    --name AzureBastionSubnet --address-prefix 10.1.253.0/26

# Create Bastion host
az network bastion create -g $rg -l $loc -n bastion \
    --vnet-name front-vnet --public-ip-address bastion-pub-ip --sku Standard --no-wait

# ============================================================
# Load Balancer: Public (Frontend Layer)
# ============================================================

# Create public IPs for Load Balancer
az network public-ip create -g $rg -l $loc -n lb-pub-ip-in --sku Standard --zone 1
az network public-ip create -g $rg -l $loc -n lb-pub-ip-out --sku Standard --zone 1

# Create Load Balancer: front-lb
az network lb create -g $rg -l $loc -n front-lb --sku Standard \
    --public-ip-address lb-pub-ip-in --frontend-ip-name lb-front-in \
    --backend-pool-name front-backpool --no-wait

# Add additional frontend IP configuration
az network lb frontend-ip create -g $rg --lb-name front-lb \
    --name lb-front-out --public-ip-address lb-pub-ip-out

# Create health probes for front-lb
az network lb probe create -g $rg --lb-name front-lb --name HTTPProbe80 --protocol tcp --port 80
az network lb probe create -g $rg --lb-name front-lb --name HTTPProbe8443 --protocol tcp --port 8443

# Create load balancing rules for front-lb
az network lb rule create -g $rg --lb-name front-lb --name FrontHTTP \
    --protocol TCP --frontend-port 80 --backend-port 80 \
    --frontend-ip-name lb-front-in --backend-pool-name front-backpool --probe-name HTTPProbe80

az network lb rule create -g $rg --lb-name front-lb --name FrontHTTPS \
    --protocol TCP --frontend-port 8443 --backend-port 8443 \
    --frontend-ip-name lb-front-in --backend-pool-name front-backpool --probe-name HTTPProbe8443

# Create outbound rule for front-lb to allow VMs to connect to the internet
az network lb outbound-rule create -g $rg --lb-name front-lb --name FrontOutboundRule \
    --frontend-ip-configs lb-front-out --backend-address-pool front-backpool \
    --protocol All --idle-timeout 4 --enable-tcp-reset

# ============================================================
# Load Balancer: Internal (App Layer)
# ============================================================

# Create Load Balancer: app-lb
az network lb create -g $rg -l $loc -n app-lb --sku Standard \
    --frontend-ip-name app-front-ip --backend-pool-name app-backpool \
    --vnet-name app-vnet --subnet vm-subnet --private-ip-address 10.2.0.250 --no-wait

# Create health probes for app-lb
az network lb probe create -g $rg --lb-name app-lb --name ProbeApp1 --protocol http --path /health --port 5000
az network lb probe create -g $rg --lb-name app-lb --name ProbeApp2 --protocol http --path /health --port 5001

# Create load balancing rules for app-lb
az network lb rule create -g $rg --lb-name app-lb --name App5000 \
    --protocol TCP --frontend-port 5000 --backend-port 5000 \
    --frontend-ip-name app-front-ip --backend-pool-name app-backpool --probe-name ProbeApp1

az network lb rule create -g $rg --lb-name app-lb --name App5001 \
    --protocol TCP --frontend-port 5001 --backend-port 5001 \
    --frontend-ip-name app-front-ip --backend-pool-name app-backpool --probe-name ProbeApp2

# ============================================================
# Load Balancer: Internal (Data Layer)
# ============================================================

# Create Load Balancer: data-lb
az network lb create -g $rg -l $loc -n data-lb --sku Standard \
    --frontend-ip-name data-front-ip --backend-pool-name data-backpool \
    --vnet-name data-vnet --subnet vm-subnet --private-ip-address 10.3.0.250 --no-wait

# Create health probes for data-lb
az network lb probe create -g $rg --lb-name data-lb --name Probe6000 --protocol http --path /health --port 6000
az network lb probe create -g $rg --lb-name data-lb --name Probe6001 --protocol http --path /health --port 6001

# Create load balancing rules for data-lb
az network lb rule create -g $rg --lb-name data-lb --name Data6000 \
    --protocol TCP --frontend-port 6000 --backend-port 6000 \
    --frontend-ip-name data-front-ip --backend-pool-name data-backpool --probe-name Probe6000

az network lb rule create -g $rg --lb-name data-lb --name Data6001 \
    --protocol TCP --frontend-port 6001 --backend-port 6001 \
    --frontend-ip-name data-front-ip --backend-pool-name data-backpool --probe-name Probe6001

# ============================================================
# NAT Gateway
# ============================================================

# Create public IPs for NAT Gateways
az network public-ip create -g $rg -n nat-gateway-ip-app --sku Standard --allocation-method Static
az network public-ip create -g $rg -n nat-gateway-ip-data --sku Standard --allocation-method Static

# Create NAT Gateways
az network nat gateway create -g $rg -n app-nat --public-ip-addresses nat-gateway-ip-app --idle-timeout 10
az network nat gateway create -g $rg -n data-nat --public-ip-addresses nat-gateway-ip-data --idle-timeout 10

# Associate NAT Gateways with respective subnets
az network vnet subnet update -g $rg --vnet-name app-vnet --name vm-subnet --nat-gateway app-nat
az network vnet subnet update -g $rg --vnet-name data-vnet --name vm-subnet --nat-gateway data-nat

# ============================================================
# Network Interfaces (NICs) and Virtual Machines (VMs)
# ============================================================

# Create NICs and VMs for front layer (assign static private IPs to match service bindings)
az network nic create -g $rg -l $loc -n front-nic-vm1 --vnet-name front-vnet --subnet vm-subnet --ip-configs name=ipconfig1 private-ip-address=10.1.0.4
az network nic create -g $rg -l $loc -n front-nic-vm2 --vnet-name front-vnet --subnet vm-subnet --ip-configs name=ipconfig1 private-ip-address=10.1.0.5

az network nic ip-config address-pool add -g $rg --lb-name front-lb \
    --address-pool front-backpool --nic-name front-nic-vm1 --ip-config-name ipconfig1
az network nic ip-config address-pool add -g $rg --lb-name front-lb \
    --address-pool front-backpool --nic-name front-nic-vm2 --ip-config-name ipconfig1

az vm create -g $rg -l $loc -n frontend-vm1 \
    --nics front-nic-vm1 --image Ubuntu2404 \
    --admin-username $adminUser --admin-password $adminPass \
    --custom-data @frontend/cloud-init-frontend1.yaml --size Standard_B1s

az vm create -g $rg -l $loc -n frontend-vm2 \
    --nics front-nic-vm2 --image Ubuntu2404 \
    --admin-username $adminUser --admin-password $adminPass \
    --custom-data @frontend/cloud-init-frontend2.yaml --size Standard_B1s

# Create NICs and VMs for app layer (assign static private IPs to match service bindings)
az network nic create -g $rg -l $loc -n app-nic-vm1 --vnet-name app-vnet --subnet vm-subnet --ip-configs name=ipconfig1 private-ip-address=10.2.0.4
az network nic create -g $rg -l $loc -n app-nic-vm2 --vnet-name app-vnet --subnet vm-subnet --ip-configs name=ipconfig1 private-ip-address=10.2.0.5

az network nic ip-config address-pool add -g $rg --lb-name app-lb \
    --address-pool app-backpool --nic-name app-nic-vm1 --ip-config-name ipconfig1
az network nic ip-config address-pool add -g $rg --lb-name app-lb \
    --address-pool app-backpool --nic-name app-nic-vm2 --ip-config-name ipconfig1

az vm create -g $rg -l $loc -n app-vm1 \
    --nics app-nic-vm1 --image Ubuntu2404 \
    --admin-username $adminUser --admin-password $adminPass \
    --custom-data @app/cloud-init-app1.yaml --size Standard_B1s

az vm create -g $rg -l $loc -n app-vm2 \
    --nics app-nic-vm2 --image Ubuntu2404 \
    --admin-username $adminUser --admin-password $adminPass \
    --custom-data @app/cloud-init-app2.yaml --size Standard_B1s

# Create NICs and VMs for data layer (assign static private IPs to match service bindings)
az network nic create -g $rg -l $loc -n data-nic-vm1 --vnet-name data-vnet --subnet vm-subnet --ip-configs name=ipconfig1 private-ip-address=10.3.0.4
az network nic create -g $rg -l $loc -n data-nic-vm2 --vnet-name data-vnet --subnet vm-subnet --ip-configs name=ipconfig1 private-ip-address=10.3.0.5

az network nic ip-config address-pool add -g $rg --lb-name data-lb \
    --address-pool data-backpool --nic-name data-nic-vm1 --ip-config-name ipconfig1
az network nic ip-config address-pool add -g $rg --lb-name data-lb \
    --address-pool data-backpool --nic-name data-nic-vm2 --ip-config-name ipconfig1

az vm create -g $rg -l $loc -n data-vm1 \
    --nics data-nic-vm1 --image Ubuntu2404 \
    --admin-username $adminUser --admin-password $adminPass \
    --custom-data @data/cloud-init-data1.yaml --size Standard_B1s

az vm create -g $rg -l $loc -n data-vm2 \
    --nics data-nic-vm2 --image Ubuntu2404 \
    --admin-username $adminUser --admin-password $adminPass \
    --custom-data @data/cloud-init-data2.yaml --size Standard_B1s

# Create NIC and VM for admin (static IP for admin portal)
az network nic create -g $rg -l $loc -n admin-nic --vnet-name data-vnet --subnet vm-subnet --ip-configs name=ipconfig1 private-ip-address=10.3.0.10

az vm create -g $rg -l $loc -n admin-vm \
    --nics admin-nic --image Ubuntu2404 \
    --admin-username $adminUser --admin-password $adminPass \
    --custom-data @admin/cloud-init-admin.yaml --size Standard_B1s
