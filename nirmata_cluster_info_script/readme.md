# Nirmata Cluster Analysis Tool

A bash script to provide detailed information about nodes and cluster status. 

## Features

- Retrieves information about all clusters in your environment
- Identifies master and worker nodes based on Kubernetes labels
- Provides detailed cluster status and creation dates
- Outputs information in JSON format for easy parsing
- Includes node counts and names for both master and worker nodes
- Secure handling of API token input

## Prerequisites

- bash
- curl
- jq
- Access to Nirmata API (URL and API token)

## Installation

1. #### Clone the repository:
```bash
git clone https://github.com/nirmata/custom-scripts.git
cd nirmata_cluster_info_script
```
2. #### Make the script executable:
```bash
chmod +x nirmata_cluster_info.sh
```
3. #### Get Nirmata API Token:
 
- **Login to Nirmata** > **Go to your profile** > **Click on Generate API key** 

4. #### Run the script with your Nirmata URL:
```bash
./nirmata_cluster_info.sh <NIRMATA_URL>
```
5. #### The script will then securely prompt you for your API token:
```bash
Enter the Nirmata API token: [Type your token here]
```
6. #### Get Nirmata API Token:
 
- **Login to Nirmata** > **Go to your profile** > **Click on Generate API key**

7. #### Example:
```bash
ishaanj18@Jarvis:~/novarti/custom-scripts/nirmata_cluster_info_script$ ./nirmata_cluster_info.sh https://pe420.nirmata.co
Enter the Nirmata API token: 
Fetching cluster information...
```
8. #### Script Output: Cluster Information  

The script outputs JSON-formatted information for each cluster, including:  

- **Cluster Name**  
- **Number of Worker Nodes**  
- **Number of Master Nodes**  
- **Names of All Master Nodes**  
- **Names of All Worker Nodes**  
- **Cluster Status**  
- **Creation Date**  
- **Cluster ID**  

Example Output- 
```bash
ishaanj18@Jarvis:~/novarti$ ./new-script-again.sh https://pe420.nirmata.co
Enter the Nirmata API token:
Fetching cluster information...
Processing nodes for cluster: day2-training
{
  "cluster_name": "day2-training",
  "worker_node_count": 0,
  "master_node_count": 1,
  "master_nodes": ["novartis-training-control-plane"],
  "worker_nodes": [],
  "cluster_status": ["Cluster failed.","Cluster has not connected for more than 30 minutes. Last error: Failed to checkClusterConnection. not connected"],
  "creation_date": "2025-02-13 10:16:26 UTC",
  "cluster_id": "4bafa32f-0dff-4050-a105-dcb442211fff",
  "cluster_type": "default-addons-type"
}
----------------------------------------
Processing nodes for cluster: duke-test
{
  "cluster_name": "duke-test",
  "worker_node_count": 0,
  "master_node_count": 1,
  "master_nodes": ["duke-test-control-plane"],
  "worker_nodes": [],
  "cluster_status": ["Validating cluster settings"],
  "creation_date": "2025-02-13 15:10:30 UTC",
  "cluster_id": "b5302919-ead1-41c5-b607-68896d4531bb",
  "cluster_type": "default-addons-type"
}
----------------------------------------
Processing nodes for cluster: duktest
{
  "cluster_name": "duktest",
  "worker_node_count": 0,
  "master_node_count": 1,
  "master_nodes": ["duk-control-plane"],
  "worker_nodes": [],
  "cluster_status": ["Cluster failed.","Cluster has not connected for more than 30 minutes. Last error: Failed to checkClusterConnection. not connected"],
  "creation_date": "2025-02-15 04:35:47 UTC",
  "cluster_id": "e60cc730-d1ab-40fc-b4fb-3605586e4139",
  "cluster_type": "default-addons-type"
}
----------------------------------------
Processing nodes for cluster: novartis-v129
{
  "cluster_name": "novartis-v129",
  "worker_node_count": 1,
  "master_node_count": 1,
  "master_nodes": ["ip-10-20-0-220.us-west-1.compute.internal"],
  "worker_nodes": ["ip-10-20-0-41.us-west-1.compute.internal"],
  "cluster_status": ["Validating cluster settings"],
  "creation_date": "2025-02-19 04:16:29 UTC",
  "cluster_id": "41c5145e-7611-42d8-9d5a-4466fa2d86f9",
  "cluster_type": "default-v1.29.3"
}

```