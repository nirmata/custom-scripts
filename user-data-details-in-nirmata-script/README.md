This script is used to Fetch User Details,Cluster and Environment Permissions for the DevOps and Platform Users from Nirmata UI.

<ins>**Usage:**</ins>
- Make sure you have `Python3`,`curl` and `jq` installed on the machine where you are running this script
- The script takes two arguments as input : `./userdetails-permissions.sh <Nirmata-API-Token> <Nirmata-URL>`
        
        - `Nirmata-API-Token`: Nirmata-API-Token
        - `Nirmata-URL`: Nirmata-URL
        - `Example`: `./userdetails-permissions.sh <Nirmata-API-Token> <Nirmata-URL>`

- Run the combine_csv.py
        - `python3 combine_csv.py`
- Final output is stored in `output_combined.csv`

