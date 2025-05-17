@description('Creates a private endpoint to Cosmos DB in the dbSubnet.')
param cosmosDbAccountId string
param vNetName string
param dbSubnetName string
param location string = resourceGroup().location
param tags object = {}

var cosmosDbPrivateDnsZoneName = 'privatelink.documents.azure.com'

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vNetName
}

// Cosmos DB Private DNS Zone
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: cosmosDbPrivateDnsZoneName
  location: 'global'
  tags: tags
}

// Link DNS zone to VNet
resource dnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${vNetName}-cosmos-link'
  parent: privateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
  tags: tags
}

resource dbSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vnet
  name: dbSubnetName
}

resource cosmosPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: 'db-private-endpoint'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: dbSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'cosmosdb-connection'
        properties: {
          privateLinkServiceId: cosmosDbAccountId
          groupIds: ['Sql']
        }
      }
    ]
  }
  dependsOn: [
    privateDnsZone
    dnsZoneVnetLink
  ]
}

output privateEndpointId string = cosmosPrivateEndpoint.id
