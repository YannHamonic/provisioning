# Consignes générales 

Un fichier **README au format texte ou markdown** doit décrire quels sont les pré-requis et comment les scripts s'installent (package Python pip, paquet Debian, téléchargement depuis un serveur en ligne, etc.) 

Les scripts doivent proposer une **aide en ligne** documentant les paramètres qu'ils acceptent, grâce à l'option -h. 

Les scripts doivent gérer les cas d'erreur et se terminer sans "crasher". Par exemple en cas de : 
- dépendance manquante
- entrée utilisateur invalide
- erreur de connexion réseau...

Les scripts (notamment ceux SUID root) doivent vérifier que l'utilisateur ne peut pas effectuer une escalade de privilège en passant des paramètres corrompus ou mal-formés. 

Les scripts devront être exécutables sans erreur sur une Debian 12 fraîchement installée. Ils peuvent comporter un ou plusieurs fichiers, à votre convenance.
# Soutenance le 25 mars (à confirmer) 

En plus du livrable technique (archive compressée ou dépôt git), vous devrez présenter au cours d’une soutenance de 10 à 15mn (+ 10mn de questions) : 
- Un résumé très rapide du besoin
- Une explication de vos choix techniques
- Le fonctionnement de votre solution, en incluant une démo
Concevoir un script capable de lire un fichier JSON contenant les noms des utilisateurs, leurs groupes, leurs clés publiques et leurs ips autorisées qui leur permettra de se connecter via ssh au serveur debian commun. 

Le script devra : 
- créer les groupes et les utilisateurs 
- déposer les clés dans les bons espaces 
- configurer ssh pour n'autoriser que les connexions à clé 
- gérer les ips autorisées à se connecter (FW, config ssh) 
- chaque utilisateur disposera d'un espace personnel dédié dont la taille sera également configurée dans le fichier d’entrée.