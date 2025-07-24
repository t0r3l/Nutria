# Guide de Déploiement - Services Nutria

## Vue d'ensemble

Ce guide décrit les procédures pour déployer les services d'optimisation de repas Nutria sur AWS, incluant les déploiements Lambda pour le calcul des targets et Fargate/Bucket S3 pour la sélection des ingrédients.

### Architecture des ressources AWS

```
┌─────────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                       │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   Internet Gateway                          ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                  │
│         ┌────────────────────────────────────────┐              │
│         │        Subnet Public 1                 │              │
│         │        (10.0.1.0/24)                   │              │
│         │        Zone eu-west-1a                 │              │
│         │                                        │              │
│         │         ┌──────────────┐               │              │
│         │         │    App3      │               │              │
│         │         │  Optimizer   │               │              │
│         │         │  (Fargate)   │               │              │
│         │         └──────────────┘               │              │
│         └────────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                               │
    ┌─────────────────────────────────────────────────────────────┐
    │                    Services AWS externes                   │
    │                                                             │
    │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
    │  │   Lambda        │  │   S3 Bucket     │  │ CloudWatch  │ │
    │  │                 │  │                 │  │             │ │
    │  │ • Target Calc   │  │ • nutrition-data│  │ • Log Groups│ │
    │  │                 │  │                 │  │ • Metrics   │ │
    │  └─────────────────┘  └─────────────────┘  └─────────────┘ │
    │                                                             │
    │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
    │  │   ECR Repos     │  │   API Gateway   │  │     IAM     │ │
    │  │                 │  │                 │  │             │ │
    │  │ • app3-optimizer│  │ • REST API      │  │ • Roles     │ │
    │  │                 │  │ • Endpoints     │  │ • Policies  │ │
    │  └─────────────────┘  └─────────────────┘  └─────────────┘ │
    └─────────────────────────────────────────────────────────────┘
```

### Ressources déployées et leurs relations

#### 1. **Infrastructure réseau**
- **VPC** (`vpc-0ae160c727ceec708`) : Réseau virtuel isolé avec plage 10.0.0.0/16
- **Internet Gateway** : Passerelle pour l'accès Internet
- **Sous-réseau public** : 
  - `subnet-052f7cf068cca1ffd` (eu-west-1a)
- **Security Group** (`sg-08743755ec203fc45`) : Firewall autorisant le port 8080

#### 2. **Services de calcul**

##### **Lambda Functions**
- **Target Calculator** : Calcul des objectifs nutritionnels (calories, protéines, lipides, glucides) basé sur les paramètres utilisateur (âge, poids, taille, activité)

##### **ECS Fargate (App3 uniquement)**
- **Cluster ECS** (`nutria-dev-cluster`) : Orchestrateur de conteneurs
- **Service déployé** :
  - `app3-optimizer-tvpgks` : Service d'optimisation avec filtrage par régime alimentaire

#### 3. **API Management**
- **API Gateway** : Point d'entrée REST pour tous les services
  - Endpoints Lambda pour les calculs de targets
  - Proxy vers Fargate pour l'optimisation des repas

#### 4. **Stockage**

##### **Images Docker (ECR)**
- `nutria/app3-optimizer` : Images du service d'optimisation App3

##### **Données (S3)**
- **Bucket nutrition** (`nutria-dev-nutrition-data-cec19e3e36b20deb`) :
  - `data/products_nutrition.csv` : Base de données des aliments

#### 5. **Monitoring et logs**
- **CloudWatch** :
  - Log Groups Lambda : `/aws/lambda/target-calculator`
  - Log Groups ECS : `/ecs/app3-optimizer-tvpgks`
  - Metrics et alarmes personnalisées

#### 6. **Gestion des permissions**
- **Rôles IAM** :
  - `lambda-execution-role` : Exécution des fonctions Lambda
  - `nutria-dev-ecs-execution-role` : Exécution des tâches ECS
  - `nutria-dev-ecs-task-role` : Accès aux ressources (S3, CloudWatch)
  - `api-gateway-role` : Invocation des services

### Flux de données

```
Client → API Gateway → Lambda Function (calcul targets)
                  │            ↓
                  │    Réponse JSON (calories, protéines, lipides, glucides)
                  │
                  └→ Fargate App3 → S3 Bucket (nutrition-data)
                           ↓               ↓
                   Algorithme optimisation + Filtrage régime
                           ↓
                   Réponse JSON (plan repas personnalisé)
```

