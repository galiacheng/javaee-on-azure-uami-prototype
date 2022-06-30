export script="${BASH_SOURCE[0]}"
export scriptDir="$(cd "$(dirname "${script}")" && pwd)"

ymlIngressWlsAdmin="ingress-wls-admin.yaml"
ymlIngressSslWlsCluster="ingress-ssl-wls-cluster.yaml"
ymlIngressWlsCluster="ingress-wls-cluster.yaml"
ymlOptNs="opt-namespace.yaml"
ymlOptSa="operator-service-account.yaml"
ymlWlsNs="wls-namespace.yaml"
ymlWlsWdtSecret="wls-wdt-k8s-secret.yaml"
ymlWlsAdminAccountSecret="wls-admin-k8s-secret.yaml"
ymlWlsDomain="wls-domain.yaml"
curlMaxTime=120
wlsDomainNS="sample-domain1-ns"

function generate_sample_configurations() {
    cat <<EOF >${scriptDir}/${ymlIngressWlsAdmin}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: azure-ingress-wls-admin-server
  namespace: ${wlsDomainNS}
  labels:
    weblogic.domainUID: "sample-domain1"
    azure.weblogic.target: "admin-server"
    azure.weblogc.createdByWlsOffer: "true"
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
spec:
  rules:
    - http:
        paths:
        - path: /console*
          pathType: Prefix
          backend:
            service:
              name: sample-domain1-admin-server
              port:
                number: 7001
EOF

cat <<EOF >${scriptDir}/${ymlIngressWlsCluster}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: azure-ingress-wls-cluster-1
  namespace: ${wlsDomainNS}
  labels:
    weblogic.domainUID: "sample-domain1"
    azure.weblogic.target: "cluster-1"
    azure.weblogc.createdByWlsOffer: "true"
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: sample-domain1-cluster-cluster-1
                port:
                  number: 8001
EOF

    cat <<EOF >${scriptDir}/${ymlIngressSslWlsCluster}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: azure-ingress-ssl-wls-cluster-1
  namespace: ${wlsDomainNS}
  labels:
    weblogic.domainUID: "sample-domain1"
    azure.weblogic.target: "cluster-1"
    azure.weblogc.createdByWlsOffer: "true"
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: ${NAME_APPGATEWAY_FRONTEND_CERT}
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: sample-domain1-cluster-cluster-1
                port:
                  number: 8001

EOF

    cat <<EOF >${scriptDir}/${ymlOptNs}
apiVersion: v1
kind: Namespace
metadata:
  name: sample-weblogic-operator-ns
EOF

    cat <<EOF >${scriptDir}/${ymlOptSa}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sample-weblogic-operator-sa
  namespace: sample-weblogic-operator-ns
EOF

    cat <<EOF >${scriptDir}/${ymlWlsNs}
apiVersion: v1
kind: Namespace
metadata:
  name: ${wlsDomainNS}
  labels:
    weblogic-operator: "enabled"
EOF

    cat <<EOF >${scriptDir}/${ymlWlsWdtSecret}
apiVersion: v1
kind: Secret
metadata:
  labels:
    weblogic.domainUID: "sample-domain1"
  name: sample-domain1-runtime-encryption-secret
  namespace: ${wlsDomainNS}
data:
  password: QVBCOWZhVEhBUEI5ZmFUSA==
type: Opaque
EOF

    cat <<EOF >${scriptDir}/${ymlWlsAdminAccountSecret}
apiVersion: v1
kind: Secret
metadata:
  labels:
    weblogic.domainUID: "sample-domain1"
  name: sample-domain1-weblogic-credentials
  namespace: ${wlsDomainNS}
data:
  username: d2VibG9naWM=
  password: QVBCOWZhVEhBUEI5ZmFUSA==
type: Opaque
EOF

    cat <<EOF >${scriptDir}/${ymlWlsDomain}
# Copyright (c) 2020, 2021, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#
# This is an example of how to define a Domain resource.
#
apiVersion: "weblogic.oracle/v8"
kind: Domain
metadata:
  name: sample-domain1
  namespace: ${wlsDomainNS}
  labels:
    weblogic.domainUID: sample-domain1

spec:
  # Set to 'FromModel' to indicate 'Model in Image'.
  domainHomeSourceType: FromModel

  # The WebLogic Domain Home, this must be a location within
  # the image for 'Model in Image' domains.
  domainHome: /u01/domains/sample-domain1

  # The WebLogic Server image that the Operator uses to start the domain
  image: "docker.io/sleepycat2/weblogic-samples:wlsonaks"

  # Defaults to "Always" if image tag (version) is ':latest'
  imagePullPolicy: "IfNotPresent"

  # Identify which Secret contains the credentials for pulling an image
  # imagePullSecrets:
  # - name: regsecret
  
  # Identify which Secret contains the WebLogic Admin credentials,
  # the secret must contain 'username' and 'password' fields.
  webLogicCredentialsSecret: 
    name: sample-domain1-weblogic-credentials

  # Whether to include the WebLogic Server stdout in the pod's stdout, default is true
  includeServerOutInPodLog: true

  # Whether to enable overriding your log file location, see also 'logHome'
  logHomeEnabled: true
  
  # The location for domain log, server logs, server out, introspector out, and Node Manager log files
  # see also 'logHomeEnabled', 'volumes', and 'volumeMounts'.
  logHome: /shared/logs/sample-domain1
  
  # Set which WebLogic Servers the Operator will start
  # - "NEVER" will not start any server in the domain
  # - "ADMIN_ONLY" will start up only the administration server (no managed servers will be started)
  # - "IF_NEEDED" will start all non-clustered servers, including the administration server, and clustered servers up to their replica count.
  serverStartPolicy: "IF_NEEDED"

  # Settings for all server pods in the domain including the introspector job pod
  serverPod:
    # Optional new or overridden environment variables for the domain's pods
    # - This sample uses CUSTOM_DOMAIN_NAME in its image model file 
    #   to set the WebLogic domain name
    env:
    - name: CUSTOM_DOMAIN_NAME
      value: "domain1"
    - name: JAVA_OPTIONS
      value: "-Dweblogic.StdoutDebugEnabled=false"
    - name: USER_MEM_ARGS
      value: "-Djava.security.egd=file:/dev/./urandom -Xms256m -Xmx512m "
    - name: MANAGED_SERVER_PREFIX
      value: managed-server
    resources:
      requests:
        cpu: "250m"
        memory: "1.5Gi"

    # Optional volumes and mounts for the domain's pods. See also 'logHome'.
    volumes:
    - name: weblogic-domain-storage-volume
      persistentVolumeClaim:
        claimName: azure-smb-pvc
    volumeMounts:
    - mountPath: /shared
      name: weblogic-domain-storage-volume

  # The desired behavior for starting the domain's administration server.
  adminServer:
    # The serverStartState legal values are "RUNNING" or "ADMIN"
    # "RUNNING" means the listed server will be started up to "RUNNING" mode
    # "ADMIN" means the listed server will be start up to "ADMIN" mode
    serverStartState: "RUNNING"
    # Setup a Kubernetes node port for the administration server default channel
    #adminService:
    #  channels:
    #  - channelName: default
    #    nodePort: 30701
   
  # The number of managed servers to start for unlisted clusters
  replicas: 1

  # The desired behavior for starting a specific cluster's member servers
  clusters:
  - clusterName: cluster-1
    serverStartState: "RUNNING"
    serverPod:
      # Instructs Kubernetes scheduler to prefer nodes for new cluster members where there are not
      # already members of the same cluster.
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: "weblogic.clusterName"
                      operator: In
                      values:
                        - \$(CLUSTER_NAME)
                topologyKey: "kubernetes.io/hostname"
    # The number of managed servers to start for this cluster
    replicas: 2

  # Change the restartVersion to force the introspector job to rerun
  # and apply any new model configuration, to also force a subsequent
  # roll of your domain's WebLogic Server pods.
  restartVersion: '1'

  # Changes to this field cause the operator to repeat its introspection of the
  #  WebLogic domain configuration.
  introspectVersion: '1'

  configuration:

    # Settings for domainHomeSourceType 'FromModel'
    model:
      # Valid model domain types are 'WLS', 'JRF', and 'RestrictedJRF', default is 'WLS'
      domainType: "WLS"

      # Optional configmap for additional models and variable files
      #configMap: sample-domain1-wdt-config-map

      # All 'FromModel' domains require a runtimeEncryptionSecret with a 'password' field
      runtimeEncryptionSecret: sample-domain1-runtime-encryption-secret

    # Secrets that are referenced by model yaml macros
    # (the model yaml in the optional configMap or in the image)
    #secrets:
    #- sample-domain1-datasource-secret
EOF
}

