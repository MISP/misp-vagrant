Development environment for MISP
================================

Vagrant is convenient to use in order to setup your development environment.

This VM uses `synced folders <https://www.vagrantup.com/docs/synced-folders/>`_
feature of Vagrant in order to let you work on the MISP source code on your
host machine while the softwares (Apache, PHP, MariaDB, etc.) and libraries
will be installed on the guest Vagrant machine.


Installation of VirtualBox and Vagrant
--------------------------------------

.. code-block:: bash

    $ sudo apt-get install virtualbox vagrant


Deployment of MISP
------------------

MISP will be automatically deployed in an Ubuntu Zesty Server.

.. code-block:: bash

    $ git clone https://github.com/MISP/MISP.git
    $ cd MISP/vagrant/
    $ vagrant up

Once the VM will be configured by Vagrant, go to the address
http://127.0.0.1:5000.

You can now edit the source code with your favorite editor and test it in your
browser. The only thing is to not forget to restart Apache in the VM after a
modification.

If you do not want a development environment (and enable synced folders):

.. code-block:: bash

    $ git clone https://github.com/MISP/misp-vagrant.git
    $ cd misp-vagrant/
    $ export MISP_ENV='demo'
    $ vagrant up


Modules activated by default in the VM:

* `MISP galaxy <https://github.com/MISP/misp-galaxy>`_
* `MISP taxonomies <https://github.com/MISP/misp-taxonomies>`_
* `MISP modules <https://github.com/MISP/misp-modules>`_
