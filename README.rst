Deployment of MISP with Vagrant
===============================


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
http://127.0.0.1:5000. Use the user/password: admin@admin.test/admin


Modules activated by default in the VM:

* `MISP galaxy <https://github.com/MISP/misp-galaxy>`_ (http://127.0.0.1:5000/taxonomies/index)
* `MISP taxonomies <https://github.com/MISP/misp-taxonomies>`_ (http://127.0.0.1:5000/galaxies/index.json)
* `MISP modules <https://github.com/MISP/misp-modules>`_ (curl -s http://127.0.0.1:6666/modules)
