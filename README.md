---
page_type: sample
languages:
- azurecli
- bicep
- powershell
- yaml
- json
products:
- azure
- azure-openai
- azure-api-management
- azure-resource-manager
- azure-key-vault
- azure-front-door
name: Azure OpenAI Service with Azure API Management and Azure Front Door
description: This sample demonstrates how to access Azure OpenAI Services using Azure API Management and Azure Front Door.
---
# Summary

This sample demonstrates how to access Azure OpenAI Services using Azure API Management and Azure Front Door.

## Components

- [**Azure OpenAI Service**](https://learn.microsoft.com/en-us/azure/ai-services/openai/overview), a managed service for OpenAI GPT models that exposes a REST API.
- [**Azure API Management**](https://learn.microsoft.com/en-us/azure/api-management/api-management-key-concepts), a managed service that provides a gateway to the backend Azure OpenAI Service instances.
- [**Azure Front Door**](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-overview), a modern cloud Content Delivery Network (CDN) that provides fast, reliable, and secure access between your users and your applications’ static and dynamic web content across the globe.
- [**Azure Key Vault**](https://learn.microsoft.com/en-us/azure/key-vault/key-vault-overview), a managed service that stores the API keys for the Azure OpenAI Service instances as secrets used by Azure API Management.
- [**Azure Managed Identity**](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview), a user-defined managed identity for Azure API Management to access Azure Key Vault.
- [**Azure Bicep**](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview?tabs=bicep), used to create a repeatable infrastructure deployment for the Azure resources.

## Getting Started

To deploy the infrastructure and test load balancing using Azure API Management, you need to:

### Prerequisites

- Install the latest [**.NET SDK**](https://dotnet.microsoft.com/download).
- Install [**PowerShell Core**](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.1).
- Install the [**Azure CLI**](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).
- Install [**Visual Studio Code**](https://code.visualstudio.com/) with the [**Polyglot Notebooks extension**](https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.dotnet-interactive-vscode).
- Apply for access to the [**Azure OpenAI Service**](https://learn.microsoft.com/en-us/azure/ai-services/openai/overview#how-do-i-get-access-to-azure-openai).

### Run the sample notebook

The [**Sample.ipynb**](./Sample.ipynb) notebook contains all the necessary steps to deploy the infrastructure using Azure Bicep, and make requests to the deployed Azure API Management API to test load balancing between two Azure OpenAI Service instances.

> **Note:** The sample uses the [**Azure CLI**](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) to deploy the infrastructure from the [**main.bicep**](./infra/main.bicep) file, and PowerShell commands to test the deployed APIs.

The notebook is split into multiple parts including:

1. Login to Azure and set the default subscription.
2. Deploy the Azure resources using Azure Bicep.
3. Test load balancing using Azure API Management.
4. Cleanup the Azure resources.

Each step is documented in the notebook with additional information and links to relevant documentation.
