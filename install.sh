#!/bin/bash  

set -eo pipefail

# Parameters with default values (can override):
tanzurmqversion=1.5.3
serviceaccount=rabbitmq
namespace="rabbitmq-system"
replicas=3
prometheusrepourl="https://github.com/rabbitmq/cluster-operator.git"
#prometheusoperatorversion=v1.14.0
requesttimeout=100s
vmwareuser=""
vmwarepassword=""
adminpassword=""
certmanagervsersion=1.13.3
kubectl=kubectl
maxskew=0
cluster_partition_handling=pause_minority
vm_memory_high_watermark_paging_ratio=0.99
disk_free_limit_relative=1.5
collect_statistics_interval=10000
cpu=2
memory=2Gi # adjust for Production!
antiaffinity=0 # Set to 1 in Production (pass parameter)!
storage="1Gi" # Override in Production (pass parameter)!
storageclassname="" # Override in Production (pass parameter)!
max_unavailable=1
servicetype=LoadBalancer
install_carvel=1
install_cert_manager=1
install_helm=1
install_prometheus=1
create_secret=1
install_package=1
tls_secret=""

enable_amqp_1_0=0
enable_ldap=1
enable_oauth2=1
enable_consistent_hash_exchange=1
enable_federation=0
enable_shovel=0
enable_mqtt=0
enable_stomp=0
enable_stream=1
enable_top=1
enable_warm_standby_replication_plugin=0


# Override parameters (if specified) e.g. --tanzurmqversion 1.2.2
while [ $# -gt 0 ]; do

   if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare $param="$2"
   fi

  shift
done

if [ -z $vmwareuser ]
then
     echo "vmwareuser not set"
     exit 1
fi

if [ -z $vmwarepassword ] 
then
     echo "vmwarepassword not set"
     exit 1
fi


if [ -z $adminpassword ] 
then
     echo "adminpassword not set"
     exit 1
fi

if [ -z $storageclassname ]; then persistent=0; else persistent=1; fi

echo "namespace: $namespace"
echo "tanzurmqversion: $tanzurmqversion"
echo "serviceaccount: $serviceaccount"
echo "replicas: $replicas"
echo "prometheusrepourl: $prometheusrepourl"
#echo "prometheusoperatorversion: $prometheusoperatorversion"
echo "requesttimeout: $requesttimeout"
echo "certmanagervsersion: $certmanagervsersion"
echo "kubectl: $kubectl"
echo "maxskew: $maxskew"
echo "cluster_partition_handling: $cluster_partition_handling"
echo "vm_memory_high_watermark_paging_ratio: $vm_memory_high_watermark_paging_ratio"
echo "disk_free_limit_relative: $disk_free_limit_relative"
echo "collect_statistics_interval: $collect_statistics_interval"
echo "cpu: $cpu"
echo "memory: $memory"
echo "antiaffinity: $antiaffinity"
echo "storage: $storage"
echo "storageclassname: $storageclassname"
echo "maxunavailable: $maxunavailable"
echo "servicetype: $servicetype"
echo "install_carvel: $install_carvel"
echo "install_cert_manager: $install_cert_manager"
echo "install_helm: $install_helm"
echo "install_prometheus: $install_prometheus"
echo "create_secret: $create_secret"
echo "install_package: $install_package"
echo "tls_secret: $tls_secret"

case $kubectl in
"oc") openshift=1 ;;
*) openshift=0 ;;
esac

echo "CREATE NAMESPACE $namespace if does not exist..."
$kubectl create namespace $namespace --dry-run=client -o yaml | $kubectl apply -f-

echo "CREATE SERVICEACCOUNT $serviceaccount if does not exist..."
$kubectl create serviceaccount $serviceaccount -n $namespace --dry-run=client -o yaml | $kubectl apply -f-

echo "CREATING CLUSTER ROLE"
$kubectl apply -f clusterrole.yml -n $namespace --request-timeout=$requesttimeout

echo "CREEATING the CLUSTER rmq ROLE BINDING if does not exist..."
$kubectl create clusterrolebinding rmq --clusterrole tanzu-rabbitmq-crd-install --serviceaccount $namespace:$serviceaccount --request-timeout=$requesttimeout --dry-run=client -o yaml | $kubectl apply -f-

if [ $install_carvel -gt 0 ]
then
     if command -v shasum &> /dev/null
     then
          if command -v wget &> /dev/null
          then
               echo "INSTALLING CARVEL USING wget"
               wget -O- https://carvel.dev/install.sh | bash
          elif command -v curl &> /dev/null
          then
               echo "INSTALLING CARVEL USING curl"
               curl -L https://carvel.dev/install.sh | bash
          else
               echo "Error: neither wget nor curl detected"
               exit 1
          fi
     else
          echo "WARNING: shasum IS MISSING !"
          chmod +x install_carvel.sh
          ./install_carvel.sh
     fi

     echo "INSTALLING KAPP-CONTROLLER"
     $kubectl apply -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml --request-timeout=$requesttimeout

     echo "INSTALLING SECRETGEN-CONTROLLER"
     $kubectl apply -f https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/latest/download/release.yml --request-timeout=$requesttimeout
fi

if [ $install_cert_manager -gt 0 ]
then
     echo "INSTALLING CERT-MANAGER" # @Param: version
     $kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v$certmanagervsersion/cert-manager.yaml --request-timeout=$requesttimeout
fi

