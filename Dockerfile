# Use Rocker R base image with R 4.3.0
FROM rocker/r-ver:4.3.0

RUN apt-get update && apt-get install -y \
    curl \
    bzip2 \
    libcurl4-openssl-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libudunits2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o miniconda.sh \
    && bash miniconda.sh -b -p /opt/conda \
    && rm miniconda.sh \
    && /opt/conda/bin/conda init \
    && ln -s /opt/conda/bin/conda /usr/local/bin/conda \
    && ln -s /opt/conda/bin/activate /usr/local/bin/activate

WORKDIR /src

COPY /.binder/environment.yml /src/environment.yml

# Throws error: Terms of Service have not been accepted for the following channels. Please accept or remove them before proceeding...
#RUN conda env create -f /src/environment.yml
# Accept Anaconda TOS (required for non-interactive builds)
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

RUN conda env create -f /src/environment.yml

COPY src /src

WORKDIR /src

ENTRYPOINT ["conda", "run", "-n", "r-environment", "/bin/bash", "-c", "Rscript /src/${R_SCRIPT} $@"]

# Example build command:
#today=$(date '+%Y%m%d')
#docker build . -t daugava-workflow-image:${today}
