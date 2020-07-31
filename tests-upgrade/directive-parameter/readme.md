### AutoRest Configuration
> see https://aka.ms/autorest

``` yaml
require:
  - $(this-folder)/../readme.azure.noprofile.md
input-file:
  - $(this-folder)/swagger.json

directive:
  - where:
      parameter-name: Sku
    set:
      parameter-name: SkuName
  - where:
      verb: Get
      subject: VirtualMachine
      parameter-name: VirtualMachineName
    set:
      parameter-name: Name
  - Where:
      parameter-name: (.*)Name$
    set:
      parameter-name: Name
  - where:
      parameter-name: VirtualMachine
    set:
      alias:
        - VM
        - VMachine
  - where:
      parameter-name: ResourceGroupName
      verb: Get
      subject: Operation
    set:
      parameter-description: This is resource group name.
  - where:
      parameter-name: SubscriptionId
    set:
      default:
        name: SubscriptionId Default
        description: Gets the SubscriptionId from the current context.
        script: '(Get-AzContext).Subscription.Id'
```
