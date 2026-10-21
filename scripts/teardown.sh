#!/usr/bin/env bash
# teardown.sh
# Removes EVERYTHING the lab created so it stops costing money and can be
# rebuilt cleanly. Keeps the GitHub repository (your portfolio).
#
# Run:  bash scripts/teardown.sh
set -euo pipefail

# ---- Settings ---------------------------------------------------------------
RESOURCE_GROUP="rg-avdlab"
LOCATION="eastus2"
KV_PREFIX="kv-avdlab-"
APP_NAME="gh-avdlab-pipeline"
TEST_USER_NAME="avdtester"
SESSION_HOST_PREFIX="avdsh"
GITHUB_REPO="attisammy/azure-avd-iac-pipeline"
# ----------------------------------------------------------------------------

echo "This permanently deletes the AVD lab: resource group $RESOURCE_GROUP, its Key Vault,"
echo "the pipeline identity $APP_NAME, the test user and the session host device objects."
read -rp "Type DELETE to continue: " CONFIRM
if [ "$CONFIRM" != "DELETE" ]; then
  echo "Cancelled. Nothing was deleted."
  exit 1
fi

echo "==> 1/6 Deleting resource group $RESOURCE_GROUP (VM, disks, NIC, network, AVD, Key Vault)"
echo "        This usually takes 5-15 minutes. Leave the Terminal open."
if [ "$(az group exists --name "$RESOURCE_GROUP")" = "true" ]; then
  az group delete --name "$RESOURCE_GROUP" --yes
  echo "    - resource group deleted"
else
  echo "    = resource group not found (already deleted)"
fi

echo "==> 2/6 Purging soft-deleted Key Vaults (otherwise a rebuild fails: name still reserved)"
DELETED_KVS=$(az keyvault list-deleted --resource-type vault \
  --query "[?starts_with(name, '$KV_PREFIX')].name" -o tsv)
if [ -z "$DELETED_KVS" ]; then
  echo "    = none to purge"
else
  for KV in $DELETED_KVS; do
    az keyvault purge --name "$KV" --location "$LOCATION"
    echo "    - purged $KV"
  done
fi

echo "==> 3/6 Removing Entra ID device objects for session hosts ($SESSION_HOST_PREFIX*)"
if ! DEVICE_IDS=$(az rest --method get \
  --url "https://graph.microsoft.com/v1.0/devices?\$filter=startswith(displayName,'$SESSION_HOST_PREFIX')&\$select=id,displayName" \
  --query "value[].id" -o tsv); then
  echo "    ! could not list devices. Remove them in Entra admin center > Devices > All devices."
  DEVICE_IDS=""
fi
if [ -z "$DEVICE_IDS" ]; then
  echo "    = none to delete"
else
  for DEVICE_ID in $DEVICE_IDS; do
    if az rest --method delete --url "https://graph.microsoft.com/v1.0/devices/$DEVICE_ID"; then
      echo "    - deleted device $DEVICE_ID"
    else
      echo "    ! could not delete $DEVICE_ID. Remove it in Entra admin center > Devices."
    fi
  done
fi

echo "==> 4/6 Deleting the pipeline identity $APP_NAME (also removes its federated credentials)"
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [ -n "$APP_ID" ]; then
  az ad app delete --id "$APP_ID"
  echo "    - app registration deleted"
else
  echo "    = not found"
fi

echo "==> 5/6 Deleting the test user"
DOMAIN=$(az rest --method get --url "https://graph.microsoft.com/v1.0/domains" \
  --query "value[?isDefault].id | [0]" -o tsv)
UPN="$TEST_USER_NAME@$DOMAIN"
if az ad user show --id "$UPN" > /dev/null 2>&1; then
  az ad user delete --id "$UPN"
  echo "    - deleted $UPN"
else
  echo "    = not found"
fi

echo "==> 6/6 Cleaning up GitHub (repo is kept)"
for SECRET in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID; do
  if gh secret delete "$SECRET" --repo "$GITHUB_REPO" > /dev/null 2>&1; then
    echo "    - removed secret $SECRET"
  else
    echo "    = secret $SECRET not found"
  fi
done
if gh workflow disable deploy.yml --repo "$GITHUB_REPO" > /dev/null 2>&1; then
  echo "    - workflow disabled (re-enable with: gh workflow enable deploy.yml)"
else
  echo "    = workflow already disabled"
fi

echo ""
echo "==> Verification"
echo "    Resource group exists : $(az group exists --name "$RESOURCE_GROUP")   (expect false)"
echo "    Soft-deleted vaults   : $(az keyvault list-deleted --resource-type vault --query "[?starts_with(name, '$KV_PREFIX')] | length(@)" -o tsv)   (expect 0)"
echo "    Pipeline app          : $(az ad app list --display-name "$APP_NAME" --query "length(@)" -o tsv)   (expect 0)"
echo ""
echo "Teardown complete."
