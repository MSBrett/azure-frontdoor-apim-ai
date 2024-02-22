#!/bin/sh
ticks=$(date +%s) && az deployment sub create --location eastus --template-file ./main.bicep --parameters ./prod-digital.bicepparam --name "digital-$ticks"