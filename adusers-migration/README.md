# Bash script to copy permissions between teams in Nirmata

This folder contains a script to copy permissions from source team to target team in Nirmata. The script takes few arguments like `FILE (csvfile)`, `NIRMATAURL`, `TOKEN` and they have to be updated in the script as per your environment. A sample csv file  provided in this repo can be used as a reference.

## Prerequisites
- `curl` and `jq`

## Usage
```sh
nohup bash fix-issue.sh > output.log 2>&1 &
```
To verify the script output, the log file can be tailed using the command below

```sh
tail -20f output.log
```
