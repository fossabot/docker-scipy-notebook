# Copyright (c) Reference Genomics, Inc.
# Distributed under the terms of the Modified BSD License.
# Extended from github.com/jupyter/docker-stacks
# See also http://blog.dscpl.com.au/2016/01/roundup-of-docker-issues-when-hosting.html

# Follow Aptible Debian releases
FROM quay.io/aptible/debian:jessie

MAINTAINER Nick Greenfield <nick@onecodex.com>

USER root

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -yq --no-install-recommends \
    wget \
    bzip2 \
    ca-certificates \
    sudo \
    locales \
    git \
    vim \
    jed \
    emacs \
    build-essential \
    python-dev \
    unzip \
    libsm6 \
    pandoc \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-fonts-extra \
    texlive-fonts-recommended \
    texlive-generic-recommended \
    libxrender1 \
    inkscape \
    libav-tools \
    fonts-dejavu \
    gfortran \
    gcc \
    cmake \
    curl \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Install Tini
RUN wget --quiet https://github.com/krallin/tini/releases/download/v0.9.0/tini && \
    echo "faafbfb5b079303691a939a747d7f60591f2143164093727e870b289a44d9872 *tini" | sha256sum -c - && \
    mv tini /usr/local/bin/tini && \
    chmod +x /usr/local/bin/tini

# Configure environment
ENV CONDA_DIR /opt/conda
ENV PATH $CONDA_DIR/bin:$PATH
ENV SHELL /bin/bash
ENV NB_USER jovyan
ENV NB_UID 1000
ENV HOME /home/$NB_USER
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

# Create jovyan user with UID=1000 and in the root group
# See https://github.com/jupyter/docker-stacks/issues/188
RUN useradd -m -s /bin/bash -N -u $NB_UID -g 0 $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:root $CONDA_DIR

USER $NB_USER

# Setup jovyan home directory
RUN mkdir /home/$NB_USER/work && \
    mkdir /home/$NB_USER/.jupyter && \
    mkdir -p -m 770 /home/$NB_USER/.local/share/jupyter && \
    echo "cacert=/etc/ssl/certs/ca-certificates.crt" > /home/$NB_USER/.curlrc

# Install conda as jovyan
# Also ensure /opt/conda is writeable by group (so installs are possible there)
# We do this here so we don't get an additional layer in the image later
RUN cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-4.1.11-Linux-x86_64.sh && \
    echo "efd6a9362fc6b4085f599a881d20e57de628da8c1a898c08ec82874f3bad41bf *Miniconda3-4.1.11-Linux-x86_64.sh" | sha256sum -c - && \
    /bin/bash Miniconda3-4.1.11-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-4.1.11-Linux-x86_64.sh && \
    $CONDA_DIR/bin/conda install --quiet --yes conda==4.1.11 && \
    $CONDA_DIR/bin/conda config --system --add channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    conda clean -tipsy && \
    chmod -R g+w $CONDA_DIR

# Temporary workaround for https://github.com/jupyter/docker-stacks/issues/210
# Stick with jpeg 8 to avoid problems with R packages
RUN echo "jpeg 8*" >> /opt/conda/conda-meta/pinned

# Install Jupyter notebook as jovyan
RUN conda install --quiet --yes \
    'notebook=4.3*' \
    && conda clean -tipsy && \
    chmod -R g+w $CONDA_DIR

# Install Python 3 packages
# Remove pyqt and qt pulled in for matplotlib since we're only ever going to
# use notebook-friendly backends in these images
RUN conda install --quiet --yes \
    'ipywidgets=5.1*' \
    'pandas=0.18*' \
    'numexpr=2.5*' \
    'matplotlib=1.5*' \
    'scipy=0.17*' \
    'seaborn=0.7*' \
    'scikit-learn=0.17*' \
    'scikit-image=0.11*' \
    'sympy=1.0*' \
    'cython=0.23*' \
    'patsy=0.4*' \
    'statsmodels=0.6*' \
    'cloudpickle=0.1*' \
    'dill=0.2*' \
    'numba=0.23*' \
    'bokeh=0.11*' \
    'sqlalchemy=1.0*' \
    'hdf5=1.8.17' \
    'h5py=2.6*' && \
    conda remove --quiet --yes --force qt pyqt && \
    conda clean -tipsy && \
    chmod -R g+w $CONDA_DIR

