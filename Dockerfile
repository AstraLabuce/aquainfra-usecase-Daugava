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
COPY /.binder/install.R /src/install.R
RUN Rscript /src/install.R

# Copy the entire src directory, excluding install.R
COPY src /src

# Set the working directory to /src
WORKDIR /src

# Use sh -c to expand the environment variables and pass arguments
ENTRYPOINT ["sh", "-c", "Rscript /src/${R_SCRIPT} $@"]