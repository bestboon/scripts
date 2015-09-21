#!/bin/bash
 
# Comprobamos si el puppet master esta instalado y activo, pero verificamos los puertos usando "File
# Descriptors" y no "lsof" o "netstat" que toman segundos.
# El file descriptor 6 en este caso, intenta conectarse por loopback, si falla entonces implica que
# el puerto esta cerrado o no tenemos acceso, en cualquier caso, reintentamos el aprovisionamiento.
if exec 6<>/dev/tcp/127.0.0.1/8443; then
    echo "Foreman ya instalado y activo. Cancelando instalacion..."
else
    # --- FOREMAN
    # Agregamos la ruta de foreman al APT
    sudo sh -c 'echo "deb http://deb.theforeman.org/ trusty 1.9" > /etc/apt/sources.list.d/foreman.list'
    sudo sh -c 'echo "deb http://deb.theforeman.org/ plugins 1.9" >> /etc/apt/sources.list.d/foreman.list'
    wget -q http://deb.theforeman.org/pubkey.gpg -O- | sudo apt-key add -
    # Actualizamos e instalamos el "instalador" de foreman
    sudo apt-get update && sudo apt-get install -y foreman-installer
    # Ejecutamos el instalador de foreman.
    sudo foreman-installer

    # Habilitamos DIFF para los reportes de Foreman
    sudo cat /etc/puppet/puppet.conf | \
    # Buscamos la seccion master y agregamos el valor.
    sed '/master/a\ show_diff=true' > /etc/puppet/puppet.conf.new
    sudo mv /etc/puppet/puppet.conf.new /etc/puppet/puppet.conf
fi

# Cerramos el FileDescriptor "6"
exec 6>&- # Conexiones salientes
exec 6<&- # Conexiones entrantes