cd ../

install.sh --namespace "rabbitmq-system-upstream" --replication_mode upstream

install.sh --namespace "rabbitmq-system-downstream" --replication_mode downstream