### Relations entre ressources

1. **API Gateway** route les requêtes vers Lambda ou Fargate selon l'endpoint
2. **Lambda Function** calcule les targets nutritionnels sans accès S3
3. **ECS Fargate (App3)** utilise le **sous-réseau public** pour obtenir des IP publiques
4. **Security Group** filtre le trafic entrant sur le port 8080 pour Fargate
5. **Rôles IAM** permettent l'accès aux ressources :
   - Lambda : CloudWatch uniquement
   - Fargate : accès S3 nutrition-data + ECR + CloudWatch
6. **CloudWatch** collecte tous les logs et métriques

### Synthèse de l'architecture de l'application

#### 1. **Séparation des responsabilités**
- **Lambda** : Calcul léger et rapide des objectifs nutritionnels (calories, protéines, lipides, glucides)
- **Fargate (App3)** : Traitement lourd d'optimisation de repas avec accès aux données nutritionnelles
- **Raison** : Optimiser les coûts et performances selon la complexité des tâches

#### 2. **Point d'entrée unique (API Gateway)**
- **Endpoints Lambda** : `/calculate-targets` pour les calculs rapides
- **Endpoints Fargate** : `/optimize-meal` pour l'optimisation complexe
- **Raison** : Interface unifiée pour les clients, routage intelligent des requêtes

#### 3. **Stockage centralisé des données (S3)**
- **Un seul bucket** : `nutria-dev-nutrition-data-cec19e3e36b20deb`
- **Structure simple** : `/data/products_nutrition.csv`
- **Raison** : Source unique de vérité pour les données nutritionnelles, accessible uniquement par Fargate

#### 4. **Architecture réseau simplifiée**
- **VPC dédié** : Isolation complète de l'infrastructure
- **Un seul subnet public** : Simplicité et réduction des coûts
- **Internet Gateway** : Accès externe pour les APIs
- **Raison** : Architecture minimale suffisante pour les besoins actuels

#### 5. **Sécurité par couches**
- **Security Group** : Restriction au port 8080 uniquement
- **Rôles IAM spécifiques** : Lambda sans S3, Fargate avec S3 lecture seule
- **Pas d'accès SSH** : Conteneurs Fargate non accessibles directement
- **Raison** : Principe du moindre privilège, surface d'attaque minimale

#### 6. **Optimisation des conteneurs**
- **Dockerfiles multi-stages** : Images légères en production
- **Wheels pré-compilés** : Build rapide (<5 min)
- **Utilisateur non-root** : Sécurité renforcée
- **Raison** : Performance, sécurité et rapidité de déploiement

#### 7. **Monitoring centralisé (CloudWatch)**
- **Logs séparés** : `/aws/lambda/*` et `/ecs/*`
- **Métriques automatiques** : CPU, mémoire, requêtes
- **Health checks** : Surveillance de la disponibilité
- **Raison** : Visibilité complète sur l'état et performances

#### 8. **Mode hybride local/AWS**
- **Détection automatique** : Variable `ENVIRONMENT`
- **Données locales** : Tests sans dépendance AWS
- **Même code** : Portable entre environnements
- **Raison** : Développement et tests simplifiés

#### 9. **Fonctionnalités avancées (App3)**
- **Filtrage par régime** : Vegan, Végétarien, Halal, Casher
- **Optimisation hybride** : NNLS + LSQ pour meilleurs résultats
- **Gestion des portions** : Respect des quantités maximales
- **Raison** : Répondre aux besoins spécifiques des utilisateurs

#### 10. **Évolutivité prévue**
- **Services indépendants** : Lambda et Fargate découplés
- **API Gateway extensible** : Ajout facile de nouveaux endpoints
- **Infrastructure as Code ready** : Migration Terraform possible
- **Raison** : Croissance future sans refonte majeure

### Services opérationnels

| Service | Type | URL/ARN | Fonctionnalités |
|---------|------|---------|-----------------|
| Target Calculator | Lambda | `arn:aws:lambda:eu-west-1:xxx:function:target-calc` | Calcul objectifs nutritionnels |
| App3 Optimizer | Fargate | http://34.245.111.159:8080 | Optimisation avec régimes alimentaires |
| API Gateway | REST API | `https://api.nutria.aws.com` | Point d'entrée unifié |

## Étape 1 : Création du cluster ECS

### Création complète de l'infrastructure

