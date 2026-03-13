using '../main.bicep'

param agentName = 'networking-audit-agent-dev'
param location = 'eastus2'
param tags = {
  project: 'networking-audit-agent'
  environment: 'dev'
  managedBy: 'bicep'
}
