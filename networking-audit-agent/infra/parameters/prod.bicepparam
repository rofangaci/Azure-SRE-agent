using '../main.bicep'

param agentName = 'networking-audit-agent'
param location = 'eastus2'
param tags = {
  project: 'networking-audit-agent'
  environment: 'prod'
  managedBy: 'bicep'
}
