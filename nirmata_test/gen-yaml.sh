kubectl -n nirmata create configmap  nirmata-test-script --from-file=nirmata_test.sh -o yaml  --dry-run=client >cronjob-yaml/nirmata-test-script.yaml
# Older kubectl
#kubectl -n nirmata create configmap  nirmata-test-script --from-file=nirmata_test.sh -o yaml  --dry-run >cronjob-yaml/nirmata-test-script.yaml
