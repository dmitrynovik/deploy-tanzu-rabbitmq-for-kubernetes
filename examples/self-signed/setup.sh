kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.yaml

kubectl create namespace rabbitmq-system --dry-run=client -o yaml | kubectl apply -f-

kubectl apply -n rabbitmq-system -f self-signed-issuer.yml
kubectl apply -n rabbitmq-system -f self-signed-cluster-issuer.yml
kubectl apply -n rabbitmq-system -f cluster-issuer.yml
kubectl apply -n rabbitmq-system -f certificate.yml
