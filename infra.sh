az config set extension.use_dynamic_install=yes_without_prompt
rg=$(az group list --query "[].name" -o tsv)
loc=$(az group list --query "[].location" -o tsv)
adminUser="azureuser"
adminPass="Motdepassefort123!"
repo="https://github.com/CallmeVRM/azure-LB02.git"

az network vnet create -g $rg -l $loc -n front-vnet \
  --address-prefixes 10.1.0.0/16 \
  --subnet-name vm-subnet --subnet-prefixes 10.1.0.0/24

az network vnet create -g $rg -l $loc -n app-vnet \
  --address-prefixes 10.2.0.0/16 \
  --subnet-name vm-subnet --subnet-prefixes 10.2.0.0/24

az network vnet create -g $rg -l $loc -n data-vnet \
  --address-prefixes 10.3.0.0/16 \
  --subnet-name vm-subnet --subnet-prefixes 10.3.0.0/24

for pair in "front-vnet app-vnet" "app-vnet data-vnet" "front-vnet data-vnet"; do
  v1=$(echo $pair | awk '{print $1}')
  v2=$(echo $pair | awk '{print $2}')
  az network vnet peering create -g $rg -n ${v1}_to_${v2} \
    --vnet-name $v1 --remote-vnet $v2 --allow-vnet-access
  az network vnet peering create -g $rg -n ${v2}_to_${v1} \
    --vnet-name $v2 --remote-vnet $v1 --allow-vnet-access
done

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

az network public-ip create -g $rg -l $loc -n bastion-pub-ip --sku Standard --zone 1
az network vnet subnet create -g $rg --vnet-name front-vnet \
  --name AzureBastionSubnet --address-prefix 10.1.253.0/26
az network bastion create -g $rg -l $loc -n bastion \
  --vnet-name front-vnet --public-ip-address bastion-pub-ip --sku Standard

# Load Balancer Public (Frontend Layer)
az network public-ip create -g $rg -l $loc -n lb-pub-ip-in --sku Standard --zone 1
az network public-ip create -g $rg -l $loc -n lb-pub-ip-out --sku Standard --zone 1

az network lb create -g $rg -l $loc -n front-lb --sku Standard \
  --public-ip-address lb-pub-ip-in --frontend-ip-name lb-front-in \
  --backend-pool-name front-backpool

az network lb frontend-ip create -g $rg --lb-name front-lb \
  --name lb-front-out --public-ip-address lb-pub-ip-out

az network lb probe create -g $rg --lb-name front-lb --name HTTPProbe80 --protocol tcp --port 80
az network lb probe create -g $rg --lb-name front-lb --name HTTPProbe8443 --protocol tcp --port 8443

az network lb rule create -g $rg --lb-name front-lb --name FrontHTTP \
  --protocol TCP --frontend-port 80 --backend-port 80 \
  --frontend-ip-name lb-front-in --backend-pool-name front-backpool --probe-name HTTPProbe80

az network lb rule create -g $rg --lb-name front-lb --name FrontHTTPS \
  --protocol TCP --frontend-port 8443 --backend-port 8443 \
  --frontend-ip-name lb-front-in --backend-pool-name front-backpool --probe-name HTTPProbe8443

#Load Balancer interne – App Layer
az network lb create -g $rg -l $loc -n app-lb --sku Standard \
  --frontend-ip-name app-front-ip --backend-pool-name app-backpool \
  --vnet-name app-vnet --subnet vm-subnet --private-ip-address 10.2.0.250

az network lb probe create -g $rg --lb-name app-lb --name ProbeApp1 --protocol http --path /health --port 5000
az network lb probe create -g $rg --lb-name app-lb --name ProbeApp2 --protocol http --path /health --port 5001

az network lb rule create -g $rg --lb-name app-lb --name App5000 \
  --protocol TCP --frontend-port 5000 --backend-port 5000 \
  --frontend-ip-name app-front-ip --backend-pool-name app-backpool --probe-name ProbeApp1

az network lb rule create -g $rg --lb-name app-lb --name App5001 \
  --protocol TCP --frontend-port 5001 --backend-port 5001 \
  --frontend-ip-name app-front-ip --backend-pool-name app-backpool --probe-name ProbeApp2

#Load Balancer interne – Data Layer
az network lb create -g $rg -l $loc -n data-lb --sku Standard \
  --frontend-ip-name data-front-ip --backend-pool-name data-backpool \
  --vnet-name data-vnet --subnet vm-subnet --private-ip-address 10.3.0.250

az network lb probe create -g $rg --lb-name data-lb --name Probe6000 --protocol http --path /health --port 6000
az network lb probe create -g $rg --lb-name data-lb --name Probe6001 --protocol http --path /health --port 6001

az network lb rule create -g $rg --lb-name data-lb --name Data6000 \
  --protocol TCP --frontend-port 6000 --backend-port 6000 \
  --frontend-ip-name data-front-ip --backend-pool-name data-backpool --probe-name Probe6000

az network lb rule create -g $rg --lb-name data-lb --name Data6001 \
  --protocol TCP --frontend-port 6001 --backend-port 6001 \
  --frontend-ip-name data-front-ip --backend-pool-name data-backpool --probe-name Probe6001

#NAT Gateway (sortie contrôlée du back)
az network public-ip create -g $rg -n nat-gateway-ip --sku Standard --allocation-method Static
az network nat gateway create -g $rg -n multilayer-nat --public-ip-addresses nat-gateway-ip --idle-timeout 10

az network vnet subnet update -g $rg --vnet-name data-vnet --name vm-subnet --nat-gateway multilayer-nat
