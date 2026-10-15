# TP Jenkins CI/CD – [Ferid SAAD]

## 1. Environnement
VM Ubuntu 26.04, Docker, K3s, Jenkins, Maven
 ### capture

![Environnement](images/environnement.png)
![Maven](images/maven.png)

## 2. Workflow manuel- without using Jenkins

### 2.1 Dockerfile
````
# java jdk 17
FROM eclipse-temurin:17-jre
# Set port number
EXPOSE 2222
# Set the working directory in the container
WORKDIR /app
# Copy the packaged JAR file into the container
COPY target/yourApp.jar app.jar
# Specify the command to run on container startup
CMD ["java", "-jar", "app.jar"]
````
### 2.2 Build de l'image
Commandes
````
mvn clean install

docker build -t jenkins-demo:1.0

docker images | grep jenkins-demo
````
#### Capture

![Docker-images](images/dockerimages.png)


### 2.3 Push sur Docker Hub

1. Login to the docker hub using the below command:
````
docker login -u feridsaad
````

![Login to Dockerhub](images/login-dockerhub.png)

2. Now you tag your image:
````
 docker tag jenkins-demo:1.0 feridsaad/jenkins-demo:1.0
````
3. Push the image to the docker hub:
````

docker push feridsaad/jenkins-demo:1.0
````

![Tag de l'image](images/image-tag.png)

4. Create a container from the image:
````
docker run --detach --name myapp --publish 2222:2222 feridsaad/jenkins-demo:1.0
````
![Creation conteneur](images/creation-conteneur.png)

![Creation conteneur](images/dockerhub.png)


### 2.4 Déploiement Kubernetes
Fichier k8s.yaml
````
apiVersion: v1
kind: Service
metadata:
  name: spring-app-service
spec:
  selector:
    app: spring-app
  ports:
    - protocol: TCP
      port: 8888
      targetPort: 2222
      nodePort: 30222
  type: NodePort
  ````
  Fichier service.yaml

  ````
  apiVersion: v1
kind: Service
metadata:
  name: spring-app-service
spec:
  selector:
    app: spring-app
  ports:
    - protocol: TCP
      port: 8888
      targetPort: 2222
      nodePort: 30222
  type: NodePort
  ````
Exécution
````
kubectl apply -f deployment.yaml
kubectl get pods
````
capture
![Pods crées](images/creation-pods.png)
````
kubectl apply -f service.yaml
kubectl get svc
````
capture

![srevices](images/creation-svc.png)

Test d'application
````
curl http://localhost:30222
````
capture

![Test d'application](images/test.png)
![Test d'application](images/curl-30222.png)
## 3. Jenkins Freestyle
### Étape 1 … Étape 5 (challenge)

## 4. Difficultés rencontrées et solutions
(ex. port 2222 vs 8080, droits Docker, conflit avec Jenkins)

## 5. Conclusion