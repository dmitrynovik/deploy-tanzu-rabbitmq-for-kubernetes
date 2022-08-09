kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.yaml 

kubectl apply -n rabbitmq-system self-signed-issuer.yml
kubectl apply -n rabbitmq-system self-signed-cluster-issuer.yml
kubectl apply -n rabbitmq-system cluster-issuer.yml
kubectl apply -n rabbitmq-system certificate.yml
