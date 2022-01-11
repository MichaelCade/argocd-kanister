## Integrating Backup into your CI/CD Pipelines using Kanister  

Deploy local Minikube cluster 

minikube start --addons volumesnapshots,csi-hostpath-driver --apiserver-port=6443 --container-runtime=containerd -p mc-demo --kubernetes-version=1.21.2

## How to Install Kanister 

add kanister helm repository 
```
helm repo add kanister https://charts.kanister.io/
```
create kanister namespace
```
kubectl create namespace kanister 
```
deploy kanister using helm 
```
helm install myrelease --namespace kanister kanister/kanister-operator --set image.tag=0.71.0
```

Once we have kanister deployed we should now show the CustomResourceDefinitions, this will show actionsets, blueprints, profiles.

```
kubectl get customresourcedefinitions.apiextensions.k8s.io | grep "kanister"
```

## Deploy ArgoCD 

```
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Username is admin and password can be obtained with this command. open a web browser [localhost](https://localhost:8080)

``` 
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

## Create a Kanister Profile 
This will give us some where to store our backups, this will be done using the KanCTL CLI tool 

Run the following but make sure you have defined your environment variables 

- $AWS_ACCESS_KEY_ID
- $AWS_SECRET_KEY
- $AWS_BUCKET

```
kanctl create profile s3compliant --access-key $AWS_ACCESS_KEY_ID --secret-key $AWS_SECRET_KEY --bucket $AWS_BUCKET --region us-east-2 --namespace mysql
```

confirm you now have a profile created 
```
kubectl get profile -n mysql-test
```
## Creating a Kanister Blueprint 

Kanister uses Blueprints to define these database-specific workflows and open-source Blueprints are available for several popular applications. It's also simple to customize existing Blueprints or add new ones.


```
kubectl create -f https://raw.githubusercontent.com/kanisterio/kanister/master/examples/stable/mysql/mysql-blueprint.yaml -n kanister
```

this blueprint is created in the Kanister namespace check with environment

```
kubectl get blueprint -n kanister 
```

At this stage I need to clone the repo for Kasten and then look at the pre sync command and change to use an actionset vs the backupaction it is today. I feel like that the kanctl is going to be an issue as well. 