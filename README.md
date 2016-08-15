# docker-scipy-notebook
[![Docker Repository on Quay](https://quay.io/repository/refgenomics/docker-scipy-notebook/status "Docker Repository on Quay")](https://quay.io/repository/refgenomics/docker-scipy-notebook)

Base Jupyter notebook image, with a user `joyvan` (1000) in the `root` (0) group. Uses `nss_wrapper` to inject a username at runtime for use with a random uid. Based on the [scipy-notebook](https://github.com/jupyter/docker-stacks/blob/master/scipy-notebook/Dockerfile) image from the Jupyter project, and also includes the [r-notebook](https://github.com/jupyter/docker-stacks/blob/master/r-notebook/Dockerfile) installs.
