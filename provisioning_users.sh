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
# Usage: sudo ./provisioning_users.sh users.json

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
#   - quota et quotatool
#-----------------
check_bin () {
    local check=false
    # Vérifier si le paquet jq pour importer des JSON est installé
    if [ ! -f /usr/bin/jq ]; then
        echo "Erreur: Le binaire jq est nécessaire pour importer le fichier JSON"
        echo "  Vous pouvez installer jq avec APT:"
        echo "  sudo apt install jq"
        echo " "
        check=true
    fi
    # Vérifier si le paquet libuser de gestion utilisateur est installé
    if [ ! -f /usr/sbin/useradd ]; then
        echo "Erreur: La librairie libuser est nécessaire pour administrer les"
        echo "utilisateurs et les groupes"
        echo "  Vous pouvez installer libuser avec APT:"
        echo "  sudo apt install libuser"
        echo " "
        check=true
    fi
    # Vérifier si les paquets de gestion de quotas sont installés
    if [ ! -f /usr/sbin/setquota ]; then
        echo "Erreur: Les librairies quota et quotatool sont nécessaires pour"
        echo "gérer les quotas des utilisateurs"
        echo "  Vous pouvez installer quota et quotatool avec APT:"
        echo "  sudo apt install quota quotatool"
        echo " "
        check=true
    fi
    # Vérifier si OpenSSH est installé
    if ! command -v sshd > /dev/null 2>&1; then
        echo "Erreur: OpenSSH n'est pas installé."
        echo "  Vous devez installer openSSH avec APT:"
        echo "  sudo apt install openssh-server"
        echo " "
        check=true
    fi
    if $check; then
        echo "Erreur durant la vérification des pré-requis"
        echo ""
        exit 1
    fi
    return 0
}

#-----------------
# import_json
# Importer le contenu du fichier json dans une variable USERS
#-----------------
import_json () {
    USERS=$(jq -c '.users' "$1")
    if [ $? -eq 0 ]; then
        if [ "$VERBOSE" = true ]; then
            echo "Les utilisateurs ont été importés avec succès"
        fi 
    else
        echo "Erreur: L'importation des utilisateurs a échoué !"
        exit 1
    fi   
    return 0
}

#-----------------
# add_user
# Ajout de l'utlisateur avec ses caractéristiques
# paramètres :"$username" "$group" "$public_key" "$quota"
#-----------------
add_user () {
    
    # Création du groupe
    groupadd -f "$2" # -f (Force) : fini avec succès, même si le groupe existe déjà
    if [ $? -eq 0 ]; then
        if [ "$VERBOSE" = true ]; then
            echo "Le groupe $2 a été ajouté avec succès"
        fi 
    else
        echo "Erreur: Le groupe $2 n'a pas pu être créé !"
        exit 1
    fi

    # Création de l'utlisateur
    useradd -m -d "/home/$1" -G "$2" -s /bin/bash "$1" 2>/dev/null # Création du home, affectation dans le groupe et ajout de l'utilisateur
    if [ $? -eq 0 ]; then
        if [ "$VERBOSE" = true ]; then
           echo "L'utilisateur $1 a été créé avec succès"
        fi 
    elif [ $? -eq 4 ]; then
        if [ "$VERBOSE" = true ]; then
            echo "L'utilisateur $1 existe déjà, les informations du JSON seront ajoutées"
        fi
    else
        echo "Erreur: Il y a eu un problème lors de la création de l'utlisateur $1 !"
        exit 1
    fi
    
    # Ajout d'un quota sur son home
    local quota_blocks=$(($4 * 1024 * 1024))
    setquota -u "$1" 0 "$quota_blocks" 0 0 / # Ajout d'un quota sur pour l'utilisateur
    if [ $? -eq 0 ]; then
        if [ "$VERBOSE" = true ]; then
            echo "Quota de $4 GB appliqué pour l'utilisateur $1"
        fi
    else
        echo "Alerte: Echec lors de la création du quota pour l'utilisateur $1"
    fi
    

    # Ajouter l'option from=IP et la clé SSH
    local ip=$(echo "$USERS" | jq -r ".[] | select(.username == \"$1\") | .ip")
    local authorized_key="from=\"$ip\" $3"
    mkdir -p "/home/$1/.ssh" # -p : fini avec succès, même si le répertoire existe déjà
    echo "$authorized_key" >> "/home/$1/.ssh/authorized_keys"
    if [ "$VERBOSE" = true ]; then
        echo "Ajout de l'IP origine et de la clef SSH pour l'utilisateur $1"
    fi
    
    # Modification de propiétaire sur le home
    chown  -R "$1:$2" "/home/$1"
    # Modification des droits sur
    #   - le repertoire .ssh
    chmod 700 "/home/$1/.ssh"
    #   - le fichier des clefs autorisées
    chmod 600 "/home/$1/.ssh/authorized_keys"
    
    echo "Le compte $1 a été créé avec succès"
    return 0
}

