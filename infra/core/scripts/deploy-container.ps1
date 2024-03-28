[string]$clusterResourceGroupName = $env:clusterResourceGroupName
[string]$clusterName = $env:clusterName
[string]$yamlFile = $env:yamlFile

if ([string]::IsNullOrEmpty($clusterResourceGroupName) ){
    Write-Output "clusterResourceGroupName not provided"
    throw "clusterResourceGroupName not provided"
}

if ([string]::IsNullOrEmpty($clusterName)){
    Write-Output "clusterName not provided"
    throw "clusterName not provided"
}

if ([string]::IsNullOrEmpty($yamlFile)){
    Write-Output "yamlFile not provided"
    throw "yamlFile not provided"
}

Invoke-AzAksRunCommand -ResourceGroupName $clusterResourceGroupName -Name $clusterName -Force -Command "kubectl delete -f '$yamlFile'"
Invoke-AzAksRunCommand -ResourceGroupName $clusterResourceGroupName -Name $clusterName -Force -Command "kubectl apply -f '$yamlFile'"
Start-Sleep -Seconds 60
Invoke-AzAksRunCommand -ResourceGroupName $clusterResourceGroupName -Name $clusterName -Force -Command 'kubectl get pods'
Invoke-AzAksRunCommand -ResourceGroupName $clusterResourceGroupName -Name $clusterName -Force -Command 'kubectl get service gpu-app-service'