Elements Container
==================

Container with all requirements installed as environment for the Elements SDK.

Build
#####

Run following code to build the `elements:v2.1` container with podman.

.. code-block:: bash

    podman build -t dnltz/elements:v2.1 .

Upload
######

.. code-block:: bash

    podman login
    podman push dnltz/elements:v2.1
