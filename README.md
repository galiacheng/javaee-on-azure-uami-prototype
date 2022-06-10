This sample is to provision Azure User Assigned Managed Identify (UAMI) and Deployment Script using Bicep template. By assigning Contributor Role to the UAMI, the deplyment script is able to access/update Azure resource (here is a storage account).

## Prerequisites

To deploy the sample, you must meet one of the following subscription permission: 
- [Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor) + [User Access Administrator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#user-access-administrator) (Both are subsrciption roles, not AAD roles.)
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