if [ $create_secret -gt 0 ]
then
     echo "CREATING VMWARE CONTAINER REGISTRY SECRET"
     export RMQ_docker__username="$vmwareuser"
     export RMQ_docker__password="$vmwarepassword"
     export RMQ_docker__server="registry.tanzu.vmware.com"
     export RMQ_rabbitmq__namespace="$namespace"
     ytt -f secret.yml --data-values-env RMQ | $kubectl apply -f-
fi

if [ $install_package -gt 0 ]
then
     echo "DEPLOYING REPOSITORY..."
     export RMQ_rabbitmq__image="registry.tanzu.vmware.com/p-rabbitmq-for-kubernetes/tanzu-rabbitmq-package-repo:$tanzurmqversion"
     ytt -f repo.yml --data-values-env RMQ | kapp deploy --debug -a tanzu-rabbitmq-repo -y -n $namespace -f-

     echo "DEPLOYING PACKAGE INSTALL..."
     export RMQ_rabbitmq__version="$tanzurmqversion"
     export RMQ_rabbitmq__serviceaccount="$serviceaccount"
     ytt -f packageInstall.yml --data-values-env RMQ | kapp deploy --debug -a tanzu-rabbitmq  -y -n $namespace -f-
fi

if [ $install_helm -gt 0 ]
then
     echo "INSTALLING HELM..."
     if command -v wget &> /dev/null
          then
               echo "INSTALLING HELM USING wget"
               wget -O get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
          elif command -v curl &> /dev/null
          then
               echo "INSTALLING HELM USING curl"
               curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
          else
               echo "Error: neither wget nor curl detected"
               exit 1
          fi
          
     chmod +x get_helm.sh
     ./get_helm.sh
fi

# TODO: fix Observability installation for Openshift
if [ ! -d "cluster-operator" ] 
then
     if [[ $install_prometheus -gt 0 ]] 
     then
          echo "INSTALLING PROMETHEUS OPERATOR FROM $prometheusrepourl"
          git clone $prometheusrepourl
          cd cluster-operator/observability/
          # Uncomment the line below to install certain prometheus operator version (as opposed to always get latest):
          #git checkout $prometheusoperatorversion
          chmod +x quickstart.sh
          ./quickstart.sh
          cd ../../

          echo "INSTALLING PROMETHEUS SERVICE MONITOR..."
          $kubectl apply --filename https://raw.githubusercontent.com/rabbitmq/cluster-operator/main/observability/prometheus/monitors/rabbitmq-servicemonitor.yml

          echo "INSTALLING OPERATORS MONITOR..."
          $kubectl apply --filename https://raw.githubusercontent.com/rabbitmq/cluster-operator/main/observability/prometheus/monitors/rabbitmq-cluster-operator-podmonitor.yml
     fi
else
     echo "Directory cluster-operator exists, skipping..."
fi

echo "CREATE RABBITMQ CLUSTER"
ytt -f cluster.yml \
     --data-value-yaml rabbitmq.replicas=$replicas \
     --data-value-yaml rabbitmq.antiaffinity=$antiaffinity \
     --data-value-yaml rabbitmq.maxskew=$maxskew \
     --data-value-yaml rabbitmq.persistent=$persistent \
     --data-value-yaml rabbitmq.storageclassname=$storageclassname \
     --data-value-yaml rabbitmq.storage=$storage \
     --data-value-yaml rabbitmq.cluster_partition_handling=$cluster_partition_handling \
     --data-value-yaml rabbitmq.vm_memory_high_watermark_paging_ratio=$vm_memory_high_watermark_paging_ratio \
     --data-value-yaml rabbitmq.disk_free_limit.relative=$disk_free_limit_relative \
     --data-value-yaml rabbitmq.collect_statistics_interval=$collect_statistics_interval \
     --data-value-yaml rabbitmq.cpu=$cpu \
     --data-value-yaml rabbitmq.memory=$memory \
     --data-value-yaml rabbitmq.default_pass=$adminpassword \
     --data-value-yaml openshift=$openshift \
     --data-value-yaml servicetype=$servicetype \
     --data-value-yaml tls_secret=$tls_secret \
     --data-value-yaml rabbitmq.enable_amqp_1_0=$enable_amqp_1_0 \
     --data-value-yaml rabbitmq.enable_ldap=$enable_ldap \
     --data-value-yaml rabbitmq.enable_oauth2=$enable_oauth2 \
     --data-value-yaml rabbitmq.enable_consistent_hash_exchange=$enable_consistent_hash_exchange \
     --data-value-yaml rabbitmq.enable_federation=$enable_federation \
     --data-value-yaml rabbitmq.enable_shovel=$enable_shovel \
     --data-value-yaml rabbitmq.enable_mqtt=$enable_mqtt \
     --data-value-yaml rabbitmq.enable_stomp=$enable_stomp \
     --data-value-yaml rabbitmq.enable_stream=$enable_stream \
     --data-value-yaml rabbitmq.enable_top=$enable_top \
     --data-value-yaml rabbitmq.enable_warm_standby_replication_plugin=$enable_warm_standby_replication_plugin \
     | kapp deploy --debug -a tanzu-rabbitmq-cluster -y -n $namespace -f-

if [ $max_unavailable -gt 0 ] 
then
     echo "APPLYING the POD DISRUPTION BUDGET"
     ytt -f pod_disruption_budget.yml --data-value-yaml rabbitmq.max_unavailable=$max_unavailable \
     | kubectl apply -n $namespace --request-timeout=$requesttimeout -f-
fi











