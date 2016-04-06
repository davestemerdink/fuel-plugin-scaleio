.. _installation:

Installation Guide
==================


Install from source code
------------------------
To install the ScaleIO Plugin from source code, you first need to prepare an environment to build the RPM file of the plugin. The recommended approach is to build the RPM file directly onto the Fuel Master node so that you won't have to copy that file later.

Prepare an environment for building the plugin on the **Fuel Master node**.

#. Install the standard Linux development tools:
   ::
      yum install createrepo rpm rpm-build dpkg-devel git

#. Install the Fuel Plugin Builder. To do that, you should first get pip:
   ::
      easy_install pip

#. Then install the Fuel Plugin Builder (the `fpb` command line) with `pip`:
   ::
      pip install fuel-plugin-builder

#. Clone the ScaleIO Plugin git repository (note the `--recursive` option):
   ::
      git clone https://github.com/cloudscaling/fuel-plugin-scaleio.git
      cd fuel-plugin-scaleio

#. Check that the plugin is valid:
   ::
      fpb --check .

#. Build the plugin:
   ::
      fpb --build .

#. Install plugin:
   ::
      fuel plugins --install ./scaleio-2.0-2.0-1.noarch.rpm

#. Verify that the plugin is installed correctly:
   ::

      [root@fuel-master ~]#fuel plugins
      id | name                  | version | package_version
      ---|-----------------------|---------|----------------
       1 | scaleio               | 2.0     | 2.0.0


Install from `Fuel Plugins Catalog`_
------------------------------------

To install the ScaleIOv2.0 Fuel plugin:

#. Download it from the `Fuel Plugins Catalog`_
#. Copy the *rpm* file to the Fuel Master node:
   ::

      [root@home ~]# scp scaleio-2.0-2.0-1.noarch.rpm
      root@fuel-master:/tmp

#. Log into Fuel Master node and install the plugin using the
   `Fuel CLI <https://docs.mirantis.com/openstack/fuel/fuel-6.1/user-guide.html#using-fuel-cli>`_:

   ::

      [root@fuel-master ~]# fuel plugins --install
      /tmp/scaleio-2.0-2.0-1.noarch.rpm

#. Verify that the plugin is installed correctly:
   ::

     [root@fuel-master ~]# fuel plugins
     id | name                  | version | package_version
     ---|-----------------------|---------|----------------
      1 | scaleio               | 2.0     | 2.0.0


.. _Fuel Plugins Catalog: https://www.mirantis.com/products/openstack-drivers-and-plugins/fuel-plugins/