# Activate ipywidgets extension in the environment that runs the notebook server
RUN jupyter nbextension enable --py widgetsnbextension --sys-prefix

# Install Python 2 packages
# Remove pyqt and qt pulled in for matplotlib since we're only ever going to
# use notebook-friendly backends in these images
RUN conda create --quiet --yes -p $CONDA_DIR/envs/python2 python=2.7 \
    'ipython=4.2*' \
    'ipywidgets=5.1*' \
    'pandas=0.18*' \
    'numexpr=2.5*' \
    'matplotlib=1.5*' \
    'scipy=0.17*' \
    'seaborn=0.7*' \
    'scikit-learn=0.17*' \
    'scikit-image=0.11*' \
    'sympy=1.0*' \
    'cython=0.23*' \
    'patsy=0.4*' \
    'statsmodels=0.6*' \
    'cloudpickle=0.1*' \
    'dill=0.2*' \
    'numba=0.23*' \
    'bokeh=0.11*' \
    'hdf5=1.8.17' \
    'h5py=2.6*' \
    'sqlalchemy=1.0*' \
    'pyzmq' && \
    conda remove -n python2 --quiet --yes --force qt pyqt && \
    conda clean -tipsy && \
    chmod -R g+w $CONDA_DIR

# # Add shortcuts to distinguish pip for python2 and python3 envs
RUN ln -s $CONDA_DIR/envs/python2/bin/pip $CONDA_DIR/bin/pip2 && \
    ln -s $CONDA_DIR/bin/pip $CONDA_DIR/bin/pip3

# # Configure ipython kernel to use matplotlib inline backend by default
RUN mkdir -p $HOME/.ipython/profile_default/startup
COPY mplimporthook.py $HOME/.ipython/profile_default/startup/

# R install
RUN conda config --add channels r && \
    conda install --quiet --yes \
    'r-base=3.3*' \
    'r-irkernel=0.6*' \
    'r-plyr=1.8*' \
    'r-devtools=1.11*' \
    'r-dplyr=0.4*' \
    'r-ggplot2=2.1*' \
    'r-tidyr=0.5*' \
    'r-shiny=0.13*' \
    'r-rmarkdown=0.9*' \
    'r-forecast=7.1*' \
    'r-stringr=1.0*' \
    'r-rsqlite=1.0*' \
    'r-reshape2=1.4*' \
    'r-nycflights13=0.2*' \
    'r-caret=6.0*' \
    'r-rcurl=1.95*' \
    'r-randomforest=4.6*' && conda clean -tipsy && \
    chmod -R g+w $CONDA_DIR

# Install Python 2 kernel spec globally to avoid permission problems when NB_UID
# switching at runtime.
USER root
RUN $CONDA_DIR/envs/python2/bin/python -m ipykernel install

# Set workdir
WORKDIR /home/$NB_USER/work

# Install nss_wrapper
RUN wget https://ftp.samba.org/pub/cwrap/nss_wrapper-1.1.2.tar.gz && \
    mkdir nss_wrapper && \
    tar -xC nss_wrapper --strip-components=1 -f nss_wrapper-1.1.2.tar.gz && \
    rm nss_wrapper-1.1.2.tar.gz && \
    mkdir nss_wrapper/obj && \
    (cd nss_wrapper/obj && \
        cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DLIB_SUFFIX=64 .. && \
        make && \
        make install) && \
    rm -rf nss_wrapper

# Configure container startup
EXPOSE 8888
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["jupyter", "notebook"]

# Add local files
COPY jupyter_notebook_config.py /home/$NB_USER/.jupyter/
COPY token_notebook.py /usr/local/bin/token_notebook.py
RUN chmod +x /usr/local/bin/token_notebook.py

# Finally fix permissions on everything
# Create jovyan user with UID=1000 and in the root group
# See https://github.com/jupyter/docker-stacks/issues/188
RUN chmod -R u+w,g+w /home/$NB_USER

# Switch back to jovyan to avoid accidental container runs as root
USER 1000
