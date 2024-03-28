#!/bin/sh
workloadName='fabrikam'
parameterFile='./main.bicepparam'
location='eastus'

ticks=$(date +%s) && az deployment sub create --location $location --template-file ./main.bicep --parameters $parameterFile --name "$workloadName-$ticks"
