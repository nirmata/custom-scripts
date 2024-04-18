The script used in this repo is used to fetch the serverURL from the imagePullSecret used by the deployment. This will help you to identify if the serverURL in the secret needs to be updated to the new URL. 

## Prerequisites

- A Kubernetes cluster
- jq
## Usage: 

```
$ ./get-nexus-info.sh

Namespace      | Type           | Name                          | Server URL                    | Policy                   | Update Needed
admsdev        | Deployment     | sample-nginx                  | nexus.duke-energy.com:18079   | Always                   | Yes
default        | Deployment     | test                          | DOCKER_REGISTRY_SERVER        | Always                   | Yes

```
