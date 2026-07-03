Elements Container
==================

Container with all requirements installed as environment for the Elements SDK.

Build
#####

Run following code to build the `elements:v2.6` container with podman.

.. code-block:: bash

    podman build -t dnltz/elements:v2.6 .

Alternatively, build a container with the latest version of OpenROAD Flow Scripts.

.. code-block:: bash

    podman build -t dnltz/elements:latest --build-arg OPENROAD_FLOW_COMMIT=master .

Upload
######

.. code-block:: bash

    podman login
    podman push dnltz/elements:v2.6
