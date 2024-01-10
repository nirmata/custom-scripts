# Nirmata Applications List in Environments Script

This Bash script creates a csv file which lists the applications found in each environment. 

## Prerequisites

Before using this script, ensure that you have the following values:

- Tenant ID (which can be found in nirmata.io > profile > account)
- MongoDB pod which is the primary mongo pod.

## Usage

To use the script, run the following command:

```bash
curl -O https://raw.githubusercontent.com/nirmata/custom-scripts/nova/show-env-apps-nirmata/env_app.sh && chmod +x env_app.sh
./env_app.sh <TenantID> <MongoPod>
```
The script will iterate through all connected clusters and check for applications in environments.

## Example

Here's an example of how to use the script:

```bash
./env_app.sh ye83h-e7dj-u373-id8f-83rbbgb mongodb-0
```
The script will create a csv file called 'output.csv' as well as a txt file called 'result.txt' with all the environments and applications under each environment. 
