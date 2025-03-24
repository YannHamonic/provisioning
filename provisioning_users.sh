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
    if [ ! -f /usr/bin/jq ]; then
        echo "Erreur: Le binaire jq est nécessaire pour importer le fichier JSON"
        echo "  Vous pouvez installer jq avec APT: sudo apt install jq"
        echo " "
        check=true
    fi
    if [ ! -f /usr/sbin/useradd ]; then
        echo "Erreur: La librairie libuser est nécessaire pour administrer les"
        echo "utilisateurs et les groupes"
        echo "  Vous pouvez installer libuser avec APT: sudo apt install libuser"
        echo " "
        check=true
    fi
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
    echo "$1" | jq .
    USERS=$(jq -c '.users' "$1")
    return 0
}
#-----------------
# get_home_partition
# Cherche la partition du /home
#-----------------
get_home_partition() {
    local mount_point
    mount_point= $(findmnt -n -o SOURCE /home)

    if [ -z "$mount_point" ]; then
        echo "Erreur: impossible de trouver le point de montage de /home. Vérifiez votre configuration."
        exit 1
    fi

    echo "$mount_point"
}
#-----------------
# apply_quota
# Applique le quota à un utilisateur
# paramètres : "$username" "$quota_gb"
#-----------------
apply_quota() {
    local username= $1
    local quota_gb= $2
    local quota_blocks=$((quota_gb * 1024 * 1024))
    local home_partition=$(get_home_partition)

    if ! id "$username" &>/dev/null; then
        echo "L'utilisateur $username n'existe pas. Création de l'utilisateur..."
        useradd -m "$username"
    fi

    setquota -u "$username" 0 "$quota_blocks" 0 0 "$home_partition"
    echo "Quota de $quota_gb GB appliqué pour l'utilisateur $username"
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
    local quota_blocks=$(($4 * 1024 * 1024))
    setquota -u "$1" 0 "$quota_blocks" 0 0 /home/$1 # Ajout d'un quota sur le répertoire utilisateur

    # Ajout de la clef SSH
    mkdir -p "/home/$1/.ssh" # -p : fini avec succès, même si le répertoire existe déjà
    echo $3 >> "/home/$1/.ssh/authorized_keys"
    
    # Ajouter l'option from=IP à la clé SSH
    local ip=$(echo "$USERS" | jq -r ".[] | select(.username == \"$1\") | .ip")
    local authorized_key="from=\"$ip\" $3"
    echo "$authorized_key" >> "/home/$1/.ssh/authorized_keys"
    
    # Modification de propiétaire sur le home
    chown  -R "$1:$2" "/home/$1"
    # Modification des droits sur
    #   - le repertoire .ssh
    chmod 700 "/home/$1/.ssh"
    #   - le fichier des clefs autorisées
    chmod 600 "/home/$1/.ssh/authorized_keys"

    return 0
}

#-----------------
# conf_SSH
# Configuration du service SSH
# Ouverture du port 22 dans le FW
# paramètres :"$username" "$group" "$public_key" "$quota"
#-----------------
conf_SSH () {
    # Activation du service OpenSSH si il n'est pas déjà activé


    # Désactiver l'authentification par mot de passe
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication no/PasswordAuthentication no/g' /etc/ssh/sshd_config

    # Autoriser uniquement l'authentification par clé publique
    sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config

    # Redémarrer le service SSH pour appliquer les changements
    systemctl restart sshd

    # Activer UFW si ce n'est pas déjà fait
    #ufw status | grep -q "active" || ufw enable

    # Configurer UFW pour autoriser les connexions SSH uniquement depuis les IPs spécifiées dans le fichier JSON
    # Réinitialiser les règles existantes pour éviter les conflits
    # ufw reset -y

    # Définir la politique par défaut : tout refuser sauf ce qui est explicitement autorisé
    #ufw default deny incoming
    #ufw default allow outgoing

    # Autoriser SSH depuis les IPs spécifiées dans le fichier JSON
    #echo "$USERS" | jq -c '.[]' | while read -r user; do
    #    ip=$(echo "$user" | jq -r '.ip')
    #    if [[ ! -z "$ip" ]]; then
    #        ufw allow from "$ip" to any port 22 proto tcp comment "SSH from $ip"
    #    fi
    #done

    # Activer UFW
    #ufw enable

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

# Configuration SSH et du firewall
conf_SSH

# CONFIGURATION DU SYSTEM DE QUOTA ....  SYSTEME DE DISQUE ? RELOAD DE LA MACHINE ?

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