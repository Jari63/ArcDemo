@description('Name of the web application (must be globally unique across Azure)')
param appName string

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('App Service Plan SKU')
@allowed(['F1', 'B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1v3', 'P2v3', 'P3v3'])
param sku string = 'B1'

@description('The .NET runtime version')
param dotnetVersion string = 'DOTNET|10.0'

var planName = '${appName}-plan'

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  sku: {
    name: sku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: dotnetVersion
      alwaysOn: sku != 'F1'
    }
  }
}

output webAppName string = app.name
output webAppUrl string = 'https://${app.properties.defaultHostName}'
