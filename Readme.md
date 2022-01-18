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
   --namespace kanister \
   --bucket kanister \
   --skip-SSL-verification \
   --endpoint http://$EXTERNAL_IP:9000/ \
   s3compliant \
   --access-key $AWS_ACCESS_KEY_ID \
   --secret-key $AWS_SECRET_KEY
```

confirm you now have a profile created 
```
kubectl get profile -n kanister
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

# Use argo to deploy your app

## Create the argo project

Create a mysql namespace.
``` 
kubectl create ns mysql
```

Create in argo a new project mysql-app :
- project name : mysql
- use the default project 
- git repo : your git repo (eg: https://github.com/michaelcourcy/argocd-kanister.git)
- path : base
- namespace: mysql
- choose the default or availables values for the rest

Once deployed, check the service account kanister-presync can create an action set in the kanister namespace.

```
kubectl auth can-i create actionset --as=system:serviceaccount:mysql:kanister-presync -n kanister
```

The answer should be yes.

## Create some data 

```
kubectl exec -ti mysql-0 -n mysql -- bash

mysql --user=root --password=ultrasecurepassword
CREATE DATABASE test;
USE test;
CREATE TABLE pets (name VARCHAR(20), owner VARCHAR(20), species VARCHAR(20), sex CHAR(1), birth DATE, death DATE);
INSERT INTO pets VALUES ('Puffball','Diane','hamster','f','1999-03-30',NULL);
SELECT * FROM pets;
+----------+-------+---------+------+------------+-------+
| name     | owner | species | sex  | birth      | death |
+----------+-------+---------+------+------------+-------+
| Puffball | Diane | hamster | f    | 1999-03-30 | NULL  |
+----------+-------+---------+------+------------+-------+
1 row in set (0.00 sec)
exit
exit
```

## Sync your project 

By resyncing your project you're going to trigger the creation of a backup. check on minio.

## Introduce some "bad" change in your application stack.

Let's imagine you create a mysqlclient app which is going to drop your database in your code 

Create this pod base/mysql-client.yaml 

```
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: mysql-client
  name: mysql-client
spec:
  containers:
  - image: mysql:8.0.26
    name: mysql-client
    env:
    - name: MYSQL_ROOT_PASSWORD
      valueFrom:
        secretKeyRef:
          key: mysql-root-password
          name: mysql
    command: 
      - sh
      - -o
      - errexit
      - -o
      - pipefail
      - -c
      - |         
        mysql -h mysql --user=root --password=$MYSQL_ROOT_PASSWORD -e "DROP DATABASE test;"
  dnsPolicy: ClusterFirst
  restartPolicy: Never
status: {}
```

You commit, push ans sync with argo ...  

The sync has deleted the database but fortunaletly kanister protect your database.

# Restore your database using kanctl

TODO 
