# Documentation
## Procédure et résultats des tests de connectivité

### 1. Connexion à la base de données
Installer le client MySQL sur l'instance EC2 Nextcloud :

```bash
sudo yum install -y mysql
```

Pour se connecter à la base de données, il faut utiliser le client MySQL en ligne de commande. Voici la commande à exécuter :

```bash
mysql -h <endpoint> -u <username> -p
```
![alt text](image.png)

## 2. Création d'une base de données test

Une fois connecté à la base de données, on peut créer une base de données de test. Voici les commandes à exécuter :

```sql
CREATE DATABASE testdb;
USE testdb;
CREATE TABLE testtable (id INT, name VARCHAR(20));
INSERT INTO testtable VALUES (1, 'John');
```
![alt text](image-1.png)

## 3. Procédure de test de failover

Pour tester la résilience de la base de données, on va simuler une panne de l'instance RDS en arrêtant l'instance manuellement. Voici les étapes à suivre :

1. Se connecter à la console AWS et trouver l'instance RDS à arrêter.
2. Arrêter l'instance RDS en utilisant l'option "Stop instance".
3. Attendre quelques minutes pour que l'instance soit arrêtée.
4. Vérifier l'état de l'instance pour confirmer qu'elle est bien arrêtée.
5. Se connecter à l'instance EC2 Nextcloud et essayer de se connecter à la base de données.
![alt text](image-2.png)

## 4. Résultats du test de failover

Après avoir arrêté l'instance RDS, on constate que l'instance EC2 Nextcloud n'arrive plus à se connecter à la base de données. Cela confirme que la panne de l'instance RDS a impacté la disponibilité de la base de données.
Une fois l'instance RDS redémarrée, l'instance EC2 Nextcloud peut à nouveau se connecter à la base de données sans perte de données.

![alt text](image-3.png)

## 5. Conclusion

Ce test de failover a permis de valider la résilience de la base de données RDS face à une panne de l'instance. En redémarrant l'instance RDS, on a pu rétablir l'accès à la base de données sans perte de données. Cela démontre l'efficacité de RDS comme solution de base de données cloud pour assurer la disponibilité et la continuité des services.