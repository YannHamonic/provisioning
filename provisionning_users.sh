#!/bin/bash

#-----------------
# Main
#-----------------

fichier=""
verbeux=false

while getopts ":f:vh" option
do
    echo "getopts a trouvé l'option $option"
    case $option in
        f)  fichier="$OPTARG"
            ;;
        v)  verbeux=true
            ;;
        :)  echo "l'option $OPTARG requiert un nom de fichier en argument"
            exit 0
            ;;
        h)  show_help
            ;;
        ?)  show_help()
            ;;
        \?) echo "L'option $OPTARG est invalide"
            exit 1
            ;;
    esac
done

if [ -f "$fichier" ]; then
    cat "$fichier"
else
    echo "Erreur : Le fichier '$fichier' n'existe pas."
    exit 1
fi

if [ "$verbeux" = true ]; then
    echo "Mode verbeux activé."
    echo "Lecture du fichier : $fichier"
fi

#-----------------
# show_help
#-----------------
# Affichage d'aide du script
# break du script
show_help(){
    echo "Le script $0 nécessite des options"
    echo "$0 -f <fichier .json> [-v] [-h]"
    exit 0
}

#-----------------
# check_file
#-----------------
# vérifier que le fichier existe et qu'il est bien au format json
# si le fichier n'est pas acceptable (check du json, des paramètres attendus) :
#   echo 'paramètres invalide' 
#   show_help())
# else return true

#-----------------
# add_user
#-----------------
# si le groupe n'existe pas :
#   - créer le groupe
# si l'utilisateur n'existe pas
#   - on ajoute l'utilisateur dans son groupe
#   - spécifier la taille (max?) de son /home
#
#-----------------
# add_ssh_access
#-----------------
# modifier la configuration ssh pour y ajouter :
#   - l'utilisateur
#   - la clef publique
#   - le mode de connexion (ssh-key only)
#   - l'ip de connexion authorisée 

