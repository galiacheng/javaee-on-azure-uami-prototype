# azure-uami-sample

## Prerequisites

To deploy the sample, you must meet one of the following condition: 
- [Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor) + [User Access Administrator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#user-access-administrator) 
- [Owner](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner)

## Run with Azure CLI

Create a resourc group:

```bash
az group create -n azure-uami-sample-rg -l eastus
```

Invoke the script:

```bash
az deployment group create -f main.bicep -g azure-uami-sample-rg
```