// networking-audit-agent - Infrastructure as Code
// Deploys the Azure SRE Agent resource with managed identity and RBAC

targetScope = 'resourceGroup'

@description('Name of the SRE Agent')
param agentName string = 'networking-audit-agent'

@description('Azure region for the agent deployment')
@allowed([
  'eastus2'
  'swedencentral'
  'australiaeast'
])
param location string = 'eastus2'

@description('Tags to apply to all resources')
param tags object = {
  project: 'networking-audit-agent'
  managedBy: 'bicep'
}

// User-Assigned Managed Identity for the agent
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${agentName}-mi'
  location: location
  tags: tags
}

// Output values needed for agent setup and RBAC
output managedIdentityClientId string = managedIdentity.properties.clientId
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output managedIdentityResourceId string = managedIdentity.id