function install_helm() {
    # Install Helm
    local browserURL=$(curl -m ${curlMaxTime} -s https://api.github.com/repos/helm/helm/releases/latest |
        grep "browser_download_url.*linux-amd64.tar.gz.asc" |
        cut -d : -f 2,3 |
        tr -d \")
    local helmLatestVersion=${browserURL#*download\/}
    local helmLatestVersion=${helmLatestVersion%%\/helm*}
    local helmPackageName=helm-${helmLatestVersion}-linux-amd64.tar.gz
    curl -m ${curlMaxTime} -fL https://get.helm.sh/${helmPackageName} -o /tmp/${helmPackageName}
    tar -zxvf /tmp/${helmPackageName} -C /tmp
    mv /tmp/linux-amd64/helm /usr/local/bin/helm
    echo "Helm version"
    helm version
}

function peer_aks_appgw_vnet() {
  local aksMCRGName=$(az aks show -n $NAME_AKS_CLUSTER \
    -g $NAME_AKS_CLUSTER_RG \
    -o tsv --query "nodeResourceGroup")
  local ret=$(az group exists -n ${aksMCRGName})
  if [ "${ret,,}" == "false" ]; then
      echo "AKS namaged resource group ${aksMCRGName} does not exist."
      exit 1
  fi

  local aksNetWorkId=$(az resource list -g ${aksMCRGName} \
    --resource-type Microsoft.Network/virtualNetworks \
    -o tsv --query '[*].id')
  local aksNetworkName=$(az resource list -g ${aksMCRGName} \
    --resource-type Microsoft.Network/virtualNetworks \
    -o tsv --query '[*].name')
  local appGatewaySubnetId=$(az network application-gateway show \
    -g ${NAME_RESOURCE_GROUP} \
    --name ${NAME_APPLICATION_GATEWAY} \
    -o tsv --query "gatewayIpConfigurations[0].subnet.id")
  local appGatewayVnetResourceGroup=$(az network application-gateway show \
    -g ${NAME_RESOURCE_GROUP} \
    --name ${NAME_APPLICATION_GATEWAY} \
    -o tsv --query "gatewayIpConfigurations[0].subnet.resourceGroup")
  local appGatewaySubnetName=$(az resource show --ids ${appGatewaySubnetId} \
    --query "name" -o tsv)
  local appgwNetworkId=$(echo $appGatewaySubnetId | sed s/"\/subnets\/${appGatewaySubnetName}"//)
  local appgwVnetName=$(az resource show --ids ${appgwNetworkId} --query "name" -o tsv)

  local toPeer=true
  # if the AKS and App Gateway have the same VNET, need not peer.
  if [ "${aksNetWorkId}" == "${appgwNetworkId}" ]; then
      echo "AKS and Application Gateway are in the same virtual network: ${appgwNetworkId}."
      toPeer=false
  fi

  # check if the Vnets have been peered.
  local ret=$(az network vnet peering list \
      --resource-group ${appGatewayVnetResourceGroup} \
      --vnet-name ${appgwVnetName} -o json \
      | jq ".[] | select(.remoteVirtualNetwork.id==\"${aksNetWorkId}\")")
  if [ -n "$ret" ]; then
      echo "VNET of AKS ${aksNetWorkId} and Application Gateway ${appgwNetworkId} is peering."
      toPeer=false
  fi

  if [ "${toPeer}" == "true" ]; then
      az network vnet peering create \
          --name aks-appgw-peer \
          --remote-vnet ${aksNetWorkId} \
          --resource-group ${appGatewayVnetResourceGroup} \
          --vnet-name ${appgwVnetName} \
          --allow-vnet-access

      az network vnet peering create \
          --name aks-appgw-peer \
          --remote-vnet ${appgwNetworkId} \
          --resource-group ${aksMCRGName} \
          --vnet-name ${aksNetworkName} \
          --allow-vnet-access
  fi

  # For Kubectl network plugin: https://azure.github.io/application-gateway-kubernetes-ingress/how-tos/networking/#with-kubenet
  # find route table used by aks cluster
  local routeTableId=$(az network route-table list -g $aksMCRGName --query "[].id | [0]" -o tsv)

  # associate the route table to Application Gateway's subnet
  az network vnet subnet update \
      --ids $appGatewaySubnetId \
      --route-table $routeTableId
  
  if [ $? -ne 0 ]; then
    echo "Failed to associate the route table to Application Gateway's subnet"
    exit 1
  fi
}

function enable_agic() {
  local appgwId=$(az network application-gateway show \
    -n ${NAME_APPLICATION_GATEWAY} \
    -g ${NAME_RESOURCE_GROUP} -o tsv --query "id")
  az aks enable-addons -n ${NAME_AKS_CLUSTER} -g ${NAME_AKS_CLUSTER_RG} --addons ingress-appgw --appgw-id $appgwId
  if [ $? -ne 0 ]; then
    echo "Failed to enable AGIC"
    exit 1
  fi
}

function enable_storage() {
  echo "create pv/pvc."
  local storageAccountKey=$(az storage account keys list \
    --resource-group $NAME_RESOURCE_GROUP \
    --account-name $NAME_STORAGE_ACCOUNT --query "[0].value" -o tsv)
  local azureSecretName="azure-secret"
  echo "create secret."
  kubectl -n ${wlsDomainNS} create secret generic ${azureSecretName} \
      --from-literal=azurestorageaccountname=${NAME_STORAGE_ACCOUNT} \
      --from-literal=azurestorageaccountkey=${storageAccountKey}

  cat <<EOF >pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: azure-smb-pv
  labels:
    storageAccount: ${NAME_STORAGE_ACCOUNT}
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  storageClassName: azurefile
  claimRef:
    name: azure-smb-pvc
    namespace: ${wlsDomainNS}
  azureFile:
    secretName: ${azureSecretName}
    shareName: weblogic
    readOnly: false
  mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=1000
  - gid=1000
  - mfsymlinks
  - nobrl
EOF

  cat <<EOF >pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azure-smb-pvc
  namespace: ${wlsDomainNS}
  labels:
    storageAccount: ${NAME_STORAGE_ACCOUNT}
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azurefile
  resources:
    requests:
      storage: 5Gi
EOF

  kubectl apply -f pv.yaml
  echo "create pvc"
  kubectl apply -f pvc.yaml
}

function enable_aks_identity() {
  local identityLength=$(az aks show -g ${NAME_AKS_CLUSTER_RG} -n ${NAME_AKS_CLUSTER} | jq '.identity | length')
  echo "identityLength ${identityLength}"
  if [ $identityLength -lt 1 ]; then
    echo "enable managed identity..."
    # Your cluster is using service principal, and you are going to update the cluster to use systemassigned managed identity.
    # After updating, your cluster's control plane and addon pods will switch to use managed identity, but kubelet will KEEP USING SERVICE PRINCIPAL until you upgrade your agentpool.
    az aks update -y -g ${NAME_AKS_CLUSTER_RG} -n ${NAME_AKS_CLUSTER} --enable-managed-identity
  fi
}

#main script
az aks install-cli

install_helm

if [[ "${BOOL_CREATE_AKS,,}" == "false" ]]; then
  az aks get-credentials --resource-group ${NAME_AKS_CLUSTER_RG} --name ${NAME_AKS_CLUSTER}
  enable_aks_identity
  peer_aks_appgw_vnet
  enable_agic
else
  az aks get-credentials --resource-group ${NAME_RESOURCE_GROUP} --name ${NAME_AKS_CLUSTER}
fi

generate_sample_configurations

echo "install weblogic operator"
kubectl apply -f ${ymlOptNs}
kubectl apply -f ${ymlOptSa}
helm repo add weblogic-operator https://oracle.github.io/weblogic-kubernetes-operator/charts --force-update
helm install weblogic-operator weblogic-operator/weblogic-operator \
    --namespace sample-weblogic-operator-ns \
    --set serviceAccount=sample-weblogic-operator-sa \
    --set "enableClusterRoleBinding=true" \
    --set "domainNamespaceSelectionStrategy=LabelSelector" \
    --set "domainNamespaceLabelSelector=weblogic-operator\=enabled" \
    --wait
if [ $? -ne 0 ]; then 
  echo "Failed to install Helm."
  exit 1
fi

echo "install weblogic"
kubectl apply -f ${ymlWlsNs}
kubectl apply -f ${ymlWlsWdtSecret}
kubectl apply -f ${ymlWlsAdminAccountSecret}

enable_storage

echo "deploy weblogic domain"
kubectl apply -f ${ymlWlsDomain}

echo "create azure ingress"
kubectl apply -f ${ymlIngressWlsCluster}
kubectl apply -f ${ymlIngressWlsAdmin}
kubectl apply -f ${ymlIngressSslWlsCluster}