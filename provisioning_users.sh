#!/bin/bash
# This script create accounts for users decribes in a JSON file
# It create new accounts for users, add them in group, configure SSH access with
# an autorized IP and an only key access. It also attribute a maximum space for home directory (Gb)
# JSON format:
#    {
#    "users": [
#        {
#        "username": "user1",
#        "group": "devs",
#        "ip": "192.168.1.10",
#        "public_key": "ssh-rsa AAAAB3NzaC1yc2E... user1@host",
#        "home_quota_gb": 50
#        },
#        {
#        "username": "user2",
#        "group": "devs",
#        "ip": "192.168.1.11",
#        "public_key": "ssh-rsa AAAAB3NzaC1yc2E... user2@host",
#        "home_quota_gb": 100
#        }
#    ]
#    }
# Usage: ./provisioning_users.sh users.json

#-----------------
# show_help
# Affiche l'aide du script
#-----------------

show_help () {
    cat ./help.me
}

#-----------------
# Main
#-----------------

fichier=""
verbeux=false

while getopts ":f:vh" option
do
#    echo "getopts a trouvé l'option $option"
    case $option in
        f)  fichier="$OPTARG"
            ;;
        v)  verbeux=true
            ;;
        :)  echo "l'option $OPTARG requiert un nom de fichier en argument"
            exit 1
            ;;
        h)  show_help
            exit 0
            ;;
        ?)  echo "L'option $OPTARG est invalide"
            show_help
            exit 1
            ;;
        \?) echo "L'option $OPTARG est invalide"
            exit 1
            ;;
    esac
done

if [ -f "$fichier" ]; then
    echo "Le fichier contient: "
    cat "$fichier"
elif [ "$fichier" = '' ]; then
    echo "Erreur : Vous devez indiquer un nom de fichier valide en argument -f"
    exit 1
else    
    echo "Erreur : Le fichier '$fichier' n'existe pas."
    exit 1
fi

if [ "$verbeux" = true ]; then
    echo "Mode verbeux activé."
    echo "Lecture du fichier : $fichier"
fi

exit 0