#### Étape 1.1 : Créer le cluster ECS
```bash
# Créer le cluster ECS Fargate
aws ecs create-cluster --cluster-name nutria-dev-cluster --region eu-west-1

# Vérifier la création
aws ecs list-clusters --region eu-west-1
```

#### Étape 1.2 : Créer le VPC et les ressources réseau
```bash
# Créer un VPC dédié
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region eu-west-1

# Récupérer l'ID du VPC créé
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=cidr-block,Values=10.0.0.0/16" --query 'Vpcs[0].VpcId' --output text --region eu-west-1)

# Créer une Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text --region eu-west-1)

# Attacher la gateway au VPC
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region eu-west-1

# Créer le sous-réseau public
SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone eu-west-1a --query 'Subnet.SubnetId' --output text --region eu-west-1)

# Activer l'auto-attribution d'IP publiques
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_1 --map-public-ip-on-launch --region eu-west-1

# Créer une table de routage
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text --region eu-west-1)

# Ajouter une route vers Internet
aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region eu-west-1

# Associer le sous-réseau à la table de routage
aws ec2 associate-route-table --route-table-id $ROUTE_TABLE_ID --subnet-id $SUBNET_1 --region eu-west-1
```

#### Étape 1.3 : Créer le Security Group
```bash
# Créer un security group pour les services Fargate
SG_ID=$(aws ec2 create-security-group --group-name nutria-fargate-sg --description "Security group for Nutria Fargate services" --vpc-id $VPC_ID --query 'GroupId' --output text --region eu-west-1)

# Autoriser le trafic HTTP sur le port 8080
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region eu-west-1

# Autoriser le trafic HTTPS sortant (pour ECR et S3)
aws ec2 authorize-security-group-egress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --region eu-west-1
aws ec2 authorize-security-group-egress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region eu-west-1
```

#### Étape 1.4 : Créer les rôles IAM nécessaires
```bash
# Créer le rôle d'exécution ECS
aws iam create-role --role-name nutria-dev-ecs-execution-role --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

# Attacher la politique d'exécution ECS
aws iam attach-role-policy --role-name nutria-dev-ecs-execution-role --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Créer le rôle de tâche ECS
aws iam create-role --role-name nutria-dev-ecs-task-role --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}'

# Créer une politique pour l'accès S3
aws iam create-policy --policy-name nutria-s3-access --policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::nutria-dev-nutrition-data-*",
        "arn:aws:s3:::nutria-dev-nutrition-data-*/*"
      ]
    }
  ]
}'

# Attacher la politique S3 au rôle de tâche
aws iam attach-role-policy --role-name nutria-dev-ecs-task-role --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/nutria-s3-access
```

#### Étape 1.5 : Créer le bucket S3
```bash
# Créer le bucket S3
aws s3 mb s3://nutria-dev-nutrition-data-cec19e3e36b20deb --region eu-west-1

# Créer le dossier data
aws s3api put-object --bucket nutria-dev-nutrition-data-cec19e3e36b20deb --key data/

# Copier le fichier CSV vers S3
aws s3 cp /chemin/vers/products_nutrition.csv s3://nutria-dev-nutrition-data-cec19e3e36b20deb/data/products_nutrition.csv
```

### Ressources créées
Après ces étapes, vous disposerez de :
- **Cluster ECS** : `nutria-dev-cluster`
- **VPC** : avec CIDR 10.0.0.0/16
- **Sous-réseau public** : dans la zone eu-west-1a
- **Security Group** : autorisant le port 8080 en entrée
- **Rôles IAM** :
  - `nutria-dev-ecs-execution-role` : pour l'exécution des tâches
  - `nutria-dev-ecs-task-role` : pour l'accès aux ressources AWS (S3)
- **Bucket S3** : `nutria-dev-nutrition-data-cec19e3e36b20deb` avec les données

## Prérequis pour les déploiements

### 1. AWS CLI configuré avec les bonnes permissions

#### Installation d'AWS CLI
```bash
# Sur Ubuntu/Debian
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Vérifier l'installation
aws --version
```

#### Configuration des credentials
```bash
# Configuration interactive
aws configure

# Ou via variables d'environnement
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=eu-west-1
```

#### Permissions IAM requises
L'utilisateur AWS doit avoir les permissions suivantes :
- `AmazonECS_FullAccess` - Gestion des services ECS
- `AmazonEC2ContainerRegistryFullAccess` - Gestion ECR
- `CloudWatchLogsFullAccess` - Gestion des logs
- `AmazonS3ReadOnlyAccess` - Lecture du bucket S3
- `IAMReadOnlyAccess` - Lecture des rôles IAM

