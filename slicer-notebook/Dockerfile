FROM ubuntu:latest

################################################################################
# Prevent apt-get from prompting for keyboard choice
#  https://superuser.com/questions/1356914/how-to-install-xserver-xorg-in-unattended-mode
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8
################################################################################
# Remove documentation to save hard drive space
#  https://askubuntu.com/questions/129566/remove-documentation-to-save-hard-drive-space
COPY etc/dpkg/dpkg.cfg.d/01_nodoc /etc/dpkg/dpkg.cfg.d/01_nodoc

################################################################################
# - update apt, set up certs, run netselect to get fast mirror
# - reduce apt gravity
# - and disable caching
#   from https://blog.sleeplessbeastie.eu/2017/10/02/how-to-disable-the-apt-cache/
RUN echo 'APT::Install-Recommends "0" ; APT::Install-Suggests "0" ;' >> /etc/apt/apt.conf && \
    echo 'Dir::Cache::pkgcache "";\nDir::Cache::srcpkgcache "";' | tee /etc/apt/apt.conf.d/00_disable-cache-files && \
    apt-get update -q -y

################################################################################
# get packages
# - update (without update, old cached server addresses may be used and apt-get install may fail)
# - install things
#   - basic  tools
#   - slicer dependencies
#   - awesome window manager
#   - install ca-certs to prevent - fatal: unable to access 'https://github.com/novnc/websockify/': server certificate verification failed. CAfile: none CRLfile: none
RUN apt-get update -q -y && \
    apt-get install -q -y \
        vim net-tools curl \
        libgl1-mesa-glx \
        xserver-xorg-video-dummy \
        libxrender1 \
        libpulse0 \
        libpulse-mainloop-glib0  \
        libnss3  \
        libxcomposite1 \
        libxcursor1 \
        libfontconfig1 \
        libxrandr2 \
        libasound2 \
        libglu1 \
        x11vnc \
        awesome \
        jq \
        git && \
        apt-get install -q -y --reinstall ca-certificates

################################################################################
# set up user
ENV NB_USER sliceruser
ENV NB_UID 1000
ENV HOME /home/${NB_USER}

RUN adduser --disabled-password \
            --gecos "Default user" \
            --uid ${NB_UID} \
            ${NB_USER}

WORKDIR ${HOME}

################################################################################
# Download and unpack Slicer

# Current preview release (2021-10-15, rev30315)
ARG SLICER_DOWNLOAD_URL=https://download.slicer.org/bitstream/61690039342a877cb3d01245

# Latest working Slicer-4.11 version (SlicerJupyter extension is not available for the more recent Slicer-4.11.20210226 version)
#ARG SLICER_DOWNLOAD_URL=https://download.slicer.org/bitstream/60add70fae4540bf6a89bfb4

# Use local package:
ADD $SLICER_ARCHIVE knee-1.1.1-0000-00-00-linux-amd64.tar.gz ${HOME}/

# Download package:
RUN tar -zxvf knee-1.1.1-0000-00-00-linux-amd64.tar.gz -C /tmp && mv /tmp/knee-1.1.1-0000-00-00-linux-amd64* Slicer

################################################################################
# these go after installs to avoid trivial invalidation
ENV VNCPORT=49053
ENV JUPYTERPORT=8888
ENV DISPLAY=:10

COPY xorg.conf .

################################################################################
# Set up remote desktop access - step 1/2

# Build rebind.so (required by websockify)
RUN set -x && \
    sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list && \
    apt-get clean && \
    apt-get update -q -y && \
    apt-get install ttf-wqy-zenhei -q -y && \
    apt-get install -y build-essential --no-install-recommends && \
    mkdir src && \
    cd src && \
    git clone https://github.com.cnpmjs.org/novnc/websockify websockify && \
    cd websockify && \
    make && \
    cp rebind.so /usr/lib/ && \
    cd .. && \
    rm -rf websockify && \
    cd .. && \
    rmdir src && \
    apt-get purge -y --auto-remove build-essential

# Set up launcher for websockify
# (websockify must run in  Slicer's Python environment)
COPY websockify ./Slicer/bin/
RUN chmod +x ${HOME}/Slicer/bin/websockify && chmod 777 -R ${HOME}/Slicer

################################################################################
# Need to run Slicer as non-root because
# - mybinder requirement
# - chrome sandbox inside QtWebEngine does not support root.
RUN chown ${NB_USER} ${HOME} ${HOME}/Slicer
USER ${NB_USER}

RUN mkdir /tmp/runtime-sliceruser
ENV XDG_RUNTIME_DIR=/tmp/runtime-sliceruser

################################################################################
# Set up remote desktop access - step 2/2

# Install websockify
# Copy rebind.so into websockify folder so websockify can find it
# Install Jupyter desktop (configures noVNC connection adds a new "Desktop" option in New menu in Jupyter)

# First upgrade pip
RUN /home/sliceruser/Slicer/bin/PythonSlicer -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple --upgrade pip

# Now install websockify and jupyter-server-proxy (fixed at tag v1.6.0)
RUN /home/sliceruser/Slicer/bin/PythonSlicer -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple --upgrade websockify && \
    cp /usr/lib/rebind.so /home/sliceruser/Slicer/lib/Python/lib/python3.6/site-packages/websockify/ && \
    /home/sliceruser/Slicer/bin/PythonSlicer -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple notebook jupyterhub jupyterlab && \
    /home/sliceruser/Slicer/bin/PythonSlicer -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple -e \
        git+https://gitee.com/yu-guoqing/jupyter-desktop-server#egg=jupyter-desktop-server \
        git+https://github.com.cnpmjs.org/jupyterhub/jupyter-server-proxy@v1.6.0#egg=jupyter-server-proxy

################################################################################
# Install Slicer extensions

COPY start-xorg.sh .
COPY install.sh .
RUN ./install.sh ${HOME}/Slicer/knee && \
    rm ${HOME}/install.sh

################################################################################
EXPOSE $VNCPORT $JUPYTERPORT
COPY run.sh .
ENTRYPOINT ["/home/sliceruser/run.sh"]

CMD ["sh", "-c", "./Slicer/bin/PythonSlicer -m jupyter notebook --port=$JUPYTERPORT --ip=0.0.0.0 --no-browser --NotebookApp.default_url=/lab/"]

################################################################################
# Install Slicer application startup script

COPY .slicerrc.py .

################################################################################
# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG IMAGE
ARG VCS_REF
ARG VCS_URL
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=$IMAGE \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url=$VCS_URL \
      org.label-schema.schema-version="1.0"