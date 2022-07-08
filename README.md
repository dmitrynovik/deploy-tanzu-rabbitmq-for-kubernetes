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
- logged in as a root user (or `sudo -i`)
- Github passwordless SSH key (if with password, you'll be prompted to enter the password)

N.B. Use this at your own risk: no liability is accepted.

Tested to work on Ubuntu 21 and with RabbitMQ 1.3.0

## Usage
```
chmod +x install.sh
./install.sh --vmwareuser <your vmware registry username> --vmwarepassword <your vmware registry password> [ --param1 value1 --param2 value2 ]
```
### Openshift (experimental)
Add following command-line argument:
```
--kubectl oc
```

### Optional arguments
| Parameter | Default Value | Meaning |
|:----------|:--------------|:--------|
|replicas   | 3             | Number of RabbitMQ replicas (pods) to create |
|requesttimeout | 100s      | Request timeout of a command before it fails |
|tanzurmqversion| 1.3.0     | The version of Tanzu RabbitMQ to install     |
|serviceaccount | rabbitmq  | K8S service account to be created to install the RabbitMQ |
|namespace|rabbitmq-system  | The K8S namespace to install RabbitMQ |
|prometheusrepourl|https://github.com/rabbitmq/cluster-operator.git | The repository of Prometheus K8S operator|
|prometheusoperatorversion|v1.14.0 | The version of Prometheus operator|
|certmanagervsersion|1.8.0| The version of K8S Cert Manager to install |
|kubectl|kubectl|Pass `--kubectl oc` to install on OpenShift|