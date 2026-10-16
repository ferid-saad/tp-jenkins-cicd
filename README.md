# TP Jenkins CI/CD – Ferid SAAD

Formateur : Wahid Hamdi

Ce compte rendu décrit le déploiement d'une application Spring Boot avec Docker, Docker Hub, Kubernetes (K3s) et Jenkins (jobs Freestyle).

- Application : <https://github.com/wahid007/Jenkins-Demo.git>
- Image Docker Hub : <https://hub.docker.com/r/feridsaad/jenkins-demo>
- Dépôt des scripts du job Freestyle (étape 3) : <https://github.com/ferid-saad/jenkins-freestyle-scripts>

## 1. Environnement

VM Ubuntu 26.04 Server avec Java 21, Maven 3.9, Docker, K3s (Kubernetes) et Jenkins.

![Environnement](images/environnement.png)

![Maven](images/maven.png)

## 2. Workflow manuel (sans Jenkins)

L'application écoute sur le port **2222** (`server.port=2222` dans `application.properties`). Ce port est utilisé partout (Dockerfile, `docker run`, Kubernetes).

### 2.1 Dockerfile

```dockerfile
# Image de base : Java 17 (JRE)
FROM eclipse-temurin:17-jre
# Port de l'application
EXPOSE 2222
# Dossier de travail dans le conteneur
WORKDIR /app
# Copie du JAR généré par Maven
COPY target/devOpsDemo-0.0.1-SNAPSHOT.jar app.jar
# Commande exécutée au démarrage du conteneur
CMD ["java", "-jar", "app.jar"]
```

### 2.2 Build de l'image

```bash
mvn clean install
docker build -t jenkins-demo:1.0 .
docker images | grep jenkins-demo
```

![Docker images](images/dockerimages.png)

### 2.3 Push sur Docker Hub

1. Connexion à Docker Hub :

```bash
docker login -u feridsaad
```

![Login Docker Hub](images/login-dockerhub.png)

2. Tag de l'image, puis push :

```bash
docker tag jenkins-demo:1.0 feridsaad/jenkins-demo:1.0
docker push feridsaad/jenkins-demo:1.0
```

