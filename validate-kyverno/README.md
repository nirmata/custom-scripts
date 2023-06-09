 # Bash script to verify the Kyverno deployment

#### Prerequisites:
    - A Kubernetes Cluster with Kyverno installed.
    - Kubectl access to the cluster.
    - A linux or Mac machine to execute the script.

#### Usage: 
```
$ ./kyverno-baseline.sh

=========================================
Current Kyverno Deployment Status
=========================================

Kubernetes Version: v1.23.17-eks-a59e1f0

Kyverno Deployment Version
 - kyverno-license-manager:v0.0.2
 - kyverno:v1.9.2-n4k.nirmata.1
 - kyvernopre:v1.9.2-n4k.nirmata.1
 - kyverno-license-manager:v0.0.2
 - cleanup-controller:v1.9.2-n4k.nirmata.1

Cluster Size Details
 - Number of Nodes in the Cluster: 11
 - Number of Pods in the Cluster: 145

Total Number of Kyverno ClusterPolicies in the Cluster: 12
Cloud Provider/Infrastructure: AWS

Total size of the etcd database file physically allocated in bytes:
etcd_db_total_size_in_bytes{endpoint="https://168.254.5.3:2379"} 4.964352e+06

Top objects in etcd:
# HELP apiserver_storage_objects [STABLE] Number of stored objects at the time of last check split by kind.
# TYPE apiserver_storage_objects gauge
apiserver_storage_objects{resource="events"} 472

Kyverno Replicas:
 - 3 replicas of Kyverno found

Kyverno Pod status:
NAME                                         READY   STATUS    RESTARTS   AGE
kyverno-55d799bb47-4t24s                     2/2     Running   0          9d
kyverno-55d799bb47-bl2wd                     2/2     Running   0          9d
kyverno-55d799bb47-qf2vs                     2/2     Running   0          9d
kyverno-cleanup-controller-5b8c57465-9ffnn   1/1     Running   0          9d

Kyverno CRD's:
 - admissionreports.kyverno.io
 - backgroundscanreports.kyverno.io
 - cleanuppolicies.kyverno.io
 - clusteradmissionreports.kyverno.io
 - clusterbackgroundscanreports.kyverno.io
 - clustercleanuppolicies.kyverno.io
 - clusterpolicies.kyverno.io
 - clusterpolicyreports.wgpolicyk8s.io
 - clusterreportchangerequests.kyverno.io
 - generaterequests.kyverno.io
 - kyvernoadapters.security.nirmata.io
 - kyvernoes.security.nirmata.io
 - kyvernooperators.security.nirmata.io
 - openshiftkyvernooperators.operator.nirmata.io
 - policies.kyverno.io
 - policyexceptions.kyverno.io
 - policyreports.wgpolicyk8s.io
 - reportchangerequests.kyverno.io
 - updaterequests.kyverno.io

Kyverno ValidatingWebhook Deployed:
 - kyverno-cleanup-validating-webhook-cfg
 - kyverno-exception-validating-webhook-cfg
 - kyverno-operator-validating-webhook-configuration
 - kyverno-policy-validating-webhook-cfg
 - kyverno-resource-validating-webhook-cfg

Kyverno MutatingWebhooks Deployed:
 - kyverno-policy-mutating-webhook-cfg
 - kyverno-resource-mutating-webhook-cfg
 - kyverno-verify-mutating-webhook-cfg

Fetching "admissionreports" for the cluster

NAMESPACE        NAME                                   PASS   FAIL   WARN   ERROR   SKIP   AGE
backup-mongodb   061164e3-6f79-4a0a-9900-799c2609bf39   13     0      0      0       0      11h
backup-mongodb   26bdaa5f-e45e-4f2b-a45b-1131d3eca15e   13     0      0      0       0      17h
backup-mongodb   8873ebe1-b5a3-4be7-b635-9ef84a5607f2   13     0      0      0       0      5h4m
backup-mongodb   f78258ef-a575-4441-b445-ef6df5f24c4f   13     0      0      0       0      23h
monitoring       00388474-292b-465c-9045-7ce987c53570   13     0      0      0       0      27h
nirmata          642d3443-cac6-42ff-801f-0923dc271434   13     0      0      0       0      8d
prod             0e917622-070f-4408-8891-44825c065760   13     0      0      0       0      4d1h
prod             148704fa-3680-4d16-9b11-c5183b93ca9f   13     0      0      0       0      54m
prod             1bd4a9bb-ddf5-4d1a-af4e-f0c458425c57   13     0      0      0       0      4d1h
prod             1f79850a-a9fc-4e71-8735-5574fade1190   13     0      0      0       0      4d1h
prod             22ce5792-6998-4606-b1c7-8a7c97352f09   13     0      0      0       0      4d1h
prod             3494000a-e2d1-49cd-95c6-72b626e5b1a6   13     0      0      0       0      4d1h
prod             3e37cea7-fc2f-4daf-a120-85a5b5e71300   13     0      0      0       0      4d1h
prod             4047cbbf-9bf9-491f-9854-3cdad8387307   13     0      0      0       0      4d1h
prod             4e7307d6-d179-4e94-95b5-15d0941a118d   13     0      0      0       0      4d1h
prod             61022a27-6505-4304-9b02-bd02dc928d47   13     0      0      0       0      4d1h
prod             61995792-0d04-48d0-9615-ddd0a38576c5   13     0      0      0       0      61m
prod             7007536e-9e5f-4fde-bea2-3ed0525a3c64   13     0      0      0       0      4d1h
prod             7e75189f-fa74-423e-ac07-1bafc8b64ed9   13     0      0      0       0      4d1h
prod             8ec14409-4a26-4291-acc2-d9941cfda8e7   13     0      0      0       0      4d1h
prod             903593d8-88f1-4a59-b0ee-2555e64e9437   13     0      0      0       0      3d9h
prod             9ba406d0-c386-4e74-8c93-1e499192953f   13     0      0      0       0      4d1h
prod             a690fe30-a729-4e42-8eec-197122f79f7e   13     0      0      0       0      58m
prod             b4718655-6019-4053-99ab-67ec7cb80cce   13     0      0      0       0      4d1h
prod             bb86d54c-9021-4010-8180-f359d390272b   13     0      0      0       0      51m
prod             bb8d84f8-1176-42df-b09e-160e9acf761c   13     0      0      0       0      59m
prod             bec46c34-cccb-4dd2-a6a2-897df1d9713c   13     0      0      0       0      62m
prod             bfbd6539-3aa1-420a-8978-ad1f6a4e5685   13     0      0      0       0      64m
prod             c3ce2983-8693-4718-abec-0704d9fb234e   13     0      0      0       0      50m
prod             cab6f84c-6d73-40e1-bab0-f8894f2b0503   13     0      0      0       0      4d1h
prod             cadbc263-19c9-4202-9621-49579b308b94   13     0      0      0       0      58m
prod             cf07fb76-2d3e-4570-ad50-7142e3b53b0a   13     0      0      0       0      45h
prod             d0803f7d-9aee-4fef-b5bb-034d139cd333   13     0      0      0       0      4d1h
prod             d2c5facb-6ada-40c5-be88-420967baaf8c   13     0      0      0       0      2d1h
prod             e086e950-3c3b-43de-a647-691b925e9d34   13     0      0      0       0      4d1h
prod             e5f87645-f4bb-4f06-ae2b-33588f1b815c   13     0      0      0       0      4d1h
prod             e729e01a-6a18-4e37-abe8-bcaa0508411a   13     0      0      0       0      52m
prod             ece2b2b7-bfb1-4dbe-a338-11be9c352290   13     0      0      0       0      4d1h
prod             f29e1fb2-4e56-4902-8329-caa0a66467ff   13     0      0      0       0      4d1h
prod             f31af00b-94ee-460d-b8e1-8f4ade3c4804   13     0      0      0       0      4d1h
prod             ff7015ac-a04e-4b13-a03d-7968646bd7db   13     0      0      0       0      2d1h

Fetching "backgroundscanreports" for the cluster

NAMESPACE                     NAME                                   PASS   FAIL   WARN   ERROR   SKIP   AGE
amazon-cloudwatch             020e096c-211b-4dac-a6e3-6678303d04de   12     1      0      0       0      9d
amazon-cloudwatch             1a8741ab-b196-4343-88ea-749e3140b353   12     1      0      0       0      9d
amazon-cloudwatch             27eafc94-5ec7-4790-b40f-bd88dc657a4e   12     1      0      0       0      9d
amazon-cloudwatch             3bc45b96-ed31-4428-ac60-8538dfcc89f4   12     1      0      0       0      9d
amazon-cloudwatch             54a3433a-cabf-447a-81f2-810364e5c419   12     1      0      0       0      9d
amazon-cloudwatch             742d98e6-2b36-4b68-84ab-bc6668d12244   12     1      0      0       0      9d
amazon-cloudwatch             8464d3cc-71a0-4d43-929d-a68b2dbf06e5   12     1      0      0       0      9d
amazon-cloudwatch             93732e1b-6456-4748-9a56-2ef27dc201ea   12     1      0      0       0      9d
amazon-cloudwatch             9ed3b2e2-cf54-4bfb-a36a-d0fd6cb51f5e   12     1      0      0       0      9d
amazon-cloudwatch             bb687516-931a-44b1-a35c-a62de87bd6e0   12     1      0      0       0      9d
amazon-cloudwatch             d64923c1-984c-4128-bd9d-72985b26b18e   12     1      0      0       0      9d
amazon-cloudwatch             e7d71167-95d2-496e-9527-df8a51ea9321   12     1      0      0       0      9d
backup-mongodb                061164e3-6f79-4a0a-9900-799c2609bf39   13     0      0      0       0      11h
backup-mongodb                09d1842f-74b0-4ce6-bad3-8da75c9820c4   13     0      0      0       0      9d
backup-mongodb                0d6b6db8-50a7-4d36-8a90-2e35b0cd24ac   13     0      0      0       0      9d
backup-mongodb                10baee4b-b702-4317-9e95-26a6a25a94a9   13     0      0      0       0      9d
backup-mongodb                220f78d7-87b2-4c8a-96a3-ce3441476c80   13     0      0      0       0      9d
backup-mongodb                26bdaa5f-e45e-4f2b-a45b-1131d3eca15e   13     0      0      0       0      17h
backup-mongodb                2c7c6fc5-7778-4c3b-b943-271ff425a96d   13     0      0      0       0      9d
backup-mongodb                3c9491ef-9e6c-46ca-a98a-36d88c101120   13     0      0      0       0      23h
backup-mongodb                469eca61-2ebb-4b1f-ae4c-6c60f6ddba08   13     0      0      0       0      9d
backup-mongodb                4b79fc87-d457-47b5-9970-abaf99110aa3   13     0      0      0       0      9d
backup-mongodb                5ef7b289-2a22-4bf8-ad9c-d0d660a8b8cf   13     0      0      0       0      5h3m
backup-mongodb                693cb2b1-4666-4bf2-9e21-530aa083a9d3   13     0      0      0       0      9d
backup-mongodb                7aa4af70-3bbe-4b14-acc1-3c9de3834fe1   13     0      0      0       0      9d
backup-mongodb                8873ebe1-b5a3-4be7-b635-9ef84a5607f2   13     0      0      0       0      5h3m
backup-mongodb                8d42ce2e-1272-41c5-8082-d14ef438c7a7   13     0      0      0       0      9d
backup-mongodb                99997660-6627-4b4f-ae2f-34ec325524a0   13     0      0      0       0      9d
backup-mongodb                b13f82c3-268f-49f2-a15f-6c42f5d845cc   13     0      0      0       0      9d
backup-mongodb                b1553c26-b72f-457c-840c-a7ae3ea7294c   13     0      0      0       0      9d
backup-mongodb                b28ec77a-6be7-425c-b666-3edf6d3172e8   13     0      0      0       0      11h
backup-mongodb                b3bea0f5-d2fa-4c57-ad66-f33cfce1b5e5   13     0      0      0       0      9d
backup-mongodb                bef1ae23-ec49-4aa3-9fed-dc2b3c699a24   13     0      0      0       0      9d
backup-mongodb                e2014d70-21ec-4aa6-96f9-d9e3995c0fe8   13     0      0      0       0      9d
backup-mongodb                e38d153a-92f2-47fa-932c-95c2ed90662a   13     0      0      0       0      17h
backup-mongodb                f1815694-43c2-4665-9cdf-acd5ba8dad1a   13     0      0      0       0      9d
backup-mongodb                f78258ef-a575-4441-b445-ef6df5f24c4f   13     0      0      0       0      23h
backup-mongodb                fd18bd64-e8b5-481b-aabb-48f559d758a4   13     0      0      0       0      9d
enterprise-kyverno-operator   0db598b7-f466-499b-addf-73c5f1267099   13     0      0      0       0      9d
enterprise-kyverno-operator   25007eba-78fd-4544-a610-e4c4090e0684   13     0      0      0       0      9d
enterprise-kyverno-operator   cc2ab3c5-c119-491c-b8c2-ff2f7ce821de   13     0      0      0       0      9d
kube-system                   04d74b82-531e-480c-b853-f901a2d1f6c3   7      6      0      0       0      9d
kube-system                   0a6acbdc-74b0-4875-98d6-0869b1f46f5b   12     1      0      0       0      9d
kube-system                   11cfdc0f-4716-485d-9bae-132f6b636388   13     0      0      0       0      9d
kube-system                   14d12d85-3bd0-495c-83b9-b81922239842   12     1      0      0       0      9d
kube-system                   17de6859-ed0c-4544-a0d9-614ac356219e   11     2      0      0       0      9d
kube-system                   191e0715-8dc3-4c58-add8-ba3ab510550d   12     1      0      0       0      9d
kube-system                   19fdb08b-e66d-4702-ba7c-4a9991dfa2b0   13     0      0      0       0      9d
kube-system                   22917615-97b6-4824-95b0-ea34f5ff9268   13     0      0      0       0      9d
kube-system                   239ec17f-0c8a-4327-919a-7fb99d6d0be4   13     0      0      0       0      9d
kube-system                   24276450-db74-45ed-95f7-2c704db7b948   10     3      0      0       0      9d
kube-system                   2745a679-f984-45b2-a9b0-1b5ad4a81555   7      6      0      0       0      9d
kube-system                   2fdfa58e-8057-4da1-9f7d-dc2376586a7c   10     3      0      0       0      9d
kube-system                   306d0e08-9234-4d94-8254-5c822d6f0a2f   13     0      0      0       0      9d
kube-system                   31e5c31d-230a-49e2-8b89-91aad66a54c5   12     1      0      0       0      9d
kube-system                   39c9e4ee-70ae-4695-9a64-de503be03335   7      6      0      0       0      9d
kube-system                   3b0cce38-46fb-4734-801c-bb45d21892de   11     2      0      0       0      9d
kube-system                   405941b1-53a7-4c08-a0e5-6bd71998c1b5   12     1      0      0       0      9d
kube-system                   431ada8e-9f7e-48bb-98ac-84f60272f674   11     2      0      0       0      9d
kube-system                   466a7f60-c57d-4378-b137-28deb3c86807   10     3      0      0       0      9d
kube-system                   4709fae8-a356-407a-bd96-8c8fbbc72a01   10     3      0      0       0      9d
kube-system                   4775dc94-3620-47af-8c25-67ab6b334ab2   12     1      0      0       0      9d
kube-system                   489da841-2cc5-40fc-9034-defe971bda8e   10     3      0      0       0      9d
kube-system                   4bfcc96f-24f3-4e67-9851-c22dcacfcbdc   7      6      0      0       0      9d
kube-system                   506b9683-e26b-4ba1-bb95-389c6911e8d5   11     2      0      0       0      9d
kube-system                   57901824-a571-47e9-b4be-3a54ce7d26c7   11     2      0      0       0      9d
kube-system                   5c4bca9b-17c2-42ea-9848-9b806fe5b6ec   10     3      0      0       0      9d
kube-system                   604e2153-e08c-444b-9413-21215e1fb605   13     0      0      0       0      9d
kube-system                   630068df-3750-43c1-9e7f-ecdba88925fd   11     2      0      0       0      9d
kube-system                   631847c0-4019-4c78-8584-bbd459d5d143   13     0      0      0       0      9d
kube-system                   63db6a76-b89c-4cd4-bfe0-6afc64d800e5   10     3      0      0       0      9d
kube-system                   68336fec-4a27-4cb2-a7da-06ba8dec42c2   13     0      0      0       0      9d
kube-system                   748b3e0f-095a-4293-97b1-30e8e3f72717   13     0      0      0       0      9d
kube-system                   77cdcd57-0c85-4b8c-ab83-6fa3e596b73d   11     2      0      0       0      9d
kube-system                   77da1500-9900-4cf9-abbb-2c40a2ad6306   7      6      0      0       0      9d
kube-system                   79f5cd38-152c-4fb8-bffc-2a5e9b961407   13     0      0      0       0      9d
kube-system                   7e2b9fb4-a120-4e38-bd5a-d63ced2f5014   13     0      0      0       0      9d
kube-system                   84d2ea54-3c55-4157-afc5-9502bbf686f0   11     2      0      0       0      9d
kube-system                   854bd5d2-682c-406f-8d37-c4c2fd1ec7f8   13     0      0      0       0      9d
kube-system                   857dd60c-5545-468c-b04a-ecfb5430ea49   12     1      0      0       0      9d
kube-system                   895f581d-e7c4-417a-a044-1a2552eecccd   11     2      0      0       0      9d
kube-system                   8d07c444-75d7-405e-a1a3-6615adcb85f6   12     1      0      0       0      9d
kube-system                   920fde70-7748-4a29-ada5-0560f5441c50   12     1      0      0       0      9d
kube-system                   96cc9018-481b-4d07-8c48-5d845fe23c69   13     0      0      0       0      9d
kube-system                   98d2d856-f587-4512-b9fc-d2e52b2d4643   7      6      0      0       0      9d
kube-system                   98e3426a-b83a-4825-b195-7d81df101beb   13     0      0      0       0      9d
kube-system                   9a8d6acc-4697-4a87-9433-63d3c04dfe7b   7      6      0      0       0      9d
kube-system                   9ce656e0-58a2-4acd-91aa-bebf7b63fa6b   13     0      0      0       0      9d
kube-system                   a168c4ef-8e5e-4c17-ac46-575b39ef22fb   12     1      0      0       0      9d
kube-system                   a3b8619d-9119-4c95-9e4e-2d9e9a5b367f   7      6      0      0       0      9d
kube-system                   a3ba6eba-d7ce-4cca-b9de-807871cfe103   7      6      0      0       0      9d
kube-system                   a7981b08-fe32-40dc-9ef4-cedc84e08d6f   13     0      0      0       0      9d
kube-system                   a8a11ac0-c858-44c4-a186-9811be683373   7      6      0      0       0      9d
kube-system                   ab6a1107-1ab0-4623-81a2-744c01c1fa77   11     2      0      0       0      9d
kube-system                   b13d38f6-d4fa-4647-a13a-f0be4fa84d0a   13     0      0      0       0      9d
kube-system                   b5fb8006-18b4-4205-92da-bee3397419a4   10     3      0      0       0      9d
kube-system                   b9060404-71b4-4f19-9f81-71c5746bd5d8   11     2      0      0       0      9d
kube-system                   baeff08b-e803-4b89-9efa-13f20f9b1b30   7      6      0      0       0      9d
kube-system                   c0b8bb3c-463b-4144-963e-449d349a3ba0   11     2      0      0       0      9d
kube-system                   c46872d1-85b7-4008-a51d-d2a8be5251ef   7      6      0      0       0      9d
kube-system                   c54917c4-e3d4-4470-9508-d63c113920ab   10     3      0      0       0      9d
kube-system                   d1778ec7-273c-4228-b5a2-7e4d98abdd83   13     0      0      0       0      9d
kube-system                   d36b5953-e7ac-4cc5-a9d1-e49e9eca97fc   10     3      0      0       0      9d
kube-system                   d822c05a-b38a-4faa-b3f7-8751b5815bc5   10     3      0      0       0      9d
kube-system                   d8498737-8872-4276-ac39-7d1cc8e814d8   13     0      0      0       0      9d
kube-system                   de33027e-5ea6-4b67-afbb-5bc997cffd6d   12     1      0      0       0      9d
kube-system                   dfc6c991-adc2-4201-be5d-38a06a22d568   13     0      0      0       0      9d
kube-system                   eb196fd0-a644-48d1-a936-c216233ddf12   12     1      0      0       0      9d
kube-system                   eb85b108-255d-42be-95c7-2c02d39d3ea6   12     1      0      0       0      9d
kube-system                   f0ed236f-3cd7-49f1-8215-6660e35b6d4c   13     0      0      0       0      9d
kube-system                   f623fafd-55b8-4802-88bf-522cc79fafc3   10     3      0      0       0      9d
kube-system                   fb3083b6-efbf-4d1b-a85e-5deb59294c35   13     0      0      0       0      9d
kyverno                       01254507-f230-4adf-984a-384a3f6e4876   13     0      0      0       0      9d
kyverno                       0f844e2a-5ab1-42de-ae12-9f654005cf0f   13     0      0      0       0      9d
kyverno                       2fb0367d-620d-4354-8452-9e4378057751   13     0      0      0       0      9d
kyverno                       4e273aec-a6ee-4159-940b-9cd7c816df99   13     0      0      0       0      9d
kyverno                       53942fc8-b00b-49c9-acb3-773ecc2914f8   13     0      0      0       0      9d
kyverno                       5c464194-be63-40c8-8d98-72e3a6daf94f   13     0      0      0       0      9d
kyverno                       6c033e99-274e-48af-9661-5731c6e3a3f9   13     0      0      0       0      9d
kyverno                       7350f2de-3d54-41a5-8501-a5ca5ffaa92f   13     0      0      0       0      9d
kyverno                       75859b1b-d304-4652-88b3-1921a394d73f   13     0      0      0       0      9d
kyverno                       942c7408-1471-43a5-a29e-9c87956bf1fa   13     0      0      0       0      9d
kyverno                       c9f0dc6b-1e46-4f38-be08-9712e47466c4   13     0      0      0       0      9d
kyverno                       f128a998-2fe3-4084-b9e4-a8afe121111c   13     0      0      0       0      9d
loki-stack                    3488e018-fde1-4ba5-a50e-40a07fac6e10   12     1      0      0       0      9d
loki-stack                    39c6b992-c970-42e5-bf05-d0e40be425e0   12     1      0      0       0      9d
loki-stack                    3d6c7849-59bf-4778-8c7c-9f2310436f26   12     1      0      0       0      9d
loki-stack                    76e69a69-3846-4ea9-a2a5-2c5cac801dd0   12     1      0      0       0      9d
loki-stack                    776ce34d-74aa-4bb8-a9a0-30053394d0bf   12     1      0      0       0      9d
loki-stack                    8a949ed5-eafe-4a0a-a0a3-7714aa511bc6   12     1      0      0       0      9d
loki-stack                    8bf58fd6-7d50-4249-ad98-e4f0127fc38b   12     1      0      0       0      9d
loki-stack                    a96233b6-79db-4ea5-bff0-4c7aaef9f6fa   12     1      0      0       0      9d
loki-stack                    ab49b249-0cb6-4fb2-855e-0836bc8beb41   12     1      0      0       0      9d
loki-stack                    d30a1edb-cf90-462b-bfe9-f3eb4af87d9d   12     1      0      0       0      9d
loki-stack                    e1e683a9-1a5e-46da-ac95-d8270eba2277   12     1      0      0       0      9d
loki-stack                    f42cc324-5501-4799-ab57-6bac4222f160   12     1      0      0       0      9d
monitoring                    00388474-292b-465c-9045-7ce987c53570   13     0      0      0       0      27h
monitoring                    0a4e84e5-c11b-4e3a-939c-3345bb02374a   13     0      0      0       0      9d
monitoring                    0d64838a-062f-43cb-afb8-5cedfbc80a64   13     0      0      0       0      9d
monitoring                    15f6e25d-25a5-48ad-babd-bf206ca3d7be   13     0      0      0       0      9d
monitoring                    2c0d56b6-83bf-424f-9890-6d8d7242809d   13     0      0      0       0      27h
monitoring                    2d420f1f-b5d8-4887-acb9-314ff3eee5a8   13     0      0      0       0      9d
monitoring                    46556e0c-2419-4731-9d3f-24663e919fee   13     0      0      0       0      9d
monitoring                    4f74250f-4182-456b-ae8e-466f4c839502   13     0      0      0       0      9d
monitoring                    5f8ef13f-20e5-4ea4-b12c-8e58cddba87f   13     0      0      0       0      9d
monitoring                    6dc50b42-7025-48a2-a791-802c5b3b5b16   13     0      0      0       0      9d
monitoring                    70849492-4b3e-43de-b518-7bfe4fac7a65   13     0      0      0       0      9d
monitoring                    79f983af-269f-44bc-9ad3-83822cd46f99   13     0      0      0       0      9d
monitoring                    7ce2be45-0a66-4023-a25b-24c6153ac9f4   13     0      0      0       0      9d
monitoring                    9317e9aa-1c62-4f30-b819-507f6898caa0   13     0      0      0       0      9d
monitoring                    96771d48-1958-480c-aa94-887304f42cd1   13     0      0      0       0      9d
monitoring                    99e44986-f819-43dd-b59f-28238a6292d3   13     0      0      0       0      9d
monitoring                    9e06867a-ce1d-43a9-ae11-ce8b4a6c5426   13     0      0      0       0      9d
monitoring                    abf3e4c7-ba5d-430e-bcc5-3fd35a18e341   13     0      0      0       0      9d
monitoring                    acde0379-07ae-4698-9a1d-272cb134c850   13     0      0      0       0      9d
monitoring                    ba5e0368-1fb2-4c3e-adf9-0e0847abfeee   13     0      0      0       0      27h
monitoring                    d4e69d67-2be1-40de-a24c-4d402531e4a8   13     0      0      0       0      9d
monitoring                    d6836eb0-e9e1-4d84-9418-9f1d3a0cb47b   13     0      0      0       0      9d
monitoring                    e4517855-7deb-4757-973d-0c0662e8922c   13     0      0      0       0      9d
monitoring                    e503f520-ab13-499d-8b82-d058e84e2d35   13     0      0      0       0      9d
monitoring                    feb6bb77-f771-46f2-930c-29d70aa215a8   13     0      0      0       0      9d
monitoring                    ff9337ab-b7bb-45bc-a3ef-265affad7e7b   13     0      0      0       0      9d
nirmata-opencost              360a1814-8754-4796-97d7-aa0b4143315d   13     0      0      0       0      9d
nirmata-opencost              4103b992-94f4-461b-8aef-2c17c110b69d   13     0      0      0       0      9d
nirmata-opencost              4a0aa7be-e4cd-4d69-86f7-349c5f897d30   13     0      0      0       0      9d
nirmata-opencost              616e89d3-3487-4a8d-860f-97bc52a04580   13     0      0      0       0      9d
nirmata-opencost              a9e87c65-fdfc-42b0-86b2-5551a7dcc2f2   13     0      0      0       0      9d
nirmata-opencost              d86527d6-feba-4560-a4e0-f4a8f978b31f   13     0      0      0       0      9d
nirmata                       11e0f147-d608-4604-a925-c40eff8caba3   13     0      0      0       0      9d
nirmata                       1227bd0e-b0ef-4d79-9575-73b91d2ea16c   13     0      0      0       0      8d
nirmata                       14654f10-deb1-499a-8a0e-c8dc3ea2eb77   13     0      0      0       0      8d
nirmata                       3bb4b2c4-5c66-4f0c-95c3-a88ae8824f8d   13     0      0      0       0      8d
nirmata                       5a93f7b4-46d8-48b4-9ca1-14a545228187   13     0      0      0       0      8d
nirmata                       642d3443-cac6-42ff-801f-0923dc271434   13     0      0      0       0      8d
nirmata                       731a381c-5f7a-4219-b834-68b28ae54460   13     0      0      0       0      9d
nirmata                       a0d14558-3c94-4378-9846-6555b1dd43e2   13     0      0      0       0      9d
nirmata                       a4ed42cf-091b-44e1-a59d-031393c4b033   13     0      0      0       0      9d
nirmata                       ae5f5b2f-004e-477f-8b2c-b00ac42b2729   13     0      0      0       0      9d
nirmata                       f5a860ba-8300-43d9-898b-60687bb70493   13     0      0      0       0      8d
prod                          009b4d6e-0ec1-437c-945a-aaf3a556467b   13     0      0      0       0      16h
prod                          013ee16e-19bf-491c-ba3b-8c69bc1b3326   13     0      0      0       0      4d1h
prod                          0146f9c4-622c-448c-9567-d4832ac8976a   13     0      0      0       0      9d
prod                          05e1a451-abf7-405b-94cf-c2e0334e5337   13     0      0      0       0      9d
prod                          09471bcd-f0d3-4160-bf1a-a1f2214c7be4   13     0      0      0       0      17h
prod                          0ca9fe63-f5b7-4542-b61b-dc682d131c35   13     0      0      0       0      9d
prod                          0d0b06d1-cb60-45a7-9655-917f3e02a8c6   13     0      0      0       0      9d
prod                          0dd81917-a575-4aaf-902e-e1f9d8c94be1   13     0      0      0       0      9d
prod                          0e917622-070f-4408-8891-44825c065760   13     0      0      0       0      4d1h
prod                          10d65e9d-b0c6-4e81-9f07-4e7aa5e93e31   13     0      0      0       0      7d12h
prod                          1291b234-a3d6-4429-a658-144a29d13792   13     0      0      0       0      9d
prod                          148704fa-3680-4d16-9b11-c5183b93ca9f   13     0      0      0       0      53m
prod                          158215bc-d6de-40a4-9f24-339a5b7839a7   13     0      0      0       0      9d
prod                          18411a8d-8b4b-41a8-9cff-cb09afec8417   13     0      0      0       0      16h
prod                          18e78f59-0236-490f-adb4-d66fd0a890af   13     0      0      0       0      9d
prod                          19f3dbdd-30c7-4bd3-9ce9-aff77288e378   13     0      0      0       0      9d
prod                          1bd4a9bb-ddf5-4d1a-af4e-f0c458425c57   13     0      0      0       0      4d1h
prod                          1f79850a-a9fc-4e71-8735-5574fade1190   13     0      0      0       0      4d1h
prod                          202cd457-0997-4161-9f66-f57bc621554a   13     0      0      0       0      9d
prod                          20390be5-eca9-4a84-834d-2fea4c61d76e   13     0      0      0       0      9d
prod                          22b07488-19c2-47e3-bb26-10e5905e16ee   13     0      0      0       0      9d
prod                          22ce5792-6998-4606-b1c7-8a7c97352f09   13     0      0      0       0      4d1h
prod                          240d1f36-8a02-4c3e-96cc-e8f633f49715   13     0      0      0       0      9d
prod                          252d98e9-1c98-437e-a9aa-66772efc425d   13     0      0      0       0      4d1h
prod                          26ce7337-de2c-490f-81d2-45f8d3db7464   13     0      0      0       0      9d
prod                          278d6c45-1004-4407-9e37-e301563804ad   13     0      0      0       0      9d
prod                          27f59931-3906-4b8c-b92f-2786a6b503ec   13     0      0      0       0      9d
prod                          292e2c2c-de1b-4cac-8658-ec85dd0fbfd4   13     0      0      0       0      9d
prod                          2a8cc7fd-5ca2-4010-9965-cb83145ea412   13     0      0      0       0      9d
prod                          2ab956c2-606b-4ebf-9225-2b510bedeb74   13     0      0      0       0      9d
prod                          2cae586b-f3af-4c24-9d88-f00e42c0f2c0   13     0      0      0       0      4d1h
prod                          32141fb3-aabe-4831-9e2c-4d30d54f3680   13     0      0      0       0      9d
prod                          3494000a-e2d1-49cd-95c6-72b626e5b1a6   13     0      0      0       0      4d1h
prod                          358512ec-0501-475f-87df-9ac72f54a6f2   13     0      0      0       0      9d
prod                          3853a49c-37f0-4b16-a4da-c41fd6c0b81e   13     0      0      0       0      4d1h
prod                          3af758d0-8bbe-4428-9e1a-956f97e71f5a   13     0      0      0       0      9d
prod                          3cbd7fd8-eb0a-4dc6-992d-292a1ac9a4a1   13     0      0      0       0      2d1h
prod                          3dcb9bf1-5b89-471f-a9dd-1c1be9fb5ab3   13     0      0      0       0      9d
prod                          3e37cea7-fc2f-4daf-a120-85a5b5e71300   13     0      0      0       0      4d1h
prod                          3f3044d5-5dab-449c-8fb6-b972397474f8   13     0      0      0       0      4d1h
prod                          4047cbbf-9bf9-491f-9854-3cdad8387307   13     0      0      0       0      4d1h
prod                          425c196c-abb6-48ba-bfd6-964da88d912e   13     0      0      0       0      9d
prod                          43ef8b83-0a13-4f05-9702-977ec0707b46   13     0      0      0       0      9d
prod                          45213bd4-b178-45fe-b806-7d619e00c9b7   13     0      0      0       0      9d
prod                          46150ea3-c6ab-4b11-8873-50253a056662   13     0      0      0       0      9d
prod                          47c2fd51-7aaa-4475-bc83-a4cc17207000   13     0      0      0       0      3d9h
prod                          4825d6b1-cc24-438f-b13b-50c84b258139   13     0      0      0       0      7d12h
prod                          485b210b-819c-4c28-b0b5-4834f9acc549   13     0      0      0       0      4h53m
prod                          49264d17-9647-496c-899e-a9e846e2b4f2   13     0      0      0       0      9d
prod                          4a95afac-a995-4bd6-9664-7b4cb279c7d3   13     0      0      0       0      9d
prod                          4c94c32f-7f57-4356-947d-436792d275ea   13     0      0      0       0      9d
prod                          4e7307d6-d179-4e94-95b5-15d0941a118d   13     0      0      0       0      4d1h
prod                          4fce2d05-9fed-4605-b95d-8f7eed404f98   13     0      0      0       0      20h
prod                          4ff0f195-41b7-415c-8e9a-e59eb636c650   13     0      0      0       0      9d
prod                          50fd37d6-3555-4b35-bc4a-0c60086ea3a9   13     0      0      0       0      9d
prod                          51d6a3f8-fae9-4cde-9d3a-e227276a9878   13     0      0      0       0      9d
prod                          53eaa456-3dd4-47b8-b689-90f4ce5763f0   13     0      0      0       0      9d
prod                          56b3edfa-3f60-497d-b750-e2c343d20a2c   13     0      0      0       0      9d
prod                          58737ee4-40a7-4045-893c-a274b3fd5398   13     0      0      0       0      9d
prod                          5ad73d7b-a458-41fd-9d31-a3f721b92f7a   13     0      0      0       0      9d
prod                          61022a27-6505-4304-9b02-bd02dc928d47   13     0      0      0       0      4d1h
prod                          61995792-0d04-48d0-9615-ddd0a38576c5   13     0      0      0       0      61m
prod                          62c537af-9264-46bf-9c3a-4d0a6768284e   13     0      0      0       0      53m
prod                          66b0a1e2-55a7-450c-b8f0-c16fb5d4c662   13     0      0      0       0      9d
prod                          678e4b05-bc02-4f24-83c3-2cf57724bfe0   13     0      0      0       0      9d
prod                          685b3807-b9b6-402e-b595-ab821e196d54   13     0      0      0       0      4d1h
prod                          6bf4be5e-3a96-4d92-b4b6-087be0f299ad   13     0      0      0       0      9d
prod                          6d714dda-1dee-4679-90dc-18900dfc4520   13     0      0      0       0      9d
prod                          7007536e-9e5f-4fde-bea2-3ed0525a3c64   13     0      0      0       0      4d1h
prod                          71d35c6a-c350-41ac-ab4c-9b84c2aa61a6   13     0      0      0       0      9d
prod                          73be1857-7835-4137-83aa-a3c299b4c54f   13     0      0      0       0      13h
prod                          745dde03-a816-4d38-8908-40fbfc264353   13     0      0      0       0      9d
prod                          777ce387-9782-4c07-a2e5-37de03b2c0e5   13     0      0      0       0      9d
prod                          77cbcf6a-9d05-48b1-a358-507292e65f70   13     0      0      0       0      9d
prod                          782e61f0-3071-4b0a-8ffd-6b82830640df   13     0      0      0       0      9d
prod                          78ca8d3c-f704-415c-b0c3-6f30579b270b   13     0      0      0       0      9d
prod                          7aaf67a9-eb74-41e9-bf7d-a56cc72a4403   13     0      0      0       0      9h
prod                          7abd0dc1-3933-4d1e-99fa-2c7882c708cc   13     0      0      0       0      20h
prod                          7d136353-9d1f-405a-9875-2924323b828d   13     0      0      0       0      9d
prod                          7e75189f-fa74-423e-ac07-1bafc8b64ed9   13     0      0      0       0      4d1h
prod                          7ef26368-13e6-496b-aa3e-6112805998d4   13     0      0      0       0      9d
prod                          7f96d488-2636-4b74-9593-f0133f613017   13     0      0      0       0      4h58m
prod                          8137e9df-af18-4340-ac4d-c9beb86f6cd8   13     0      0      0       0      9d
prod                          84bdee94-5505-4917-bd02-8401edf0625f   13     0      0      0       0      9d
prod                          8697abac-1314-44c6-b8d9-55639c0afd00   13     0      0      0       0      4d1h
prod                          87a55993-976c-4dcd-9ccc-b00363fbd2ce   13     0      0      0       0      9d
prod                          8adf5b90-1fe5-4a84-a3cf-5da09caf1024   13     0      0      0       0      9d
prod                          8bc82e66-3f0a-455f-9b36-0fc75ba8e19b   13     0      0      0       0      9d
prod                          8befc641-198e-4e6c-92cd-8aff738a0ab1   13     0      0      0       0      9d
prod                          8cc6391e-7f2d-4302-9a8f-7c1f44567aad   13     0      0      0       0      9d
prod                          8e92d482-26ab-4b86-a9ed-e41172b12a47   13     0      0      0       0      8h
prod                          8ec14409-4a26-4291-acc2-d9941cfda8e7   13     0      0      0       0      4d1h
prod                          901f281a-ec80-4647-9f13-ae5ef1bc583a   13     0      0      0       0      9d
prod                          903593d8-88f1-4a59-b0ee-2555e64e9437   13     0      0      0       0      3d9h
prod                          90eb548a-afdb-4296-83c8-6ec8336af3cc   13     0      0      0       0      9d
prod                          90eea296-3c03-4c4e-98fc-4bb6b20bc381   13     0      0      0       0      4d1h
prod                          91f58188-a9f6-4df7-a6b5-0ac273eb1c6a   13     0      0      0       0      12h
prod                          9ba406d0-c386-4e74-8c93-1e499192953f   13     0      0      0       0      4d1h
prod                          9ef733dc-31d4-44fc-b082-04ffa94e17ec   13     0      0      0       0      9d
prod                          9f904645-8afe-42e7-8c0a-e8604f6158ba   13     0      0      0       0      58m
prod                          a127eb9e-8b65-4317-a194-fcef7449e890   13     0      0      0       0      9d
prod                          a483e370-1620-4b99-8963-b6ed16ef4edf   13     0      0      0       0      9d
prod                          a56df7aa-be4f-4772-a36e-4073c88b8ee9   13     0      0      0       0      9d
prod                          a5d57560-e41a-47d2-9a3c-c574e8d35373   13     0      0      0       0      9d
prod                          a690fe30-a729-4e42-8eec-197122f79f7e   13     0      0      0       0      58m
prod                          aaa966f0-23fd-4644-b370-c1f18aec1789   13     0      0      0       0      9d
prod                          ab9b3ac0-11a4-4bce-bf15-e1a733e38f61   13     0      0      0       0      9d
prod                          acab310c-8579-4a38-bf87-361ea568e683   13     0      0      0       0      4d1h
prod                          ad8585ff-cea7-4d19-8c56-b829267653b7   13     0      0      0       0      5h3m
prod                          af8c2be9-9d2e-4d9c-aa74-d26d6f540c42   13     0      0      0       0      9d
prod                          b3aefde8-a4c9-4e3f-a4fb-9219644da3a1   13     0      0      0       0      9d
prod                          b4718655-6019-4053-99ab-67ec7cb80cce   13     0      0      0       0      4d1h
prod                          b4df7c49-88f2-4b9b-9871-2326ab7dad0c   13     0      0      0       0      9d
prod                          b803e1df-b623-40ba-be74-6fba53f9373d   13     0      0      0       0      9d
prod                          bb86d54c-9021-4010-8180-f359d390272b   13     0      0      0       0      51m
prod                          bb8d84f8-1176-42df-b09e-160e9acf761c   13     0      0      0       0      58m
prod                          bec46c34-cccb-4dd2-a6a2-897df1d9713c   13     0      0      0       0      62m
prod                          bfbd6539-3aa1-420a-8978-ad1f6a4e5685   13     0      0      0       0      63m
prod                          c2c12a52-d6cc-4bcc-bfa7-fa550adea828   13     0      0      0       0      9d
prod                          c368cabb-801a-44f1-a7fc-1e9c0931a4a9   13     0      0      0       0      9d
prod                          c3ce2983-8693-4718-abec-0704d9fb234e   13     0      0      0       0      50m
prod                          c9d094f6-9b54-4456-9177-96577cf980b8   13     0      0      0       0      9d
prod                          cab6f84c-6d73-40e1-bab0-f8894f2b0503   13     0      0      0       0      4d1h
prod                          cadbc263-19c9-4202-9621-49579b308b94   13     0      0      0       0      57m
prod                          cf07fb76-2d3e-4570-ad50-7142e3b53b0a   13     0      0      0       0      45h
prod                          d0803f7d-9aee-4fef-b5bb-034d139cd333   13     0      0      0       0      4d1h
prod                          d2c5facb-6ada-40c5-be88-420967baaf8c   13     0      0      0       0      2d1h
prod                          d3543f5a-8f27-4abb-9878-874f5bbae3b0   13     0      0      0       0      9d
prod                          d3a10630-c7bd-4743-ba46-808863d74d4e   13     0      0      0       0      9d
prod                          d617f4f9-25e6-4947-8919-fc4fd6e7964c   13     0      0      0       0      9d
prod                          dc0ac8b7-d7ca-43b2-8909-d71e8060286f   13     0      0      0       0      4d1h
prod                          dff62af5-6b65-4bcb-a739-a17e7a1d7b4d   13     0      0      0       0      9d
prod                          e0491b50-57e1-4d6f-b320-50d067fd5db9   13     0      0      0       0      63m
prod                          e086e950-3c3b-43de-a647-691b925e9d34   13     0      0      0       0      4d1h
prod                          e10f763c-bb50-4663-86be-0604b59dc8b4   13     0      0      0       0      9d
prod                          e22aa698-88c4-4e1b-9dcc-0d194b576fde   13     0      0      0       0      9d
prod                          e5b705b3-61a4-495f-a911-9c5b4a38be20   13     0      0      0       0      9d
prod                          e5f87645-f4bb-4f06-ae2b-33588f1b815c   13     0      0      0       0      4d1h
prod                          e7127b96-3947-45f1-92bb-a807d425e40e   13     0      0      0       0      12h
prod                          e729e01a-6a18-4e37-abe8-bcaa0508411a   13     0      0      0       0      52m
prod                          eb3c42b3-623f-47fb-9678-0a3302c473b1   13     0      0      0       0      9d
prod                          ece2b2b7-bfb1-4dbe-a338-11be9c352290   13     0      0      0       0      4d1h
prod                          ee9d0daa-e796-4c30-9722-051192aa9c95   13     0      0      0       0      9d
prod                          ef46ff7a-e349-482e-a3fd-a205fbacf6f5   13     0      0      0       0      8h
prod                          efd9358f-9ffe-4519-a49f-ce2aacac8d23   13     0      0      0       0      9d
prod                          f135194a-31dc-4cce-b72a-d1bcf870dd07   13     0      0      0       0      9d
prod                          f29e1fb2-4e56-4902-8329-caa0a66467ff   13     0      0      0       0      9d
prod                          f31af00b-94ee-460d-b8e1-8f4ade3c4804   13     0      0      0       0      4d1h
prod                          f78a1603-d5dd-454b-8c6c-452911b52354   13     0      0      0       0      9d
prod                          f90bb67f-d9d2-4fe6-8449-d12e83022494   13     0      0      0       0      9d
prod                          f9549c90-1724-439c-962b-9a3bde14b104   13     0      0      0       0      9d
prod                          fa8963a7-7473-4ec0-80ec-7ff4758e9e7e   13     0      0      0       0      9d
prod                          fcb0a1fc-6281-4e03-958e-1d60f8b642bd   13     0      0      0       0      20h
prod                          ff7015ac-a04e-4b13-a03d-7968646bd7db   13     0      0      0       0      2d1h
test-yun                      6347bb52-ff93-4b74-af09-085a6bd8f9c0   13     0      0      0       0      9d
velero                        14da000a-93f9-4ff8-a779-5d798fd6a431   13     0      0      0       0      9d
velero                        34b586bb-553b-4c05-91ef-7d6618364e00   13     0      0      0       0      9d
velero                        66b35322-f61b-409c-9986-9e109e2f0cc1   13     0      0      0       0      9d

Fetching "cleanuppolicies" for the cluster

No resources found

Fetching "clusteradmissionreports" for the cluster

No resources found

Fetching "clusterbackgroundscanreports" for the cluster

No resources found

Fetching "clustercleanuppolicies" for the cluster

No resources found

Fetching "clusterpolicies" for the cluster

NAME                             BACKGROUND   VALIDATE ACTION   READY   AGE
disallow-capabilities            true         audit             true    8d
disallow-host-namespaces         true         audit             true    8d
disallow-host-path               true         audit             true    8d
disallow-host-ports              true         audit             true    8d
disallow-host-ports-range        true         audit             true    8d
disallow-host-process            true         audit             true    8d
disallow-privileged-containers   true         audit             true    8d
disallow-proc-mount              true         audit             true    8d
disallow-selinux                 true         audit             true    8d
restrict-apparmor-profiles       true         audit             true    8d
restrict-seccomp                 true         audit             true    8d
restrict-sysctls                 true         audit             true    8d

Fetching "clusterpolicyreports" for the cluster

No resources found

Fetching "clusterreportchangerequests" for the cluster

No resources found

Fetching "generaterequests" for the cluster

No resources found

Fetching "kyvernoadapters" for the cluster

No resources found

Fetching "kyvernoes" for the cluster

NAMESPACE                     NAME      NAMESPACE   VERSION                RUNNING   HA MODE
enterprise-kyverno-operator   kyverno   kyverno     v1.9.2-n4k.nirmata.1   true      true

Fetching "kyvernooperators" for the cluster

No resources found

Fetching "openshiftkyvernooperators" for the cluster

No resources found

Fetching "policies" for the cluster

No resources found

Fetching "policyexceptions" for the cluster

No resources found

Fetching "policyreports" for the cluster

NAMESPACE                     NAME                                  PASS   FAIL   WARN   ERROR   SKIP   AGE
amazon-cloudwatch             cpol-disallow-capabilities            12     0      0      0       0      9d
amazon-cloudwatch             cpol-disallow-host-namespaces         12     0      0      0       0      9d
amazon-cloudwatch             cpol-disallow-host-path               0      12     0      0       0      9d
amazon-cloudwatch             cpol-disallow-host-ports              12     0      0      0       0      9d
amazon-cloudwatch             cpol-disallow-host-ports-range        12     0      0      0       0      9d
amazon-cloudwatch             cpol-disallow-host-process            12     0      0      0       0      9d
amazon-cloudwatch             cpol-disallow-privileged-containers   12     0      0      0       0      9d
amazon-cloudwatch             cpol-disallow-proc-mount              12     0      0      0       0      9d
amazon-cloudwatch             cpol-disallow-selinux                 24     0      0      0       0      9d
amazon-cloudwatch             cpol-restrict-apparmor-profiles       12     0      0      0       0      9d
amazon-cloudwatch             cpol-restrict-seccomp                 12     0      0      0       0      9d
amazon-cloudwatch             cpol-restrict-sysctls                 12     0      0      0       0      9d
backup-mongodb                cpol-disallow-capabilities            26     0      0      0       0      35d
backup-mongodb                cpol-disallow-host-namespaces         26     0      0      0       0      35d
backup-mongodb                cpol-disallow-host-path               26     0      0      0       0      35d
backup-mongodb                cpol-disallow-host-ports              26     0      0      0       0      35d
backup-mongodb                cpol-disallow-host-ports-range        26     0      0      0       0      9d
backup-mongodb                cpol-disallow-host-process            26     0      0      0       0      35d
backup-mongodb                cpol-disallow-privileged-containers   26     0      0      0       0      35d
backup-mongodb                cpol-disallow-proc-mount              26     0      0      0       0      35d
backup-mongodb                cpol-disallow-selinux                 52     0      0      0       0      35d
backup-mongodb                cpol-restrict-apparmor-profiles       26     0      0      0       0      9d
backup-mongodb                cpol-restrict-seccomp                 26     0      0      0       0      35d
backup-mongodb                cpol-restrict-sysctls                 26     0      0      0       0      35d
enterprise-kyverno-operator   cpol-disallow-capabilities            3      0      0      0       0      35d
enterprise-kyverno-operator   cpol-disallow-host-namespaces         3      0      0      0       0      35d
enterprise-kyverno-operator   cpol-disallow-host-path               3      0      0      0       0      35d
enterprise-kyverno-operator   cpol-disallow-host-ports              3      0      0      0       0      35d
enterprise-kyverno-operator   cpol-disallow-host-ports-range        3      0      0      0       0      35d
enterprise-kyverno-operator   cpol-disallow-host-process            3      0      0      0       0      35d
enterprise-kyverno-operator   cpol-disallow-privileged-containers   3      0      0      0       0      35d
enterprise-kyverno-operator   cpol-disallow-proc-mount              3      0      0      0       0      35d
enterprise-kyverno-operator   cpol-disallow-selinux                 6      0      0      0       0      35d
enterprise-kyverno-operator   cpol-restrict-apparmor-profiles       3      0      0      0       0      35d
enterprise-kyverno-operator   cpol-restrict-seccomp                 3      0      0      0       0      35d
enterprise-kyverno-operator   cpol-restrict-sysctls                 3      0      0      0       0      35d
kube-system                   cpol-disallow-capabilities            59     12     0      0       0      35d
kube-system                   cpol-disallow-host-namespaces         47     24     0      0       0      35d
kube-system                   cpol-disallow-host-path               22     49     0      0       0      35d
kube-system                   cpol-disallow-host-ports              59     12     0      0       0      35d
kube-system                   cpol-disallow-host-ports-range        59     12     0      0       0      35d
kube-system                   cpol-disallow-host-process            71     0      0      0       0      35d
kube-system                   cpol-disallow-privileged-containers   35     36     0      0       0      35d
kube-system                   cpol-disallow-proc-mount              71     0      0      0       0      35d
kube-system                   cpol-disallow-selinux                 142    0      0      0       0      35d
kube-system                   cpol-restrict-apparmor-profiles       71     0      0      0       0      35d
kube-system                   cpol-restrict-seccomp                 71     0      0      0       0      35d
kube-system                   cpol-restrict-sysctls                 71     0      0      0       0      35d
kyverno                       cpol-disallow-capabilities            12     0      0      0       0      9d
kyverno                       cpol-disallow-host-namespaces         12     0      0      0       0      9d
kyverno                       cpol-disallow-host-path               12     0      0      0       0      9d
kyverno                       cpol-disallow-host-ports              12     0      0      0       0      9d
kyverno                       cpol-disallow-host-ports-range        12     0      0      0       0      9d
kyverno                       cpol-disallow-host-process            12     0      0      0       0      9d
kyverno                       cpol-disallow-privileged-containers   12     0      0      0       0      8d
kyverno                       cpol-disallow-proc-mount              12     0      0      0       0      9d
kyverno                       cpol-disallow-selinux                 24     0      0      0       0      9d
kyverno                       cpol-restrict-apparmor-profiles       12     0      0      0       0      9d
kyverno                       cpol-restrict-seccomp                 12     0      0      0       0      8d
kyverno                       cpol-restrict-sysctls                 12     0      0      0       0      9d
loki-stack                    cpol-disallow-capabilities            12     0      0      0       0      9d
loki-stack                    cpol-disallow-host-namespaces         12     0      0      0       0      9d
loki-stack                    cpol-disallow-host-path               0      12     0      0       0      9d
loki-stack                    cpol-disallow-host-ports              12     0      0      0       0      9d
loki-stack                    cpol-disallow-host-ports-range        12     0      0      0       0      9d
loki-stack                    cpol-disallow-host-process            12     0      0      0       0      9d
loki-stack                    cpol-disallow-privileged-containers   12     0      0      0       0      9d
loki-stack                    cpol-disallow-proc-mount              12     0      0      0       0      9d
loki-stack                    cpol-disallow-selinux                 24     0      0      0       0      9d
loki-stack                    cpol-restrict-apparmor-profiles       12     0      0      0       0      9d
loki-stack                    cpol-restrict-seccomp                 12     0      0      0       0      9d
loki-stack                    cpol-restrict-sysctls                 12     0      0      0       0      9d
monitoring                    cpol-disallow-capabilities            26     0      0      0       0      35d
monitoring                    cpol-disallow-host-namespaces         26     0      0      0       0      35d
monitoring                    cpol-disallow-host-path               26     0      0      0       0      35d
monitoring                    cpol-disallow-host-ports              26     0      0      0       0      35d
monitoring                    cpol-disallow-host-ports-range        26     0      0      0       0      35d
monitoring                    cpol-disallow-host-process            26     0      0      0       0      35d
monitoring                    cpol-disallow-privileged-containers   26     0      0      0       0      35d
monitoring                    cpol-disallow-proc-mount              26     0      0      0       0      35d
monitoring                    cpol-disallow-selinux                 52     0      0      0       0      35d
monitoring                    cpol-restrict-apparmor-profiles       26     0      0      0       0      35d
monitoring                    cpol-restrict-seccomp                 26     0      0      0       0      35d
monitoring                    cpol-restrict-sysctls                 26     0      0      0       0      35d
nirmata-opencost              cpol-disallow-capabilities            6      0      0      0       0      9d
nirmata-opencost              cpol-disallow-host-namespaces         6      0      0      0       0      9d
nirmata-opencost              cpol-disallow-host-path               6      0      0      0       0      9d
nirmata-opencost              cpol-disallow-host-ports              6      0      0      0       0      9d
nirmata-opencost              cpol-disallow-host-ports-range        6      0      0      0       0      8d
nirmata-opencost              cpol-disallow-host-process            6      0      0      0       0      9d
nirmata-opencost              cpol-disallow-privileged-containers   6      0      0      0       0      9d
nirmata-opencost              cpol-disallow-proc-mount              6      0      0      0       0      9d
nirmata-opencost              cpol-disallow-selinux                 12     0      0      0       0      9d
nirmata-opencost              cpol-restrict-apparmor-profiles       6      0      0      0       0      9d
nirmata-opencost              cpol-restrict-seccomp                 6      0      0      0       0      9d
nirmata-opencost              cpol-restrict-sysctls                 6      0      0      0       0      9d
nirmata                       cpol-disallow-capabilities            11     0      0      0       0      9d
nirmata                       cpol-disallow-host-namespaces         11     0      0      0       0      9d
nirmata                       cpol-disallow-host-path               11     0      0      0       0      9d
nirmata                       cpol-disallow-host-ports              11     0      0      0       0      9d
nirmata                       cpol-disallow-host-ports-range        11     0      0      0       0      9d
nirmata                       cpol-disallow-host-process            11     0      0      0       0      9d
nirmata                       cpol-disallow-privileged-containers   11     0      0      0       0      9d
nirmata                       cpol-disallow-proc-mount              11     0      0      0       0      9d
nirmata                       cpol-disallow-selinux                 22     0      0      0       0      9d
nirmata                       cpol-restrict-apparmor-profiles       11     0      0      0       0      9d
nirmata                       cpol-restrict-seccomp                 11     0      0      0       0      9d
nirmata                       cpol-restrict-sysctls                 11     0      0      0       0      9d
prod                          cpol-disallow-capabilities            154    0      0      0       0      9d
prod                          cpol-disallow-host-namespaces         154    0      0      0       0      9d
prod                          cpol-disallow-host-path               154    0      0      0       0      9d
prod                          cpol-disallow-host-ports              154    0      0      0       0      9d
prod                          cpol-disallow-host-ports-range        154    0      0      0       0      9d
prod                          cpol-disallow-host-process            154    0      0      0       0      9d
prod                          cpol-disallow-privileged-containers   154    0      0      0       0      9d
prod                          cpol-disallow-proc-mount              154    0      0      0       0      9d
prod                          cpol-disallow-selinux                 308    0      0      0       0      9d
prod                          cpol-restrict-apparmor-profiles       154    0      0      0       0      9d
prod                          cpol-restrict-seccomp                 154    0      0      0       0      9d
prod                          cpol-restrict-sysctls                 154    0      0      0       0      9d
test-yun                      cpol-disallow-capabilities            1      0      0      0       0      9d
test-yun                      cpol-disallow-host-namespaces         1      0      0      0       0      9d
test-yun                      cpol-disallow-host-path               1      0      0      0       0      9d
test-yun                      cpol-disallow-host-ports              1      0      0      0       0      9d
test-yun                      cpol-disallow-host-ports-range        1      0      0      0       0      9d
test-yun                      cpol-disallow-host-process            1      0      0      0       0      9d
test-yun                      cpol-disallow-privileged-containers   1      0      0      0       0      9d
test-yun                      cpol-disallow-proc-mount              1      0      0      0       0      9d
test-yun                      cpol-disallow-selinux                 2      0      0      0       0      9d
test-yun                      cpol-restrict-apparmor-profiles       1      0      0      0       0      9d
test-yun                      cpol-restrict-seccomp                 1      0      0      0       0      9d
test-yun                      cpol-restrict-sysctls                 1      0      0      0       0      9d
velero                        cpol-disallow-capabilities            3      0      0      0       0      9d
velero                        cpol-disallow-host-namespaces         3      0      0      0       0      9d
velero                        cpol-disallow-host-path               3      0      0      0       0      9d
velero                        cpol-disallow-host-ports              3      0      0      0       0      9d
velero                        cpol-disallow-host-ports-range        3      0      0      0       0      9d
velero                        cpol-disallow-host-process            3      0      0      0       0      9d
velero                        cpol-disallow-privileged-containers   3      0      0      0       0      9d
velero                        cpol-disallow-proc-mount              3      0      0      0       0      9d
velero                        cpol-disallow-selinux                 6      0      0      0       0      9d
velero                        cpol-restrict-apparmor-profiles       3      0      0      0       0      9d
velero                        cpol-restrict-seccomp                 3      0      0      0       0      9d
velero                        cpol-restrict-sysctls                 3      0      0      0       0      9d

Fetching "reportchangerequests" for the cluster

No resources found

Fetching "updaterequests" for the cluster

No resources found

Pod Disruption Budget Deployed:

NAME      MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
kyverno   1               N/A               2                     9d

System Namespaces excluded in webhook
- "kyverno"

Memory and CPU consumption of Kyverno pods:
NAME                                         CPU(cores)   MEMORY(bytes)
kyverno-55d799bb47-4t24s                     119m         170Mi
kyverno-55d799bb47-bl2wd                     161m         146Mi
kyverno-55d799bb47-qf2vs                     16m          138Mi
kyverno-cleanup-controller-5b8c57465-9ffnn   3m           24Mi

Collecting the manifests for cluster policies,Kyverno deployments and ConfigMaps
 - Manifests are collected in "kyverno/manifests" folder

Collecting the logs for all the Kyverno pods
 - Logs are collected in "kyverno/logs" folder

Verifying Kyverno Metrics
- Kyverno Metrics are exposed on this cluster

NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
kyverno-svc-metrics   ClusterIP   172.20.205.112   <none>        8000/TCP   9d

No of Policies in "Not Ready" State: 0


---------------------------------------------------
Prometheus ServiceMonitor for Kyverno found!

---------------------------------------------------

Total admission requests triggered in the last 24h:  14313

Percentage of total incoming admission requests corresponding to resource creations:  0.010812124157200996


Scraping Policies and Rule Counts from Prometheus


Scraping Policy and Rule Execution from Prometheus


Scraping Policy Rule Execution Latency from Prometheus


Scraping Admission Review Latency from Prometheus


Scraping Admission Requests Counts from Prometheus


Scraping Policy Change Counts from Prometheus


Scraping Client Queries from Prometheus


All the raw Kyverno data scraped above is dumped in BaselineReport.txt


Baseline report "baselinereport.tar" generated successfully in the current directory
```
