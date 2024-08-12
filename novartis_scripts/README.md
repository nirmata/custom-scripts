## Scripts Overview

The Scripts below 

---

### 1. `novartis_test.sh`
- **Usage**: 
  ```bash
  ./novartis_test.sh --namespace [NAMESPACE] --cluster --node

### Description
This script is used for testing cluster components, including metrics services and all Nirmata non-shared services. 

The --cluster flag is specifically for testing non-shared services.

The --node is specified when testing for pre-requisite and node readiness.

### 2. `./certificate_check.sh`

### Description:
This script checks the certificates for an on-premises Kubernetes cluster to ensure they are valid and not expired.

### 3. `./backup_mongo.sh`
### Description:
This script creates a backup of the MongoDB database.

### 3. `./restore_mongo.sh`
### Description:
This script restores the MongoDB database from a backup created using backup_mongo.sh. It is crucial for recovering data after a loss.