![Tag et push de l'image](images/image-tag.png)

3. Création d'un conteneur à partir de l'image Docker Hub :

```bash
docker run --detach --name myapp --publish 2222:2222 feridsaad/jenkins-demo:1.0
```

![Création du conteneur](images/creation-conteneur.png)

Image présente sur Docker Hub :

![Docker Hub](images/dockerhub.png)

### 2.4 Déploiement sur Kubernetes (K3s)

Fichier `deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-app-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spring-app
  template:
    metadata:
      labels:
        app: spring-app
    spec:
      containers:
        - name: spring-app-container
          image: feridsaad/jenkins-demo:1.0
          ports:
            - containerPort: 2222
```

Fichier `service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: spring-app-service
spec:
  selector:
    app: spring-app
  ports:
    - protocol: TCP
      port: 2222
      targetPort: 2222
      nodePort: 30222
  type: NodePort
```

Déploiement du Deployment :

```bash
kubectl apply -f deployment.yaml
kubectl get pods
```

![Pods créés](images/creation-pods.png)

Création du Service :

```bash
kubectl apply -f service.yaml
kubectl get svc
```

![Service créé](images/creation-svc.png)

Test de l'application :

```bash
curl http://localhost:30222
```

![Test de l'application](images/test.png)

![curl sur le port 30222](images/curl-30222.png)

## 3. Jenkins Freestyle

### Étape 1 : job `freestyle_demo`

Étape de build « Exécuter un script shell » :

```bash
echo 'Bonjour'
ls -l
echo 'Bonjour DevOps' > test.txt
ls -l
```

Le fichier `test.txt` est créé dans `/var/lib/jenkins/workspace/freestyle_demo`.

![Configuration du job](images/freestyle.png)

![Console du job](images/freestyle-demo.png)

### Étape 2 : exécution de `Test.java`

Fichier `Test.java`, affichant `Hi Master DevOps`, ajouté au job avec la commande `java Test.java`.

![Test.java](images/test-java.png)

![Console du build](images/console-job2.png)

### Étape 3 : script récupéré depuis GitHub

Le job clone le dépôt <https://github.com/ferid-saad/jenkins-freestyle-scripts> (section « Gestion du code source »), qui contient `demo.sh` et `Test.java`. L'étape de build exécute :

```bash
bash demo.sh
```

![Bonjour depuis GitHub](images/bonjour%20depuis%20github.png)

### Étape 4 : déclenchement automatique et nettoyage

- Déclencheur « Construire périodiquement » : `H/5 * * * *` (toutes les 5 minutes).
- « Supprimer les anciens builds » : conservation des 2 derniers builds.
- « Delete workspace before build starts » : nettoyage du workspace avant chaque build.

![Planning](images/planning.png)

![Suppression des anciens builds](images/supprimer-dernier-build.png)

![Suppression du workspace](images/delete-workspace.png)

Résultat : seuls les 2 derniers builds restent dans l'historique.

![Il reste 2 builds](images/reste-2.png)

### Étape 5 : challenge, un job Freestyle qui automatise tout

#### 5.1 Donner à Jenkins l'accès à Docker et à K3s

```bash
sudo usermod -aG docker jenkins
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
sudo systemctl restart jenkins
```

#### 5.2 Configuration du job `freestyle_challenge`

- **Gestion du code source** : Git, dépôt `https://github.com/wahid007/Jenkins-Demo.git`, branche `*/main`.
- **Identifiants** : le token Docker Hub est enregistré dans les Credentials de Jenkins (type « Username with password ») et injecté dans le job par « Use secret text(s) or file(s) » sous les variables `DOCKER_USER` et `DOCKER_PASS`. Le token n'apparaît donc jamais en clair dans le script.

![Code source](images/freestyle-chllenge-source.png)

![Credentials](images/freestyle-chllenge-credentials.png)

Script de l'étape « Exécuter un script shell » :

```bash
set -e
export KUBECONFIG=/var/lib/jenkins/.kube/config
IMAGE=feridsaad/jenkins-demo
TAG=$BUILD_NUMBER

# 1. Build Maven
mvn clean install -DskipTests

# 2. Dockerfile (celui du dépôt utilise une image dépréciée)
cat > Dockerfile << 'EOF'
FROM eclipse-temurin:17-jre
EXPOSE 2222
WORKDIR /app
COPY target/devOpsDemo-0.0.1-SNAPSHOT.jar app.jar
CMD ["java", "-jar", "app.jar"]
EOF

# 3. Build et push de l'image (tag = numéro du build)
docker build -t $IMAGE:$TAG .
echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
docker push $IMAGE:$TAG

# 4. Déploiement sur K3s avec la nouvelle image
sed "s|image: .*|image: $IMAGE:$TAG|" k8s.yml | kubectl apply -f -
kubectl rollout status deployment/spring-app-deployment --timeout=120s

# 5. Vérification
kubectl get pods
kubectl get svc
NODEPORT=$(kubectl get svc spring-app-service -o jsonpath='{.spec.ports[0].nodePort}')
curl -s http://localhost:$NODEPORT | head -5
```

Chaque build produit une image avec un tag unique (le numéro du build), ce qui force Kubernetes à redéployer la nouvelle version.

#### 5.3 Résultat

Build réussi : 2 pods `Running` et Service en NodePort.

![Build réussi](images/success.png)

Test final de l'application :

![Test final](images/test-final.png)

## 4. Difficultés rencontrées et solutions

| # | Problème | Cause | Solution |
|---|---|---|---|
| 1 | Le sujet utilise le port 8080 dans les YAML | L'application écoute sur 2222 (`server.port=2222`) | Utiliser 2222 dans le Dockerfile, `docker run` et Kubernetes |
| 2 | `Test.java` introuvable dans le job (`Could not find or load main class`) | Le workspace est remis à zéro au clonage Git | Ajouter `Test.java` au dépôt GitHub |
| 3 | `Could not find credentials entry with ID '${ dockerhub}'` | Identifiant saisi avec une syntaxe de variable | Sélectionner l'identifiant dans la liste déroulante |
| 4 | `password is empty` au `docker login` | Identifiant Jenkins sans mot de passe | Créer un token Docker Hub et un nouvel identifiant propre |
| 5 | `kubectl` : permission refusée pour l'utilisateur `jenkins` | `/etc/rancher/k3s/k3s.yaml` est réservé à `root` | Copier la config dans `/var/lib/jenkins/.kube/config` et exporter `KUBECONFIG` |
| 6 | Port du Service imprévisible | Sans `nodePort`, Kubernetes en choisit un au hasard (ex. 31475) | Lire le port avec `kubectl get svc` (ou fixer `nodePort`) |

## 5. Conclusion

Ce TP a permis de mettre en place une chaîne complète : compilation avec Maven, conteneurisation avec Docker, publication sur Docker Hub, puis déploiement sur Kubernetes (K3s). Elle a d'abord été réalisée à la main, puis automatisée avec des jobs Jenkins Freestyle (déclenchement périodique, récupération du code depuis GitHub, rétention des builds, injection sécurisée des identifiants). Le challenge final regroupe toutes les étapes dans un seul job, du build Maven jusqu'au déploiement sur K3s.