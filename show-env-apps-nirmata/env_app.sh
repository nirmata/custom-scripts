#!/bin/bash
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 tenantID mongoMaster"
    exit 1
fi
tenant=$1
mongo_master=$2

# First, we get the clusters
#Managed only has been commented out
#kubectl -n nirmata exec $mongo_master -it -- mongo Cluster-nirmata --quiet --eval "db.KubernetesCluster.find({'tenantId':'${tenant}','mode':'managed'},{'_id':1,'name':1})" > cluster.txt
kubectl -n nirmata exec $mongo_master -it -- mongo Cluster-nirmata --quiet --eval "db.KubernetesCluster.find({'tenantId':'${tenant}'},{'_id':1,'name':1})" > cluster.txt

#now extract only the cluster_id
grep -E '"_id" : "([^"]+)"\s*,\s*"name" : "([^"]+)"' cluster.txt | sed -E 's/.*"_id" : "([^"]+)"\s*,\s*"name" : "([^"]+)".*/\1 \2/' > cluster_data.txt
awk '{print $1}' cluster_data.txt > cluster_id_only.txt

clusters=()
while IFS= read -r cluster_id; do
  clusters+=("$cluster_id")
done < cluster_id_only.txt

#get the cluster id from environments db
for cluster_id in "${clusters[@]}"; do
     kubectl -n nirmata exec -it $mongo_master -- mongo Environments-nirmata --quiet --eval "db.Cluster.find({'clusterRef.id':'$cluster_id'},{'_id':1,'name':1})"
done > env.txt

#get ids
grep -E '"_id" : "([^"]+)"\s*,\s*"name" : "([^"]+)"' env.txt | sed -E 's/.*"_id" : "([^"]+)"\s*,\s*"name" : "([^"]+)".*/\1 \2/' > env_data.txt
awk '{print $1}' env_data.txt > env_id_only.txt

env=()
while IFS= read -r env_id; do
  env+=("$env_id")
done < env_id_only.txt

#get all the applications and environments
for env_id in "${env[@]}"; do
    kubectl -n nirmata exec -it $mongo_master -- mongo Environments-nirmata --quiet --eval "db.Environment.find({'cluster.id':'$env_id'}).forEach(function(env) {var envName = env.name; db.Application.find({'parent.id':env._id}).forEach(function(app) {print('Application ' +app.name+' in environment '+envName); })})"
done > app_env.txt

grep -oP 'Application \K\S+ in environment \K\S+' app_env.txt | awk '{count[$2][$1]++} END {for (env in count) {print "Count of all Applications in each environment:", env; for (app in count[env]) print app, " :: Applications Count:", count[env][app]; print ""}}' > count.txt

#presenting all apps under an environment
input_file="app_env.txt"

declare -A environments
declare -A applications

# Read the file line by line
while IFS= read -r line; do
  environment=$(echo "$line" | awk '{print $NF}')
  application=$(echo "$line" | awk '$1=$1' | awk -F ' in environment ' '{print $1}')

  # Populate environments and applications arrays
  environments["$environment"]=1
  applications["$environment"]+=" $application"$'\n'
done < "$input_file"

# Print unique environments and their corresponding applications
for env in "${!environments[@]}"; do
  echo "Environment  : $env"
  echo -e "${applications[$env]}"
done > apps.txt

#FORMATTING
cat count.txt > result.txt
echo " " >> result.txt
echo "********************************************" >> result.txt
echo " " >> result.txt
cat apps.txt >> result.txt

# First, write the header to the output.csv
echo "Environment,Total Applications Count,Application Names" > output.csv

# Process applications and environments for counts and names
awk -F ' in environment ' '
{
  app_name = $1;
  gsub(/^Application /, "", app_name);
  env_name = $2;
  apps[env_name][app_name]++;
  envs[env_name]++;
}
END {
  for (env in envs) {
    printf("%s,%d,", env, envs[env]);
    first = 1;
    for (app in apps[env]) {
      if (!first) printf(";");
      first = 0;
      printf("%s", app);
    }
    print "";
  }
}' app_env.txt >> output.csv

echo ""
echo "********************************************"
echo ""
echo "CSV file 'output.csv' has been created with environment, total applications count, and application names."
echo "We have also provided the same in txt format using results.txt file"

# Cleanup
rm cluster_id_only.txt cluster_data.txt cluster.txt env.txt env_data.txt env_id_only.txt app_env.txt count.txt apps.txt
