// RBAC role assignments for the networking-audit-agent managed identity
// Deploy this at subscription scope for each subscription the agent needs access to

targetScope = 'subscription'

@description('Principal ID of the agent managed identity')
param principalId string

@description('Role assignments to create. Default: Reader + Network Contributor')
param roles array = [
  {
    name: 'Reader'
    id: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  }
  {
    name: 'Network Contributor'
    id: '4d97b98b-1d4f-4787-a291-c67834d212e7'
  }
]

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roles: {
    name: guid(subscription().id, principalId, role.id)
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.id)
      principalId: principalId
      principalType: 'ServicePrincipal'
    }
  }
]