#### Vérification de la configuration
```bash
# Tester la connectivité AWS
aws sts get-caller-identity

# Tester l'accès au cluster ECS
aws ecs describe-clusters --clusters nutria-dev-cluster --region eu-west-1
```

### 2. Docker installé et fonctionnel

#### Installation de Docker
```bash
# Sur Ubuntu/Debian
sudo apt update
sudo apt install -y docker.io docker-compose

# Démarrer le service Docker
sudo systemctl start docker
sudo systemctl enable docker

# Ajouter votre utilisateur au groupe docker (optionnel)
sudo usermod -aG docker $USER
# Redémarrer la session pour appliquer les changements
```

#### Vérification de Docker
```bash
# Tester Docker
docker --version
docker info

# Test de fonctionnement
docker run hello-world
```

#### Configuration pour ECR
```bash
# Tester la connexion à ECR
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 539247448895.dkr.ecr.eu-west-1.amazonaws.com
```

### 3. Accès au cluster ECS `nutria-dev-cluster`

#### Vérification de l'existence du cluster
```bash
aws ecs describe-clusters --clusters nutria-dev-cluster --region eu-west-1
```

#### Vérification du cluster existant
Si le cluster a déjà été créé selon l'Étape 1, vérifiez simplement son existence :
```bash
aws ecs describe-clusters --clusters nutria-dev-cluster --region eu-west-1
```

#### Ressources réseau requises
Le cluster doit avoir accès aux ressources suivantes :
- **VPC** : `vpc-0ae160c727ceec708`
- **Subnet public** : `subnet-052f7cf068cca1ffd`
- **Security Group** : `sg-08743755ec203fc45` (autorisant le port 8080)

#### Rôles IAM requis
- **Rôle de tâche** : `nutria-dev-ecs-task-role`
- **Rôle d'exécution** : `nutria-dev-ecs-execution-role`

### 4. Bucket S3 `nutria-dev-nutrition-data-cec19e3e36b20deb` avec les données nutritionnelles

#### Vérification du bucket
```bash
# Vérifier l'existence du bucket
aws s3 ls s3://nutria-dev-nutrition-data-cec19e3e36b20deb --region eu-west-1

# Vérifier le fichier de données
aws s3 ls s3://nutria-dev-nutrition-data-cec19e3e36b20deb/data/ --region eu-west-1
```

#### Structure attendue du bucket
```
nutria-dev-nutrition-data-cec19e3e36b20deb/
└── data/
    └── products_nutrition.csv
```

#### Création du bucket (si nécessaire)
```bash
# Créer le bucket S3
aws s3 mb s3://nutria-dev-nutrition-data-cec19e3e36b20deb --region eu-west-1

# Créer le dossier data
aws s3api put-object --bucket nutria-dev-nutrition-data-cec19e3e36b20deb --key data/
```

#### Upload des données nutritionnelles
```bash
# Copier le fichier CSV vers S3
aws s3 cp /chemin/vers/products_nutrition.csv s3://nutria-dev-nutrition-data-cec19e3e36b20deb/data/products_nutrition.csv

# Vérifier l'upload
aws s3 ls s3://nutria-dev-nutrition-data-cec19e3e36b20deb/data/products_nutrition.csv --human-readable
```

#### Permissions du bucket
Le bucket doit autoriser la lecture par le rôle `nutria-dev-ecs-task-role` :

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::539247448895:role/nutria-dev-ecs-task-role"
            },
            "Action": [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::nutria-dev-nutrition-data-cec19e3e36b20deb",
                "arn:aws:s3:::nutria-dev-nutrition-data-cec19e3e36b20deb/*"
            ]
        }
    ]
}
```

### Script de vérification des prérequis

Créer un script `check-prerequisites.sh` :

```bash
#!/bin/bash

echo "Vérification des prérequis..."

# 1. AWS CLI
if command -v aws &> /dev/null; then
    echo "[OK] AWS CLI installé: $(aws --version)"
    if aws sts get-caller-identity &> /dev/null; then
        echo "[OK] AWS CLI configuré correctement"
    else
        echo "[ERREUR] AWS CLI non configuré"
        exit 1
    fi
else
    echo "[ERREUR] AWS CLI non installé"
    exit 1
fi