#-----------------
# conf_SSH
# Configuration du service SSH
# Ouverture du port 22 dans le FW
# paramètres :"$username" "$group" "$public_key" "$quota"
#-----------------
conf_SSH () {
    # Désactiver l'authentification par mot de passe
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication no/PasswordAuthentication no/g' /etc/ssh/sshd_config

    # Autoriser uniquement l'authentification par clé publique
    sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/^#PubkeyAuthentication no/PubkeyAuthentication yes/g' /etc/ssh/sshd_config

    # Redémarrer le service SSH pour appliquer les changements
    systemctl restart sshd
    if [ "$VERBOSE" = true ]; then
        echo "Redémarrage du service SSH..."
    fi
    sleep 10

    return 0
}

conf_quota () {
    
    # Modifier /etc/fstab pour activer les quotas sur /
    if [ "$VERBOSE" = true ]; then
        echo "Modification de /etc/fstab..."
    fi
    sed -i 's/errors=remount-ro/errors=remount-ro,usrjquota=aquota.user,grpjquota=aquota.group,jqfmt=vfsv0/' /etc/fstab

    # Remonter la partition racine avec les nouvelles options (sans redémarrer)

    systemctl daemon-reload
    if [ "$VERBOSE" = true ]; then
        echo "Redémarrage du daemon..."
    fi
    sleep 10
    if [ "$VERBOSE" = true ]; then
        echo "Remontage de /..."
    fi
    mount -o remount /

    # Activation des quotas
    if [ "$VERBOSE" = true ]; then
        echo "Activation des quotas..."
    fi    
    quotacheck -ugm /
    quotaon /

    # Vérification de l'état des quotas
    if quotaon -p / 2>/dev/null | grep -q "is on"; then
        echo "Les quotas sont activés sur /"
    else
        echo "Les quotas n'ont pas pu être activés automatiquement, essayez une configuration manuel"
        exit 1
    fi
    return 0
}

#-----------------
# Main
#-----------------

fichier=""
VERBOSE=false

# Le script doit être exécuté en root (sudo)
if [ ! $(whoami) = 'root' ]; then
    echo "Ce script doit être exécuté avec des droits root"
    exit 0
fi

# Vérification de la présence des binaires nécessaires
check_bin

while getopts ":f:vh" option
do
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
    if [ "$VERBOSE" = true ]; then
        echo "Importation du fichier JSON..."
    fi   
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
fi

# Configuration SSH
if ! grep -q "PasswordAuthentication " /etc/ssh/sshd_config && ! grep -q "PubkeyAuthentication yes" /etc/ssh/sshd_config; then
    if [ "$VERBOSE" = true ]; then
        echo "Configuration du service SSH..."
    fi
    conf_SSH
fi

# Configuration du système de quotas ?
if quotaon -p / 2>/dev/null | grep -q "is on"; then
    if [ "$VERBOSE" = true ]; then
        echo "Les quotas sont activés sur /"
    fi    
else
    if [ "$VERBOSE" = true ]; then
        echo "Les quotas ne sont PAS activés sur /"
    fi     
    conf_quota
fi

echo "$USERS" | jq -c '.[]' | while read -r user; do
    username=$(echo "$user" | jq -r '.username')
    group=$(echo "$user" | jq -r '.group')
    public_key=$(echo "$user" | jq -r '.public_key')
    quota=$(echo "$user" | jq -r '.home_quota_gb')

    add_user "$username" "$group" "$public_key" "$quota"
done

exit 0