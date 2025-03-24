# provisioning
User's provisioning  for Debian
# Prérequis
Le téléchargement du script nécessite GIT ou peut être directement télécharger à partir du repos [repos Github](https://github.com/YannHamonic/provisioning)
L'installation de GIT ou l'exécution du script nécessite des privilèges administrateurs.
# Installation de GIT
sudo apt update && sudo apt install git
# Importation du script
git clone https://github.com/YannHamonic/provisioning
# Utilisation
./provisionning_users.sh -f  <users.json> \[-v\] \[-h\]

Le fichier des utilisateurs "users.json" doit être au format JSON.
Exemple :
```JSON
{
  "users": [
    {
      "username": "user1",
      "group": "devs",
      "ip": "10.170.12.1",
      "public_key": "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDIA/wzeamzAIf2ZwQ1fZgFzkfqqDaOL2jx6wSF1vlRPLIAC7vAhW1byZBH4l2jCN5+ixAvGvP+IvZ+Py/QRXC8= yann@YH-CLT-AA0001",
      "home_quota_gb": 50
    },
    {
      "username": "user2",
      "group": "devs",
      "ip": "10.170.12.2",
      "public_key": "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAPLfA+nyBVbNdmUyXtxLpsNnECo2fsEyALdsC+7XQZc/D7oIL8SOCGTz653Ce3QE50NXaKRqeyODezjTNTVlew= yann@YH-CLT-AA0001",
      "home_quota_gb": 100
    }
  ]
}
```