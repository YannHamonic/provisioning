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
# check_bin
# Vérifie que les binaires et librairies essentiels sont présent
#   - jq
#   - libuser
#-----------------
check_bin () {
    if [ ! -f /usr/bin/jq ]; then
        echo "Erreur: Le binaire jq est nécessaire pour importer le fichier JSON"
        echo "  Vous pourvez installer jq avec APT: sudo apt install jq"
        exit 1
    fi
    if [ ! -f /usr/bin/useradd ]; then
        echo "Erreur: La librairie libuser est nécessaire pour administrer les"
        echo "utilisateurs et les groupes"
        echo "  Vous pourvez installer libuser avec APT: sudo apt install libuser"
        exit 1
    fi
    return 0
}

#-----------------
# import_json
# Importer le contenu du fichier json dans une variable USERS
#-----------------
import_json () {
    echo "$1" | jq .
    USERS=$(jq -c '.users' "$1")
    return 0
}

#-----------------
# add_user
# Ajout de l'utlisateur avec ses caractéristiques
# paramètres :"$username" "$group" "$public_key" "$quota"
#-----------------
add_user () {
    # Création de l'utlisateur (basics)
    groupadd -f "$2" # -f (Force) : fini avec succès, même si le groupe existe déjà
    useradd -m -d "/home/$1" -g "$2" "$1" # Création du home, affectation dans le groupe et ajout de l'utilisateur
    # Ajout d'un quota sur son home
    setquota -u "$1" 0 "$4" 0 0 / # A décrire

    # Ajout de la clef SSH
    mkdir -p "/home/$1/.ssh" # -p : fini avec succès, même si le répertoire existe déjà
    echo $3 >> "/home/$1/.ssh/authorized_keys"

    # Modification de propiétaire sur le home
    chown  -R "$1:$2" "/home/$1"
    # Modification des droits sur
    #   - le repertoire .ssh
    chmod 700 "/home/$1/.ssh"
    #   - le fichier des clefs autorisées
    chmod 600 "/home/$1/.ssh/authorized_keys"

    return O
}

#-----------------
# conf_SSH
# Configuration du service SSH
# Ouverture du port 22 dans le FW
# paramètres :"$username" "$group" "$public_key" "$quota"
#-----------------
conf_SSH () {
    return 0
}

#-----------------
# Main
#-----------------

fichier=""
VERBOSE=false

# Vérification de la présence des binaires nécessaires
check_bin

while getopts ":f:vh" option
do
#    echo "getopts a trouvé l'option $option"
    case $option in
        f)  fichier="$OPTARG"
            ;;
        v)  VERBOSE=true
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

if [ -s "$fichier" ]; then
    import_json $fichier
elif [ "$fichier" = '' ]; then
    echo "Erreur : Vous devez indiquer un nom de fichier valide en argument -f"
    exit 1
else    
    echo "Erreur : Le fichier '$fichier' n'existe pas."
    exit 1
fi

if [ "$VERBOSE" = true ]; then
    echo "Mode verbeux activé."
    echo "Lecture du fichier : $fichier"
fi

echo "$USERS" | jq -c '.[]' | while read -r user; do
    username=$(echo "$user" | jq -r '.username')
    group=$(echo "$user" | jq -r '.group')
    public_key=$(echo "$user" | jq -r '.public_key')
    quota=$(echo "$user" | jq -r '.home_quota_gb')

    add_user "$username" "$group" "$public_key" "$quota"
done

# Configurer le service SSH + ouvrir le port 22 dans le FW
# Eventuellement à faire avant l'ajout des utilisateurs pour que l'on puisse autoriser les IP's à la lecture de celles-ci
# conf_SSH

exit 0