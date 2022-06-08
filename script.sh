
echo "query storage account"
az storage account list

if [ $? -ne 0 ]; then
    exit 1
fi

echo "update storage account"
az storage account update --name ${NAME_STORAGE_ACCOUNT}   --resource-group ${NAME_RESOURCE_GROUP} --https-only false

if [ $? -ne 0 ]; then
    exit 1
fi