# 2. Docker
if command -v docker &> /dev/null; then
    echo "[OK] Docker installé: $(docker --version)"
    if docker info &> /dev/null; then
        echo "[OK] Docker fonctionnel"
    else
        echo "[ERREUR] Docker daemon non démarré"
        exit 1
    fi
else
    echo "[ERREUR] Docker non installé"
    exit 1
fi

# 3. Cluster ECS
if aws ecs describe-clusters --clusters nutria-dev-cluster --region eu-west-1 &> /dev/null; then
    echo "[OK] Cluster ECS nutria-dev-cluster accessible"
else
    echo "[ERREUR] Cluster ECS nutria-dev-cluster inaccessible"
    exit 1
fi

# 4. Bucket S3
if aws s3 ls s3://nutria-dev-nutrition-data-cec19e3e36b20deb/data/products_nutrition.csv &> /dev/null; then
    echo "[OK] Bucket S3 et données nutritionnelles accessibles"
else
    echo "[ERREUR] Bucket S3 ou données nutritionnelles inaccessibles"
    exit 1
fi

echo "Tous les prérequis sont satisfaits !"
```

## Architecture des Services

### Services Fargate Déployés

1. **nutria-meal-optimizer-v2** - Service principal d'optimisation
2. **app3-optimizer-tvpgks** - Service avec filtrage par régime alimentaire

## Procédures de Déploiement

### 1. Déploiement Fargate avec Script Universel

#### Script de déploiement
```bash
./deploy-universal.sh <Dockerfile> [nom-service]
```

#### Exemple d'utilisation
```bash
# Déployer app3 avec Dockerfile optimisé
./deploy-universal.sh Dockerfile.fast-app3 app3-optimizer

# Le script génère automatiquement :
# - Nom de service : app3-optimizer-<suffix-aléatoire>
# - Repository ECR : nutria/app3-optimizer-<suffix-aléatoire>
```

### 2. Procédure Manuelle de Déploiement Fargate

#### Étape 1 : Créer le repository ECR
```bash
SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
SERVICE_NAME="app3-optimizer-${SUFFIX}"
REPO_NAME="nutria/app3-optimizer-${SUFFIX}"

aws ecr create-repository --repository-name ${REPO_NAME} --region eu-west-1
```

#### Étape 2 : Construire et pousser l'image Docker
```bash
# Connexion à ECR
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 539247448895.dkr.ecr.eu-west-1.amazonaws.com

# Construction de l'image
docker build -f ./fargate/Dockerfile.fast-app3 -t 539247448895.dkr.ecr.eu-west-1.amazonaws.com/${REPO_NAME}:latest .

# Push vers ECR
docker push 539247448895.dkr.ecr.eu-west-1.amazonaws.com/${REPO_NAME}:latest
```

#### Étape 3 : Créer la définition de tâche
```json
{
    "family": "app3-optimizer-tvpgks",
    "taskRoleArn": "arn:aws:iam::539247448895:role/nutria-dev-ecs-task-role",
    "executionRoleArn": "arn:aws:iam::539247448895:role/nutria-dev-ecs-execution-role",
    "networkMode": "awsvpc",
    "cpu": "1024",
    "memory": "2048",
    "requiresCompatibilities": ["FARGATE"],
    "containerDefinitions": [
        {
            "name": "app3-optimizer-tvpgks",
            "image": "539247448895.dkr.ecr.eu-west-1.amazonaws.com/nutria/app3-optimizer-tvpgks:latest",
            "portMappings": [{"containerPort": 8080, "hostPort": 8080, "protocol": "tcp"}],
            "essential": true,
            "environment": [
                {"name": "CSV_FILE_KEY", "value": "data/products_nutrition.csv"},
                {"name": "PORT", "value": "8080"},
                {"name": "S3_BUCKET_NAME", "value": "nutria-dev-nutrition-data-cec19e3e36b20deb"},
                {"name": "ENVIRONMENT", "value": "production"}
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/app3-optimizer-tvpgks",
                    "awslogs-region": "eu-west-1",
                    "awslogs-stream-prefix": "ecs"
                }
            },
            "healthCheck": {
                "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
                "interval": 30,
                "timeout": 5,
                "retries": 3,
                "startPeriod": 60
            }
        }
    ]
}
```

#### Étape 4 : Enregistrer la définition de tâche
```bash
# Créer le groupe de logs CloudWatch
aws logs create-log-group --log-group-name /ecs/app3-optimizer-tvpgks --region eu-west-1

