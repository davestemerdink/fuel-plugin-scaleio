# ScaleIO Plugin for Fuel

## Overview

Disclaimer: Current version is Beta 2.

The `ScaleIO` plugin allows to:
  * Deploy an EMC ScaleIO v.2.0 cluster together with OpenStack and configure OpenStack to use ScaleIO
    as the storage for persistent and ephemeral volumes
  * Configure OpenStack to use an existing ScaleIO cluster as a volume backend
  * Support the following ScaleIO custer modes: 1_node, 3_node and 5_node
    the mode is chosen automatically depending on the number of controller nodes


## Requirements

| Requirement                      | Version/Comment |
|----------------------------------|-----------------|
| Mirantis OpenStack               | 6.1             |
| Mirantis OpenStack               | 7.0             |

## Recommendations

1. Use configuration with 3 controllers or 5 controllers.
    Although 1 controller mode is supported is suitable for testing purposees only.
2. Assign Cinder role for all controllers with allocating minimal diskspace for this role.
    Some space is needed because of FUEL6.1/7.0 framework limitation (this space will not used).
    Rest of the space keep for images.
3.  Use nodes with similar HW configuration within one group of roles.
4. Deploy SDS coponents only on compute nodes.
    Deploymen SDS-es on controllers is supported but it is more suitable for testing than for production environment.
5. On compute nodes keep minimal space for virtual storage on the first disk, rest disks use for ScaleIO.
    Some space is needed because of FUEL6.1/7.0 framework limitations.
    Other disks should be unallocated and can be used for ScaleIO.
6. In case of extending cluster with new compute nodes not to forget to run update_hosts tasks on controller nodes via FUEL cli. 

## Limitations

1. Plugin is only compatible with Mirantis 6.1 and 7.0.
2. Plugin supports the only Ubuntu environment.
3. The only hyper converged environment is supported - there is no separate ScaleIO Storage nodes.
4. Multi storage backend is not supported.
5. It is not possible to use different backends for persistent and ephemeral volumes.
6. Disks for SDS-es should be unallocated before deployment via FUEL UI or cli.
7. MDMs and Gateways are deployed together and only onto controller nodes.
8. Adding and removing node(s) to/from the OpenStack cluster won't re-configure the ScaleIO.

# Installation Guide

## ScaleIO Plugin install from source code

To install the ScaleIO Plugin from source code, you first need to prepare an environment to build the RPM file of the plugin. The recommended approach is to build the RPM file directly onto the Fuel Master node so that you won't have to copy that file later.

Prepare an environment for building the plugin on the **Fuel Master node**.

0. You might want to make sure that kernel you have on the nodes for ScaleIO SDC installation (compute and cinder nodes) is suitable for the drivers present here: ``` ftp://QNzgdxXix:Aw3wFAwAq3@ftp.emc.com/ ```. Look for something like ``` Ubuntu/2.0.5014.0/4.2.0-30-generic ```. Local kernel version can be found with ``` uname -a ``` command.

1. Install the standard Linux development tools:
    ```
    $ yum install createrepo rpm rpm-build dpkg-devel git
    ```

2. Install the Fuel Plugin Builder. To do that, you should first get pip:
    ```
    $ easy_install pip
    ```

3. Then install the Fuel Plugin Builder (the `fpb` command line) with `pip`:
    ```
    $ pip install fuel-plugin-builder
    ```

*Note: You may also have to build the Fuel Plugin Builder if the package version of the
plugin is higher than package version supported by the Fuel Plugin Builder you get from `pypi`.
In this case, please refer to the section "Preparing an environment for plugin development"
of the [Fuel Plugins wiki](https://wiki.openstack.org/wiki/Fuel/Plugins) if you
need further instructions about how to build the Fuel Plugin Builder.*

4. Clone the ScaleIO Plugin git repository (note the `--recursive` option):
    ```
    $ git clone https://github.com/cloudscaling/fuel-plugin-scaleio.git
    $ cd fuel-plugin-scaleio
    ```

5. Check that the plugin is valid:
    ```
    $ fpb --check .
    ```

6. Build the plugin:
    ```
    $ fpb --build .
    ```

7. Install plugin:
    ```
    $ fuel plugins --install ./scaleio-2.0-2.0.0-1.noarch.rpm
    ```


# User Guide

Please read the [ScaleIO Plugin User Guide](doc/source/builddir/ScaleIO-Plugin_Guide.pdf) for full description.

First of all, ScaleIOv2.0 plugin functionality should be enabled by switching on ScaleIO in the Settings.

ScaleIO section contains the following info to fill in:

1. Existing ScaleIO Cluster.
Set "Use existing ScaleIO" checkbox.
The following parameters should be specified:
* Gateway IP address - IP address of ScaleIO gateway
* Gateway port - Port of ScaleIO gateway
* Gateway user - User to access ScaleIO gateway
* Gateway password - Password to access ScaleIO gateway
* Protection domain - The protection domain to use
* Storage pools - Comma-separated list of storage pools

2. New ScaleIO deployment
The following parameters should be specified:
* Admin password - Administrator password to set for ScaleIO MDM
* Gateway password - Administrator password to set for ScaleIO Gateway (for now should be the same as Admin password)
* Protection domain - The protection domain to create for ScaleIO cluster
* Storage pools - Comma-separated list of storage pools to create for ScaleIO cluster
* Storage devices - Path to storage devices, comma separated (/dev/sdb,/dev/sdd)
* Controller as Storage - Use controller nodes for ScaleIO SDS (by default only compute nodes are used for ScaleIO SDS deployment)
  
Configuration of disks for allocated nodes:
The devices listed in the "Storage devices" above should be left unallocated for ScaleIO SDS to work.

# Contributions

Please read the [CONTRIBUTING.md](CONTRIBUTING.md) document for the latest information about contributions.

# Bugs, requests, questions

Please use the [Launchpad project site](https://launchpad.net/fuel-plugin-scaleio) to report bugs, request features, ask questions, etc.

# License

Please read the [LICENSE](LICENSE) document for the latest licensing information.

