# ScaleIO Plugin for Fuel

## Overview

The `ScaleIO` plugin allows to:
  * deploy an EMC ScaleIO v.2.0 cluster together with OpenStack and configure OpenStack to use ScaleIO as a volume backend
  * configure OpenStack to use an existing ScaleIO cluster as a volume backend
  * deploy ScaleIO cluster in the following modes: 1_node, 3_node and 5_node
  ** the mode is chosen automatically depending on the number of controller nodes


## Requirements

| Requirement                      | Version/Comment |
|----------------------------------|-----------------|
| Mirantis OpenStack compatibility | 6.1, 7.         |


## Recommendations

TODO.

## Limitations

  * plugin is currently only compatible with Mirantis 6.1 and 7.0
  * plugin supports the onyl Ubuntu environment
  * the only hyper converged environment is supported - there is no separate ScaleIO Storage nodes
  * disks for SDS-es should be unallocated, they will be cleaned up
  * MDMs and Gateways are deployed together and only onto controller nodes
  * There is no ability to separate data network traffic from replication traffic
  * There is no fault sets support


# Installation Guide

## ScaleIO Plugin install from RPM file

1. Download the plugin from the [Fuel Plugins Catalog](TODO).

2. Copy the plugin file to the Fuel Master node. Follow the [Quick start guide](https://software.mirantis.com/quick-start/) if you don't have a running Fuel Master node yet.
    ```
    $ scp scaleio-3.0-3.0-1.noarch.rpm root@<Fuel Master node IP address>:/tmp/
    ```

3. Log into the Fuel Master node and install the plugin using the fuel command line.
    ```
    $ fuel plugins --install /tmp/scaleio-3.0-3.0-1.noarch.rpm
    ```

4. Verify that the plugin is installed correctly.
    ```
    $ fuel plugins
    ```

## ScaleIO Plugin install from source code

To install the ScaleIO Plugin from source code, you first need to prepare an environment to build the RPM file of the plugin. The recommended approach is to build the RPM file directly onto the Fuel Master node so that you won't have to copy that file later.

Prepare an environment for building the plugin on the **Fuel Master node**.

1. Install the standard Linux development tools:
    ```
    $ yum install createrepo rpm rpm-build dpkg-devel
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
    $ git clone --recursive TODO
    ```

5. Check that the plugin is valid:
    ```
    $ fpb --check ./fuel-plugin-scaleio
    ```

6. Build the plugin:
    ```
    $ fpb --build ./fuel-plugin-scaleio
    ```

7. Now you have created an RPM file that you can install using the steps described above. The RPM file will be located in:
    ```
    $ ./fuel-plugin-scaleio/scaleio-3.0-3.0-1.noarch.rpm
    ```

# User Guide

Please read the [ScaleIO Plugin User Guide](doc/source).

# Contributions

Please read the [CONTRIBUTING.md](CONTRIBUTING.md) document for the latest information about contributions.

# Bugs, requests, questions

Please use the [Launchpad project site](https://launchpad.net/fuel-plugin-scaleio) to report bugs, request features, ask questions, etc.

# License

Please read the [LICENSE](LICENSE) document for the latest licensing information.

