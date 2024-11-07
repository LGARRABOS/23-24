# Documentation

## 1. Documentation du Script User Data

Le script *user data* est un script Bash exécuter lors de la création de l'instance EC2 *Nextcloud* (vous pouvre le retrouver dans le fichier terraform) il permet le montage du système de fichiers EFS.

```bash
#!/bin/bash
yum update -y
yum install -y amazon-efs-utils
mkdir -p /mnt/efs
mount -t efs -o tls ${aws_efs_file_system.efs.id}:/ /mnt/efs
echo "${aws_efs_file_system.efs.id}:/ /mnt/efs efs _netdev,tls 0 0" >> /etc/fstab
sudo chmod 777 /mnt/efs
```

1. `#!/bin/bash` : Spécifie que le script doit être exécuté avec l'interpréteur Bash.
2. `yum update -y` : Met à jour tous les paquets installés pour s'assurer que l'instance EC2 est à jour avec les derniers correctifs de sécurité.
3. `yum install -y amazon-efs-utils` : Installe l'utilitaire *amazon-efs-utils*, nécessaire pour monter un système de fichiers EFS.
4. `mkdir -p /mnt/efs` : Crée le répertoire */mnt/efs* qui servira de point de montage pour le système de fichiers EFS.
5. `mount -t efs -o tls ${aws_efs_file_system.efs.id}:/ /mnt/efs` : Monte le système de fichiers EFS en utilisant le protocole TLS pour sécuriser la connexion. Le *file system ID* est injecté dynamiquement par Terraform.
6. `echo "${aws_efs_file_system.efs.id}:/ /mnt/efs efs _netdev,tls 0 0" >> /etc/fstab` : Ajoute une entrée au fichier `/etc/fstab` pour que le système de fichiers EFS soit automatiquement monté lors du redémarrage de l'instance.
7. `sudo chmod 777 /mnt/efs` : Donne les permissions nécessaires pour que l'utilisateur puisse écrire et lire des fichiers sur le montage EFS.

## 2. Description de la Procédure de Test Réalisée

Pour valider la résilience et la continuité des données stockées sur EFS, la procédure suivante a été mise en place :

1. **Création d'un Fichier sur le Montage EFS** :
   - Connexion à l'instance EC2 "Nextcloud" via le bastion($ ssh -i ssh/nextcloud -o "ProxyCommand=ssh -W %h:%p -i ssh/bastion ec2-user@<IP DU NEXTCLOUD>" ec2-user@<IP DU BASTION>) .
   - Création d'un fichier de test dans le répertoire monté EFS (`/mnt/efs/test_file.txt`).

2. **Simulation d'une Panne d'AZ** :
   - Modification du sous-réseau de l'instance EC2 "Nextcloud" pour la déployer dans un autre sous-réseau (situé dans une autre zone de disponibilité - AZ).
   - Déploiement d'une nouvelle instance EC2 en utilisant `terraform apply` (L'ancienne instance EC2 est automatiquement supprimer par terraform qui vas en déployer une nouvelle à la place).

3. **Vérification de l'Accès aux Données** :
   - Connexion à la nouvelle instance EC2 "Nextcloud" via le bastion($ ssh -i ssh/nextcloud -o "ProxyCommand=ssh -W %h:%p -i ssh/bastion ec2-user@<IP DU NEXTCLOUD>" ec2-user@<IP DU BASTION>).
   - Vérification de la présence du fichier de test sur le montage EFS (`cat /mnt/efs/test_file.txt`).

## 3. Conclusions du Proof of Concept (POC)
En conclusion, ce POC a démontré l'efficacité d'EFS comme solution de stockage partagé résiliente en effet si jamais une resssource EC2 de Nextcloud vener à tomber dans une zone de disponibilité, une nouvelle instance EC2 peut être déployée dans une autre zone de disponibilité et accéder aux données stockées sur EFS sans perte de données.
