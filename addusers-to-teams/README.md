This script is used to add new and existing users to teams in Nirmata using a csv file which consists of a namespaces, usernames and email addresses. Any users and teams that do not exist in the csv file are created by this script.

<ins>**Prerequisites:**</ins>

- Make sure `curl` and `jq` are installed on the machine where you are running this script

<ins>**Usage:**</ins>

Execute the script with the required arguments and provide the Nirmata API token for your tenant. 

Required Arguments:
```sh
$1 - Nirmata URL
$2 - Path to csv file consisting of namespaces, username and email (See example csv file for reference)

```

```sh

[root@nibr1 tmp]# ./addusers-teams_v2.sh https://nirmata.io sample-file.csv

Enter the Nirmata API token:

Team "nirmata1-ea1qa-team" created successfully

User "sagar-devops2" getting added to below team ids
"687bc65f-10cd-4567-b2c1-7fff72a7fabb"
"893bcecc-7c92-4653-9c5e-364980ab9428"
"897b7c6e-31e1-4278-8841-fe7b1ffb7f32"
"a9c9c638-79b6-4775-a08b-14354b186216"
User "sagar-devops2" added to teams successfully

User "sagar-devops5" getting added to below team ids
"1e6820db-5531-4d27-a02f-7975f0383aea"
"649675cf-c3e6-4031-87a0-012dda6f27b2"
"6e87339d-0f73-4f23-b89a-85ff762449ec"
User "sagar-devops5" added to teams successfully

User "sagar-devops7" getting added to below team ids
"66f0d91d-c12d-4ecd-bc10-bd6d766068ee"
"cb5590a5-df29-4fd4-acfb-7b464a55e692"
"e4c42020-c6e6-4c99-859c-dc1d06597853"
User "sagar-devops7" added to teams successfully



```

