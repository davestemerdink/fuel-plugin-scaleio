.. _installation:

Installation Guide
==================


Install from `Fuel Plugins Catalog`_
------------------------------------

To install the ScaleIOv2.0 Fuel plugin:

#. Download it from the `Fuel Plugins Catalog`_
#. Copy the *rpm* file to the Fuel Master node:
   For FUEL6.1/7.0
   ::

      [root@home ~]# scp scaleio-2.0-2.0.0-1.noarch.rpm
      root@fuel-master:/tmp
   For FUEL8.0
   ::

      [root@home ~]# scp scaleio-2.1-2.1.0-1.noarch.rpm
      root@fuel-master:/tmp

#. Log into Fuel Master node and install the plugin using the
   `Fuel CLI <https://docs.mirantis.com/openstack/fuel/fuel-6.1/user-guide.html#using-fuel-cli>`_:
   For FUEL6.1/7.0
   ::

      [root@fuel-master ~]# fuel plugins --install
      /tmp/scaleio-2.0-2.0.0-1.noarch.rpm
   For FUEL8.0
   ::

      [root@fuel-master ~]# fuel plugins --install
      /tmp/scaleio-2.1-2.1.0-1.noarch.rpm

#. Verify that the plugin is installed correctly:
   For FUEL6.1/7.0
   ::
     [root@fuel-master ~]# fuel plugins
     id | name                  | version | package_version
     ---|-----------------------|---------|----------------
      1 | scaleio               | 2.0.0   | 2.0.0
   For FUEL8.0
   ::
     [root@fuel-master ~]# fuel plugins
     id | name                  | version | package_version
     ---|-----------------------|---------|----------------
      1 | scaleio               | 2.1.0   | 3.0.0


.. _Fuel Plugins Catalog: https://www.mirantis.com/products/openstack-drivers-and-plugins/fuel-plugins/
