# Deployment script for installation of Tanzu RabbitMQ for Kubernetes

This will install Tanzu RabbitMQ for Kubernetes on K8S along with pre-requisites

## What does it add to the system?
- Installing [Carvel toolchain](https://carvel.dev)
- Installing `kapp-controller`, `cert-mamager` and `secretgen-controller`
- Creating the `serviceaccount`, `cluster role` and `role binding`
- Installing observability tools such as `Grafana` and `Prometheus`
- Installing Tanzu RabbitMQ along with Kubernetes operator

## To make this work, you must have:
- *NIX Operating System
- `kubectl` utility pointing to K8S cluster
- `wget` OR `curl` utility installed
- Github passwordless SSH key (if with password, you'll be prompted to enter the password)

N.B. Use this at your own risk: no liability is accepted.

Tested to work on Ubuntu 21 and with RabbitMQ 1.3.0

## Usage

The minimal usage on a Dev machine is:

```
chmod +x install.sh
./install.sh --registryuser <your vmware registry username> --registrypassword <your vmware registry password> --adminpassword <RabbitMQ admin user password> [ --param1 value1 --param2 value2 ]
```

NOTE: For Production, you'll need to specify few more arguments:
* antiaffinity=1 (to schedule the pods on different zones)
* storageclassname = your persistent storage class
* storage = size of the storage e.g. 64Gi
* (optional): cpu (default: 2 cores), memory: (default: 2Gi)

Example of a Production deployment
```
./install.sh --registryuser <your vmware registry username> --registrypassword <your vmware registry password> --antiaffinity 1 storage <storage size> storageclassname <storage class> cpu 4 memory 4Gi --adminpassword <RabbitMQ admin user password>
```

Modify cluster only (NOT the first deployment):
```
--install_prerequisites 0
```

### Openshift (experimental)
Add following command-line argument:
```
--kubectl oc
```

### Optional arguments
| Parameter | Default Value | Meaning |
|:----------|:--------------|:--------|
|rabbitmq_cluster_name|rabbit-1-upstream|the name of the cluster to be created |
|replicas   | 3             | Number of RabbitMQ replicas (pods) to create |
|requesttimeout | 100s      | Request timeout of a command before it fails |
|tanzurmqversion| 1.3.0     | The version of Tanzu RabbitMQ to install     |
|serviceaccount | rabbitmq  | K8S service account to be created to install the RabbitMQ |
|namespace|rabbitmq-system  | The K8S namespace to install RabbitMQ |
|prometheusrepourl|https://github.com/rabbitmq/cluster-operator.git | The repository of Prometheus K8S operator|
|prometheusoperatorversion|v1.14.0 | The version of Prometheus operator|
|certmanagervsersion|1.8.0| The version of K8S Cert Manager to install |
|kubectl|kubectl|Pass `--kubectl oc` to install on OpenShift|
|maxskew|1|when `antiaffinity=1` - max differenece in pods number between different availability zones, see the [Pod Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)|
|cluster_partition_handling|pause_minority|see [Network partitioning handling mode](https://www.rabbitmq.com/partitions.html)|
|disk_free_limit_relative|1.5|See the [Configuring Disk Free Space Limit](https://www.rabbitmq.com/disk-alarms.html#configure)|
|collect_statistics_interval|10 seconds|See the [Statistics Interval](https://www.rabbitmq.com/management.html#statistics-interval)|
|cpu|2|number of cores per container|
|memory|2Gi|memory per container|
|antiaffinity|0|Set to 1 to deploy pods to different nodes in Production|
|storage|1Gi|Reserved persistent disk space, set to larger value in Production|
|storageclassname|none|Set to persistent storage class name in Production|
|servicetype|ClusterIp| `ClusterIP` or `NodePort` or `LoadBalancer`|
|install_carvel|1|if to install `carvel` toolchain  (skip otherwise)|
|install_cert_manager|1|if to install `cert-manager`  (skip otherwise)|
|install_helm|1|if to install `helm`  (skip otherwise)|
|install_prometheus|1|if to install and configure `Prometheus` and `Grafana` for Observability (skip otherwise)|
|create_secret|1|if to create VMWare registry pull secret in K8S|
|install_package|1|if to install RabbitMQ repository AND package (skip otherwise)|
|tls_secret|""|if not emply, will enable TLS with a `secretName` passed as `tls_secret`. Prerequisiste: must create a certificate in `cert-manager` and deploy to K8S cluster|
|max_unavailable|1|pod disruption budget|
|enable_amqp_1_0|0|if to enable the AMQP 1.0 plugin|
|enable_ldap|1|if to enable the LDAP plugin|
|enable_oauth2|1|if to enable the Oauth2 plugin|
|enable_consistent_hash_exchange|1|if to enable the Consistent Hash Exchange plugin|
|enable_federation|0|if to enable the Federation plugin|
|enable_shovel|0|if to enable the Shovel plugin|
|enable_mqtt|0|if to enable the MQTT plugin|
|enable_stomp|0|if to enable the Stomp plugin|
|enable_stream|1|if to enable the Stream plugin|
|enable_top|1|if to enable the Top plugin|

### To remove RabbitMQ cluster:
```
kubectl -n rabbitmq-system delete RabbitmqCluster tanzu-rabbitmq
```

### Running the Performance Test
[Pre-requisiste: Get the RabbitMQ perf-test](https://rabbitmq.github.io/rabbitmq-perf-test/stable/htmlsingle/)

Example of the usage with Quorum queues:
```
bin/runjava com.rabbitmq.perf.PerfTest --quorum-queue --queue quorum_test -h amqp://admin:admin@172.18.255.200 --size 2048 --rate 2000 --shutdown-timeout 60

```


