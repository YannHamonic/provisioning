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
./provisionning_users.sh \[fv\]
# -f fichier
            ;;
v)  verbeux=true
            ;;
:)  echo "l'option $OPTARG requiert un nom de fichier en argument"
            exit 0
            ;;
h)  show_help()
            ;;
?)  show_help()
            ;;
\?) echo "L'option $OPTARG est invalide"
