## Integrating Backup into your CI/CD Pipelines using Kanister  

Deploy local Minikube cluster 

minikube start --addons volumesnapshots,csi-hostpath-driver --apiserver-port=6443 --container-runtime=containerd -p mc-demo --kubernetes-version=1.21.2

## Create a mysql namespace 

```
kubectl create ns mysql
```

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
kubectl port-forward svc/argocd-server -n argocd 8443:443
```

Username is admin and password can be obtained with this command. open a web browser [localhost](https://localhost:8443)

``` 
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

## Create a bucket in minikube with minio

Enable load balancer in minikube 
```
# run this command in another terminal
minikube tunnel --profile=mc-demo
```

Install minio
```
helm repo add minio https://charts.min.io/
kubectl create ns minio
helm install kasten-minio minio/minio --namespace=minio --version 8.0.10 \
  --set persistence.size=5Gi

# feed ACCESS_KEY variable and SECRET_KEY and display them
AWS_ACCESS_KEY_ID=$(kubectl -n minio get secret kasten-minio -o jsonpath="{.data.accesskey}" | base64 --decode)
echo $AWS_ACCESS_KEY_ID
AWS_SECRET_KEY=$(kubectl -n minio get secret kasten-minio -o jsonpath="{.data.secretkey}" | base64 --decode)
echo $AWS_SECRET_KEY

# Expose minio in a load balancer 
kubectl expose svc/kasten-minio --name=minio-lb -n minio --type=LoadBalancer
EXTERNAL_IP=$(kubectl get svc -n minio minio-lb -o jsonpath='{.spec.clusterIP}')
echo "http://$EXTERNAL_IP:9000/"
```

open a web browser to this addres and use `$ACCESS_KEY`and `$SECRET_KEY` to access th minio GUI.

Create a `kanister` bucket.


## Create a Kanister Profile 
This will give us some where to store our backups, this will be done using the KanCTL CLI tool 

```
kanctl create profile \
   --namespace mysql \
   --bucket kanister \
   --skip-SSL-verification \
   --endpoint http://$EXTERNAL_IP:9000/ \
   s3compliant \
   --access-key $AWS_ACCESS_KEY_ID \
   --secret-key $AWS_SECRET_KEY
```

confirm you now have a profile created 
```
kubectl get profile -n mysql
PROFILE=$(kubectl get profile -n mysql -o jsonpath='{.items[0].metadata.name}')
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

## Sync the project

Create in argo a new project using the clone repository.