# Enregistrer la définition de tâche
aws ecs register-task-definition --cli-input-json file://task-definition.json --region eu-west-1
```

#### Étape 5 : Créer le service ECS
```bash
aws ecs create-service \
  --cluster nutria-dev-cluster \
  --service-name app3-optimizer-tvpgks \
  --task-definition app3-optimizer-tvpgks:1 \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-052f7cf068cca1ffd],securityGroups=[sg-08743755ec203fc45],assignPublicIp=ENABLED}" \
  --region eu-west-1
```

### 3. Mise à Jour d'un Service Existant

#### Corriger les variables d'environnement
```bash
# Mettre à jour la définition de tâche avec les bonnes variables
aws ecs register-task-definition --cli-input-json file://task-definition-updated.json --region eu-west-1

# Mettre à jour le service
aws ecs update-service --cluster nutria-dev-cluster --service nom-service --task-definition nom-service:2 --region eu-west-1
```

## Dockerfiles Optimisés

### Dockerfile.fast-app3 (Recommandé)
- Utilise des wheels pré-compilés pour numpy, scipy, polars
- Construction rapide (< 5 minutes vs 45+ minutes)
- Image de production optimisée avec utilisateur non-root

### Variables d'Environnement Importantes

| Variable | Valeur | Description |
|----------|--------|-------------|
| `ENVIRONMENT` | `production` | Active le mode AWS (ne pas utiliser `dev`) |
| `S3_BUCKET_NAME` | `nutria-dev-nutrition-data-cec19e3e36b20deb` | Bucket S3 correct |
| `CSV_FILE_KEY` | `data/products_nutrition.csv` | Chemin du fichier CSV |
| `PORT` | `8080` | Port d'exposition du service |

## Tests et Validation

### Test de santé
```bash
curl -s http://<IP_SERVICE>:8080/health
```

### Test d'optimisation avec régime
```bash
curl -X POST http://<IP_SERVICE>:8080/optimize \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "target_array": [2000, 75, 50, 250]
    },
    "meal_fraction": 0.3,
    "solveur": "hybride",
    "sample_size": 500,
    "target_legumes": 100,
    "regime": "Vegan"
  }'
```

### Script de test rapide
```bash
# Utiliser le script de test fourni
./fargate/test3.sh
```

## Obtenir l'IP Publique d'un Service

```bash
# Lister les tâches du service
aws ecs list-tasks --cluster nutria-dev-cluster --service-name <NOM_SERVICE> --region eu-west-1

# Obtenir l'interface réseau
aws ecs describe-tasks --cluster nutria-dev-cluster --tasks <TASK_ARN> --region eu-west-1 --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text

# Obtenir l'IP publique
aws ec2 describe-network-interfaces --network-interface-ids <ENI_ID> --region eu-west-1 --query 'NetworkInterfaces[0].Association.PublicIp' --output text
```

## Dépannage

### Problèmes Courants

1. **Service en mode local au lieu d'AWS**
   - Vérifier que `ENVIRONMENT=production` (pas `dev`)
   - Redéployer avec la bonne définition de tâche

2. **Erreur S3 403 Forbidden**
   - Vérifier que `S3_BUCKET_NAME` pointe vers le bon bucket
   - Vérifier les permissions IAM du rôle de tâche

3. **Construction Docker lente**
   - Utiliser `Dockerfile.fast-app3` avec des wheels pré-compilés
   - Éviter la compilation depuis les sources

4. **Service ne démarre pas**
   - Vérifier les logs CloudWatch
   - Vérifier la configuration réseau (subnets, security groups)

## Ressources AWS Utilisées

- **Cluster ECS** : `nutria-dev-cluster`
- **Rôle de tâche** : `nutria-dev-ecs-task-role`
- **Rôle d'exécution** : `nutria-dev-ecs-execution-role`
- **Security Group** : `sg-08743755ec203fc45`
- **Subnet** : `subnet-052f7cf068cca1ffd`
- **Bucket S3** : `nutria-dev-nutrition-data-cec19e3e36b20deb`

## Services Actifs

### nutria-meal-optimizer-v2
- **URL** : http://34.245.22.84:8080
- **Version** : 2.0.0
- **Statut** : ✅ Opérationnel

### app3-optimizer-tvpgks
- **URL** : http://34.245.111.159:8080
- **Version** : 3.0.0
- **Statut** : ✅ Opérationnel
- **Fonctionnalités** : Filtrage par régime alimentaire (Vegan, Végétarien, Halal, etc.)