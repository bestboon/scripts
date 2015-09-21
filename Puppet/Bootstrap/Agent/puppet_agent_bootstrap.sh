#!/bin/bash
 
# Comprobamos si el puppet master esta instalado y activo, pero verificamos los puertos usando "File
# Descriptors" y no "lsof" o "netstat" que toman segundos.
# El file descriptor 6 en este caso, intenta conectarse por loopback, si falla entonces implica que
# el puerto esta cerrado o no tenemos acceso, en cualquier caso, reintentamos el aprovisionamiento.

# @TODO: Verificar el puerto o el proceso de comprobación del agente.
if exec 6<>/dev/tcp/127.0.0.1/8140; then
    echo "Puppet agent activo. Cancelando aprovisionamiento...";
else
    echo "Aprovisionando al agente.";
    NOMBRE_EQUIPO="agente"
    NOMBRE_SERVER="puppet"
    IP_SERVER="192.168.1.125"
    DOMINIO="bestboon.local"

    # --- NTP:
    #=========
    # Actualizacion de la hora actual.
    sudo ntpdate pool.ntp.org
    # Instalación del NTP.
    sudo apt-get update && sudo apt-get -y install ntp
    
    # --- HOSTS:
    #===========
    echo $NOMBRE_EQUIPO > /etc/hostname
    # Archivo Hosts
    sudo cat /etc/hosts | \
    # Eliminamos la linea 127.0.1.1
    sed '/127.0.1.1/{d;}' | \
    # Agregamos el nombre del agente al archivo de host local
    sed "/127.0.0.1/a 127.0.1.1    $NOMBRE_EQUIPO $NOMBRE_EQUIPO.$DOMINIO" | \
    # Agregamos el puppet master al archivo de hosts
    sed "/127.0.1.1/a $IP_SERVER   $NOMBRE_SERVER $NOMBRE_SERVER.$DOMINIO" > /etc/hosts.new
    # Renombramos el archivo de hosts original.
    sudo mv /etc/hosts.new /etc/hosts

    # --- PPA
    cd ~; wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
    # Instalamos el paquete (ppa)
    sudo dpkg -i puppetlabs-release-trusty.deb
    # Actualizamos el repositorio
    sudo apt-get update
    # Instalamos el agente
    sudo apt-get install -y puppet

    # --- PUPPET
    # Editamos el archivo de configuración del agente para que tenga la 
    # opción de inicio activada.
    sudo cat /etc/default/puppet | \
    sed "s/START=no/START=yes/" > /etc/default/puppet.new
    mv /etc/default/puppet.new /etc/default/puppet

    # --- PUPPET.CONF
    sudo cat /etc/puppet/puppet.conf | \
    # Eliminamos la linea "templatedir" de la sección [main].
    sed '/templatedir/{d;}' | \
    # Agregamos el nombre del equipo y los nombres alternativos a la resolución de dns.
    sed "/factpath/a certname=$NOMBRE_EQUIPO \ndns_alt_names=$NOMBRE_EQUIPO,$NOMBRE_EQUIPO.$DOMINIO" | \
    # Agregamos la sección [agent] con los detalles del puppet master.
    sed "/dns_alt_names/a\ \n\n[agent]\nserver=$NOMBRE_SERVER.$DOMINIO" | \
    # Borramos toda la sección [master].
    sed '/master/q' | \
    # Borramos el encabezado [master]
    sed '/master/{d;}' > /etc/puppet/puppet.conf.new
    # Reemplazamos el archivo original.
    mv /etc/puppet/puppet.conf.new /etc/puppet/puppet.conf

    # --- INICIAMOS EL SERVICIO DEL AGENTE
    sudo service puppet start
    sudo puppet agent --enable
    # sudo puppet agent --test  #forzar la aplicación de los manifiestos
fi

# Cerramos el FileDescriptor "6"
exec 6>&- # Conexiones salientes
exec 6<&- # Conexiones entrantes