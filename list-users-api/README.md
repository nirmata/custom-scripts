This script is used to list the users from Nirmata with their name, id and configured IdentityProvider. Sample csv file that get generated is provided in the repo for reference

<ins>**Prerequisites:**</ins>

- Make sure `curl` and `jq` are installed on the machine where you are running this script

<ins>**Usage:**</ins>

Execute the script with the required arguments and provide the Nirmata API token for your tenant. 

Required Arguments:
```sh
$1 - Nirmata URL
```

```sh

[root@saas delete-old-users]# ./list-users.sh https://nirmata.io
Enter the Nirmata API token:

-------------------------------------------------
Generating the csv file with the list of users...
-------------------------------------------------

users.csv file generated successfully

```
