This script is used to create teams, catalogs and environments in Nirmata using a file which consists of a list of namespaces.

<ins>**Prerequisites:**</ins>

- Make sure `curl` and `jq` are installed on the machine where you are running this script

<ins>**Usage:**</ins>

Execute the script with the required arguments and provide the Nirmata API token for your tenant. 

Required Arguments:
```sh
$1 - Nirmata URL
$2 - Path to file consisting of namespaces
$3 - Cluster Name
```

<ins>**Note:**</ins> 

The resources in Nirmata are created by appending a string "ea1qa" to the namespace. This can be updated in the script if needed. 

```sh

$ ./create-teams-catalog-env.sh https://nirmata.io namespaces.txt calico-ipip4

Enter the Nirmata API token:

Team "test-namespace1-ea1qa" already exists
Team "test-namespace2-ea1qa" already exists
Team "test-namespace3-ea1qa" already exists
Catalog "test-namespace1-ea1qa" already exists
Catalog "test-namespace2-ea1qa" already exists
Catalog "test-namespace3-ea1qa" already exists
Environment "test-namespace1-ea1qa" created successfully
Environment "test-namespace2-ea1qa" created successfully
Environment "test-namespace3-ea1qa" created successfully


```
