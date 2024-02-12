#!/bin/sh
az account set --subscription "id"
az deployment sub create --location eastus --template-file ./main.bicep --parameters ./main.bicepparam