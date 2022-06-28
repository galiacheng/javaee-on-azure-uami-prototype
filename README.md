This sample is to demostrate how to leverage Azure User Assigned Managed Identify (UAMI) to connect Azure resources; make those resources to serve as infrustracture that are able to run and expose Oracle WebLogic Server.  Including:

- Run Oracle WebLogic Server on AKS and expose WebLogic with Application Gateway Ingress Controller (AGIC)
- Store certifcates in Key Vault and store WebLogic logs in Storage Account SMB file share
- Use UAMI to connect AGIC with Application Gateway
- Use UAMI to connect Key Vaule with Application Gateway
- Use UAMI to connet Deployment Script with Azure resources


## Prerequisites

To deploy the sample, you must meet one of the following subscription permission: 
- [Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor) + [User Access Administrator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#user-access-administrator) (Both are subsrciption roles, not AAD roles.)
- [Owner](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner)

## Run with Azure CLI

### Run the sample with a new AKS cluster

Create a resourc group:

```bash
az group create -n javaee-on-azure-uami-prototype-rg -l eastus
```

Invoke the script:

```bash
az deployment group create -f mainTemplate.bicep -g javaee-on-azure-uami-prototype-rg
```

### Run the sample with an existing AKS cluster

Create a resourc group:

```bash
az group create -n javaee-on-azure-uami-prototype-rg -l eastus
```

Create an AKS cluster

```bash
az aks create -g javaee-on-azure-uami-prototype-rg -n javaeeUamiTestWlsOnAks --enable-managed-identity
```

Invoke the script and specify the AKS cluster:

```bash
az deployment group create -f mainTemplate.bicep \
    -g javaee-on-azure-uami-prototype-rg \
    --parameters aksClusterName=javaeeUamiTestWlsOnAks aksClusterRGName=javaee-on-azure-uami-prototype-rg createAKSCluster=false
```

### Access application

Url for test application: `http://<appgw-ip>/testwebapp/` and `https://<appgw-ip>/testwebapp/`

## Design details

### Senarios

| Resources | Use Cases |
|---|---|
| AKS | 1. Create a new AKS with system managed identity enable. <br> 2. Support existing AKS cluster of different auth mode: <br> &nbsp; - User assigned managed identity. <br> &nbsp; - System assigned managed identity. <br> &nbsp; - Service principal |
| Key Vault| Auto generate a self-signed certificate for Application SSL/TLS termination, and store it in the key vault. |
| Application Gateway | 1. Expose workload with HTTP. <br> 2. Expose workload with HTTPS. |
| Storage | Enable AKS PV on a SMB file share. |

### Managed Identity and Roles

Here list key managed identity used in the prototype. Terms and phrases used in the table:

- Current resource group: the resource group that runs this sample, e.g. `javaee-on-azure-uami-prototype-rg`
- AKS Node resource group: the managed resource group ok AKS, e.g. `MC_javaee-on-azure-uami-prototype-rg_javaeeUamiTestWlsOnAks_eastus`

1. Managed Identity and roles used in the sample when creating a new AKS cluster.

| Managed Identity Name | Type | Role Assignments | Scope | Usage |
|---|---|---|---|------------|
| `wls-aks-application-gateway-user-defined-managed-itentity` | User Assigned | Contributor | Subscription | The identity is used for Deployment Script: <br> &nbsp; - To access and update AKS cluster for WebLogic deployment and ingress creation. <br> &nbsp; - To access and update key vault. |
| `wls-aks-application-gateway-user-defined-managed-itentity` | User Assigned | Contributor | Current resource group | 1. To connect Application Gateway and AGIC. <br> 2. To access key vault for SSL certificate of Application Gateway.  |

2. Managed Identity and roles used in the sample when bringing an existing AKS cluster

| Managed Identity Name | Type | Resource group |Role Assignments | Scope | Usage |
|---|---|---|---|------------|---|
| `wls-aks-application-gateway-user-defined-managed-itentity` | User Assigned | Current resource group | Contributor | Subscription | The identity is used for Deployment Script: <br> &nbsp; - To access and update existing AKS cluster for WebLogic deployment, network peering and ingress creation. <br> &nbsp; - To access and update key vault. |
| `wls-aks-application-gateway-user-defined-managed-itentity` | User Assigned | Current resource group| Contributor | Current resource group | 1. To access key vault for SSL certificate of Application Gateway.  |
| `ingressapplicationgateway-*` | User Assigned | AKS Node resource group | Contributor | Current resource group | 1. Connect ACIG and Application Gateway. |

Note: manged identity `ingressapplicationgateway-*` is created by command `az aks enable-addons -n ${NAME_AKS_CLUSTER} -g ${NAME_AKS_CLUSTER_RG} --addons ingress-appgw --appgw-id $appgwId`, the command does not support specifying a managed identity.

#### Workflow







