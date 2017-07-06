Deployment of the MISP with Vagrant
===================================

This script is a work in progress! Almost working :-)

TODO:

* check the GPG key generation;
* check the generation of the SSL certificate;
* make the background workers start on boot;
* apache.24.misp.ssl seems to be missing;
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
