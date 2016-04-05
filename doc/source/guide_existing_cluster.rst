Openstack with existing ScaleIO cluster
==============================================

Once the Fuel ScaleIOv2.0 plugin has been installed (following the
:ref:`Installation Guide <installation>`), you can create an *OpenStack* environments that
uses existing ScaleIO cluster as the block storage backend.

Prepare infrastructure
----------------------

At least 5 nodes are required to successfully deploy Mirantis OpenStack with ScaleIO.

#. Fuel master node (w/ 50GB Disk, 2 Network interfaces [Mgmt, PXE] )
#. OpenStack Controller #1 node
#. OpenStack Controller #2 node
#. OpenStack Controller #3 node
#. OpenStack Compute node

Each node shall have at least 2 CPUs, 4GB RAM, 200GB disk, 3 Network interfaces. The 3 interfaces will be used for the following purposes:

#. Admin (PXE) network: Mirantis OpenStack uses PXE booting to install the operating system, and then loads the OpenStack packages for you.
#. Public, Management and Storage networks: All of the OpenStack management traffic will flow over this network (“Management” and “Storage” will be separated by VLANs), and to re-use the network it will also host the public network used by OpenStack service nodes and the floating IP address range.
#. Private network: This network will be added to Virtual Machines when they boot. It will therefore be the route where traffic flows in and out of the VM.

At least on of controllers 1, 2, and 3 should play Cinder role, because of lack of custom role support in Fuel6.1.

In that deployment option plugin installs the only client component on the nodes with Cinder and Compute roles and configure them to use existing ScaleIO cluster.

ScaleIO cluster should be available for the Cinder and Compute nodes via storage network, ScaleIO Gateway should be available via management interface (management_vip).


Select Environment
------------------

#. Create a new environment with the Fuel UI wizard. Select "Juno on Ubunu 14.04" from OpenStack Release dropdown list and continue until you finish with the wizard.

    .. image:: images/wizard.png
       :width: 80%

#. Add VMs to the new environment according to `Fuel User Guide <https://docs.mirantis.com/openstack/fuel/fuel-6.1/user-guide.html#add-nodes-to-the-environment>`_ and configure them properly.


Plugin configuration
--------------------

#. Go to the Settings tab and scroll down to "ScaleIO plugin" section. You need to fill all fields with your preferred ScaleIO configuration. If you do not know the purpose of a field you can leave it with its default value.

    .. image:: images/settings_existing_cluster.png
       :width: 70%

#. Take the time to review and configure other environment settings such as the DNS and NTP servers, URLs for the repositories, etc.


Finish environment configuration
--------------------------------

#. Go to the Network tab and configure the network according to your environment.

#. Run `network verification check <https://docs.mirantis.com/openstack/fuel/fuel-6.1/user-guide.html#verify-networks>`_

    .. image:: images/network.png
       :width: 90%

#. Press `Deploy button <https://docs.mirantis.com/openstack/fuel/fuel-6.1/user-guide.html#deploy-changes>`_ once you have finished reviewing the environment configuration.

    .. image:: images/deploy.png
       :width: 60%

#. After deployment is done, you will see a message indicating the result of the deployment.

    .. image:: images/deploy-result.png
       :width: 80%


ScaleIO verification
--------------------

Once the OpenStack cluster is setup, we can make use of ScaleIO volumes. This is an example about how to attach a volume to a running VM.

#. Login into the OpenStack cluster:

#. Review the block storage services by navigating to the "Admin -> System -> System Information" section. You should see the "@ScaleIO" appended to all cinder-volume hosts.

    .. image:: images/block-storage-services.png
       :width: 90%

#. In the ScaleIO GUI (see :ref:`Install ScaleIO GUI section <scaleiogui>`), enter the IP address of the primary controller node, username `admin`, and the password you entered in the Fuel UI.

#. Once logged in, verify that it successfully reflects the ScaleIO resources:

    .. image:: images/scaleio-cp.png
       :width: 80%

#. Click on the "Backend" tab and verify all SDS nodes:

    .. image:: images/scaleio-sds.png
       :width: 90%

#. Create a new OpenStack volume (ScaleIO backend is used by default).

#. In the ScaleIO GUI, you will see that there is one volume defined but none have been mapped yet.

    .. image:: images/sio-volume-defined.png
       :width: 20%

#. Once the volume is attached to a VM, the ScaleIO GUI will reflect the mapping.

    .. image:: images/sio-volume-mapped.png
       :width: 20%
