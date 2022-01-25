#!/bin/bash
echo "$(tput setaf 4)Create new cluster"
minikube start --addons volumesnapshots,csi-hostpath-driver --apiserver-port=6443 --container-runtime=containerd -p mc-demo --kubernetes-version=1.21.2 

echo "$(tput setaf 4)update helm repos if already present"
helm repo update

echo "$(tput setaf 4)Add helm repositories for Kanister & Deploy"
helm repo add kanister https://charts.kanister.io/
kubectl create namespace kanister 
helm install myrelease --namespace kanister kanister/kanister-operator --set image.tag=0.71.0
kubectl create -f https://raw.githubusercontent.com/kanisterio/kanister/master/examples/stable/mysql/mysql-blueprint.yaml -n kanister

echo "$(tput setaf 4)Change default storageclass"

kubectl patch storageclass csi-hostpath-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'


######################################################################################################
#Deploy ArgoCD
######################################################################################################

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "you should now open a new terminal and run kubectl port-forward svc/argocd-server -n argocd 8443:443"

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo




echo kubectl get customresourcedefinitions.apiextensions.k8s.io | grep "kanister"
echo "$(tput setaf 4)Environment Complete"
