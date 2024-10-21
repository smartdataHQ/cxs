1. `kubectl create namespace pipelines`
2. `wget https://raw.githubusercontent.com/smartdataHQ/cxs/refs/heads/main/pipelines/nifi/nifi-deployment.yaml -O nifi-deployment.yaml`
2. `kubectl apply -f nifi-deployment.yaml`
3. `kubectl get pods -n pipelines`
4. `kubectl logs -f nifi-xxx-xxx -n pipelines`
5. `kubectl delete deployment nifi -n pipelines`
6. `kubectl delete -f nifi-deployment.yaml`

