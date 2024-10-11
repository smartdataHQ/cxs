`kubectl create namespace pipelines`
`kubectl apply -f nifi-deployment.yaml`
`kubectl get pods -n pipelines`
`kubectl logs -f nifi-xxx-xxx -n pipelines`
`kubectl delete deployment nifi -n pipelines`
`kubectl delete -f nifi-deployment.yaml`