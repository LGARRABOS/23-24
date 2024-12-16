1. Contraintes Liées à la Haute Disponibilité (Réseau)

Le VPC comprend trois sous-réseaux publics et trois sous-réseaux privés répartis sur plusieurs zones de disponibilité (data.aws_availability_zones.available.names garantit qu'ils sont dans des zones différentes).

Une passerelle NAT dans un sous-réseau public fournit un accès Internet pour les instances privées, assurant une tolérance aux pannes grâce à une architecture haute disponibilité.

2. Contraintes Liées à la Nomenclature des Ressources

Une convention de nommage cohérente utilisant local.name garantit que toutes les ressources suivent le format <username>-<project>.

Les balises "Name" et "Owner" sont appliquées à toutes les ressources en utilisant local.tags pour qu'elles soient toute taguées de manière identique.

3. Contraintes Liées à l'Authentification SSH sur les Instances EC2

Des paires de clés distinctes (aws_key_pair.bastion et aws_key_pair.nextcloud) sont utilisées pour le bastion et les instances Nextcloud, améliorant la sécurité.

4. Contraintes Liées à l'Accessibilité SSH de l'Hôte Bastion

Mise en œuvre :

L'hôte bastion dispose d'un groupe de sécurité (aws_security_group.bastion_sg) permettant l'accès SSH uniquement à partir d'une IP spécifique (celle de notre instance Cloud9).

5. Contraintes Liées à l'Accessibilité SSH des Instances Nextcloud

Le groupe de sécurité des instances Nextcloud (aws_security_group.nextcloud_sg) n'autorise l'accès qu'à partir de l'hôte bastion, garantissant un accès sécurisé et restreint.

6. Contraintes Liées à l'Utilisation du Service EC2 Instance Connect

EC2 Instance Connect est désactivé pour les instances Nextcloud et le bastion, car l'accès SSH est géré via des clés SSH. Ainsi, l'accès est limité aux utilisateurs autorisés.

7. Contraintes Liées à la Sécurité des Fichiers sur le Système de Fichiers Partagé

Le système EFS est chiffré (encrypted = true) en utilisant le chiffrement géré par AWS.

Le groupe de sécurité associé (aws_security_group.efs_sg) limite l'accès au bloc CIDR du VPC.

8. Contraintes Liées à l'Accessibilité du Système de Fichiers Partagé

Les points de montage pour l'EFS (aws_efs_mount_target) sont déployés dans chaque sous-réseau privé pour garantir l'accessibilité dans le VPC. Ainsi en cas de panne d'une zone, le système de fichiers reste accessible et synchronisé via une autre zone.

9. Contraintes Liées à la Haute Disponibilité du Système de Fichiers Partagé

Les points de montage EFS dans plusieurs sous-réseaux garantissent la redondance et la haute disponibilité.

10. Contraintes Liées à l'Accessibilité de la Base de Données

Mise en œuvre :

Le groupe de sécurité de la base de données (aws_security_group.nextcloud_db_sg) n'autorise l'accès qu'à partir du groupe de sécurité des instances Nextcloud ainnsi la base de données est accessible uniquement par l'instance Nextcloud.

11. Contraintes Liées à la Haute Disponibilité de la Base de Données

L'instance RDS (aws_db_instance.nextcloud_db) est configurée avec multi_az = true, permettant un basculement automatique en cas de panne de zone.

12. Contraintes Liées à l'Accessibilité de l'Application Nextcloud

Un équilibreur de charge applicatif public (aws_lb.nextcloud) garantit une accessibilité externe via un nom DNS configuré dans Route 53.

13. Contraintes Liées à la Haute Disponibilité de l'Application

L'équilibreur de charge applicatif s'étend sur plusieurs zones de disponibilité et distribue le trafic vers les instances Nextcloud permettant une haute disponibilité de l'application.

14. Contraintes Liées à l'Élasticité de l'Application


15. Contraintes Liées à la Scalabilité de l'Application



16. Contraintes Liées à l'Authentification des Instances EC2 aux API AWS

Les instances Nextcloud sont associées à un rôle IAM (aws_iam_role.nextcloud_role) avec des politiques appropriées pour accéder aux ressources AWS nécessaires limitant ainsi les permissions aux actions spécifiques requises.

17. Contraintes Liées aux Permissions entre Nextcloud et le Bucket S3

Une politique IAM (aws_iam_role_policy.nextcloud_s3_policy) attachée au rôle autorise des actions S3 spécifiques (p s3:GetObject , s3:PutObject etc...) sur le bucket Nextcloud qui permet à l'application Nextcloud d'accéder et d'interargiravec les objets S3.

18. Contraintes Liées aux Permissions sur le Bucket S3

Le bucket S3 (aws_s3_bucket.nextcloud_bucket) utilise le chiffrement côté serveur avec une clé KMS (aws_kms_key.mykey) pour la sécurité des objets.