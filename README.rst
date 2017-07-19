Deployment of MISP with Vagrant
===============================

TODO:

* check the generation of the SSL certificate;
* check the configuration of postfix;
* generate the TLS certificate with Let's Encrypt.


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
