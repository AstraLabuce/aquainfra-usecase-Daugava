# Use Rocker Geospatial R base image with R 4.3.0
FROM rocker/geospatial:4.3.0
# Note: The previous image was mixing conda installations
# and the base R from the rocker image, leading to dependency
# problems when trying to add/update dependencies, and
# to rebuilding, due to outdated channels.
# Mixing channels is not recommended, so now everything is
# installed based on the rocker-geospatial base image.

# Include git commit hash as label (at the end):
ARG GIT_COMMIT=notset

# Install additional R packages not already included
# from dependencies.R
COPY dependencies.R ./
RUN Rscript dependencies.R

# Copy script code
COPY src /src
WORKDIR /src

# Add an entrypoint that can deal with CLI arguments that contain spaces:
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []


# Include git commit hash as label:
LABEL org.opencontainers.image.revision=$GIT_COMMIT

# Example build command:
#today=$(date '+%Y%m%d')
#docker build . -t daugava-workflow-image:${today}

# Example build command:
# This includes the git commit hash, so please
# make sure all your changes are committed/stashed:
#today=$(date '+%Y%m%d')
#githash=$(git rev-parse --short HEAD)
#docker build \
#  --build-arg GIT_COMMIT=${githash} \
#  -t daugava-workflow-image:${today}-${githash} .

