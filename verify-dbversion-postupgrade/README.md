### Introduction

DBVersion for all the mongodb databases need to be verified post Nirmata PE upgrade to ensure the upgrade was successful. This script compares the DBVERSION values of mongodb databases against the expected values based on the PE version and reports if there are any discrepencies. Before executing the script, update the expected values of DBVERSIONS for different databases based on the PE version you are upgrading in the script. 


### Usage: 

```sh
./verify-dbversion-post-peupgrade.sh <namespace>

```
