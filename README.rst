Deployment of MISP with Vagrant
===============================

This script is a work in progress!

TODO:

* automatically update the galaxies via the API;
* check the generation of the SSL certificate;
* check the configuration of postfix;
* configure redis connection;
* make the background workers start on boot;
* generate the TLS certificate with Let's Encrypt.

Improvements:

* provide more options through variables (for the gpg keys, etc.).



Installation of VirtualBox and Vagrant
--------------------------------------

.. code-block:: bash

    $ sudo apt-get install virtualbox vagrant


Deployment of MISP
------------------

MISP will be automatically deployed in an Ubuntu Zesty Server.

.. code-block:: bash

    $ git clone https://github.com/MISP/misp-vagrant.git
    $ cd misp-vagrant/
    $ vagrant up

Once the VM will be configured by Vagrant, go to the address
http://127.0.0.1:5000.
