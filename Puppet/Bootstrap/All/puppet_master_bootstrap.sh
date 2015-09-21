#!/bin/bash
 
# Comprobamos si el puppet master esta instalado y activo, pero verificamos los puertos usando "File
# Descriptors" y no "lsof" o "netstat" que toman segundos.
# El file descriptor 6 en este caso, intenta conectarse por loopback, si falla entonces implica que
# el puerto esta cerrado o no tenemos acceso, en cualquier caso, reintentamos el aprovisionamiento.
if exec 6<>/dev/tcp/127.0.0.1/8140; then
    echo "Puppet Master ya instalado y activo. Cancelando aprovisionamiento..."
else
    NOMBRE_EQUIPO="puppet"
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
    sed '/127.0.1.1/{d;}' > /etc/hosts.new
    # Renombramos el archivo de hosts original.
    sudo mv /etc/hosts.new /etc/hosts

    # Agregamos la linea basada en el nombre del equipo y del dominio.
    echo "" | sudo tee --append /etc/hosts 2> /dev/null && \
    echo "# Configuración del puppet master y los agentes." | sudo tee --append /etc/hosts 2> /dev/null && \
    echo "127.0.1.1    $NOMBRE_EQUIPO $NOMBRE_EQUIPO.$DOMINIO " | sudo tee --append /etc/hosts 2> /dev/null 
    
    # --- PUPPET MASTER
    #==================
    # Descargar el puppet master para trusty
    cd ~; wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
    # Instalamos el pupet master
    sudo dpkg -i puppetlabs-release-trusty.deb
    # Actualizamos el repositorio
    sudo apt-get -y update
    
    # --- PUPPET PASSENGER
    #=====================
    # Instalamos el puppetmaster passenger y sus dependencias
    # incluido apache2. Luego de esto la ejecución del puppet 
    # master será controlada por apache.
    sudo apt-get -y install puppetmaster-passenger
    # Detenemos apache2 para detener el puppet master y proceder a 
    # realizar las configuraciones.
    sudo service apache2 stop

    # --- SSL
    #========
    # Borramos cualquier certificado SSL existente.
    sudo rm -rf /var/lib/puppet/ssl
    
    # --- PUPPET.CONF
    #================
    sudo cat /etc/puppet/puppet.conf | \
    # Eliminamos la linea "templatedir" de la sección [Master].
    sed '/templatedir/{d;}' | \
    # Agregamos la linea "certname" luego de la variable "factpath"
    sed "/factpath/ a\certname=$NOMBRE_EQUIPO" | \
    # Agregamos la linea "dns_alt_names" despues de la linea "certname" y lo guardamos en un archivo nuevo.
    sed "/certname/ a\dns_alt_names=$NOMBRE_EQUIPO,$NOMBRE_EQUIPO.$DOMINIO" > /etc/puppet/puppet.conf.new
    # Remplazamos el archivo original
    sudo mv /etc/puppet/puppet.conf.new /etc/puppet/puppet.conf

    # --- CERTIFICADOS APACHE2
    #=========================
    sudo cat /etc/apache2/sites-available/puppetmaster.conf | \
    # Ajustamos el nombre del certificado para que coincida con el nombre del equipo (en Apache2)
    sed "s/$NOMBRE_EQUIPO\..*.pem$/$NOMBRE_EQUIPO.pem/" > /etc/apache2/sites-available/puppetmaster.conf.new
	# Remplazamos el archivo original.
    sudo mv /etc/apache2/sites-available/puppetmaster.conf.new /etc/apache2/sites-available/puppetmaster.conf

    # --- CERTIFICADOS SSL
    #=====================
    # Ejecutamos el comando para generar los certificados del ssl durante 60s y luego lo cerramos
    timeout 60s sudo puppet master --verbose --no-daemonize
    # Listamos los certificados para comprobar su generación.
    sudo puppet cert list -all

    # Generamos el archivo base para los manifiestos según el estandar.
    sudo touch /etc/puppet/manifests/site.pp
    
    # --- INICIAMOS APACHE Y EL PUPPET MASTER
    sudo service apache2 start
fi

# Cerramos el FileDescriptor "6"
exec 6>&- # Conexiones salientes
exec 6<&- # Conexiones entrantes