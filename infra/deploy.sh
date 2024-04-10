#!/bin/sh
workloadName='fabrikam'
parameterFile='./main.bicepparam'
location='eastus'
yamlFile='./yaml/deployment.yaml'
clusterResourceGroupName="rg-$workloadName-aks"


ticks=$(date +%s) && az deployment sub create --location $location --template-file ./main.bicep --parameters $parameterFile --name "$workloadName-$ticks"
clusterName=$(az aks list --resource-group $clusterResourceGroupName -o tsv --query [0].name | tr -d '\r')
az aks command invoke --resource-group $clusterResourceGroupName --name "$clusterName" --command "kubectl delete -f 'deployment.yaml'" --file $yamlFile 
az aks command invoke --resource-group $clusterResourceGroupName --name $clusterName --command "kubectl apply -f 'deployment.yaml'" --file $yamlFile
Sleep 60
az aks command invoke --resource-group $clusterResourceGroupName --name $clusterName --command "kubectl get pods"
az aks command invoke --resource-group $clusterResourceGroupName --name $clusterName --command "kubectl get service gpu-app-service"