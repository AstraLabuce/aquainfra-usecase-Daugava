# Use the official R image as the base image
FROM rocker/r-ver:4.3.0

# Install system dependencies for R packages (spatial packages and others)
RUN apt-get update && apt-get install -y \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install remotes (needed to install specific versions of packages)
RUN R -e "install.packages('remotes', repos='https://cran.rstudio.com/')"

# Copy the install.R file and run it to install the R packages
COPY /install.R /src/install.R
RUN Rscript /src/install.R

# Set user-related variables
ARG NB_USER=jovyan
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV NB_UID ${NB_UID}
ENV HOME /home/${NB_USER}

# Create the user, set up home directory and permissions
RUN adduser --disabled-password --gecos "Default user" --uid ${NB_UID} ${NB_USER} \
    && mkdir -p ${HOME} \
    && chown -R ${NB_UID}:${NB_UID} ${HOME}

# Make sure the contents of our repo are in the user's home directory
COPY . ${HOME}

# Change user to ${NB_USER}
USER ${NB_USER}



# Copy the entire src directory, excluding install.R
COPY src /src

# Set the working directory to /src
WORKDIR /src

# Use sh -c to expand the environment variables and pass arguments
ENTRYPOINT ["sh", "-c", "Rscript /src/${R_SCRIPT} $@"]
