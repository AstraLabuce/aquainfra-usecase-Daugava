import logging
import subprocess
import json
import os
import requests
from urllib.parse import urlparse
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''

Output file name: interactive_map-xyz.html

curl --location 'http://localhost:5000/processes/map-shapefile-points/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "regions": "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip",
        "colname_long": "longitude",
        "colname_lat": "latitude",
        "input_data": "https://aqua.igb-berlin.de/download/testinputs/data_merged_with_regions.csv",
        "colname_value_name": "transparency_m",
        "colname_region_id": "HELCOM_ID"
    }
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class MapShapefilePointsProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.my_job_id = 'nothing-yet'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<MapShapefilePointsProcessor> {self.name}'

    def execute(self, data, outputs=None):
        # Get config
        config_file_path = os.environ.get('DAUGAVA_CONFIG_FILE', "./config.json")
        with open(config_file_path, 'r') as configFile:
            configJSON = json.load(configFile)

        download_dir = configJSON["download_dir"]
        own_url = configJSON["own_url"]

        # Get user inputs
        in_shp_url = data.get('regions') # 'https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip')
        in_dpoints_url = data.get('input_data')
        in_long_col_name = data.get('colname_long') # 'longitude'
        in_lat_col_name = data.get('colname_lat') # 'latitude'
        in_value_name = data.get('colname_value_name') # 'transparency_m'
        in_region_col_name = data.get('colname_region_id') # 'HELCOM_ID'

        # Check
        if in_shp_url is None:
            raise ProcessorExecuteError('Missing parameter "regions". Please provide a URL to your input data.')
        if in_dpoints_url is None:
            raise ProcessorExecuteError('Missing parameter "input_data". Please provide a URL to your input data.')
        if in_long_col_name is None:
            raise ProcessorExecuteError('Missing parameter "colname_long". Please provide a column name.')
        if in_lat_col_name is None:
            raise ProcessorExecuteError('Missing parameter "colname_lat". Please provide a column name.')
        if in_value_name is None:
            raise ProcessorExecuteError('Missing parameter "colname_value_name". Please provide a column name.')
        if in_region_col_name is None:
            raise ProcessorExecuteError('Missing parameter "colname_region_id". Please provide a column name.')

        # Where to store output data
        downloadfilename = 'interactive_map-%s.html' % self.my_job_id
        #downloadfilepath = download_dir.rstrip('/')+os.sep+downloadfilename

        returncode, stdout, stderr = run_docker_container(
            in_shp_url, 
            in_dpoints_url, 
            in_long_col_name, 
            in_lat_col_name,
            in_value_name,
            in_region_col_name,
            download_dir, 
            downloadfilename
        )

        if not returncode == 0:
            err_msg = 'Running docker container failed.'
            for line in stderr.split('\n'):
                if line.startswith('Error'):
                    err_msg = 'Running docker container failed: %s' % (line)
            raise ProcessorExecuteError(user_msg = err_msg)

        else:
            # Create download link:
            downloadlink = own_url.rstrip('/')+os.sep+downloadfilename

            # Return link to file:
            response_object = {
                "outputs": {
                    "interactive_map": {
                        "title": self.metadata['outputs']['interactive_map']['title'],
                        "description": self.metadata['outputs']['interactive_map']['description'],
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object


def run_docker_container(
        in_shp_url, 
        in_dpoints_url, 
        in_long_col_name,
        in_lat_col_name,
        in_value_name,
        in_region_col_name,
        download_dir, 
        outputFilename
    ):
    LOGGER.debug('Start running docker container')
    container_name = f'daugava-workflow-image_{os.urandom(5).hex()}'
    image_name = 'daugava-workflow-image'

    # Prepare container command

    # Define paths inside the container
    container_in = '/in'
    container_out = '/out'

    # Define local paths
    local_in = os.path.join(download_dir, "in")
    local_out = os.path.join(download_dir, "out")

    # Ensure directories exist
    os.makedirs(local_in, exist_ok=True)
    os.makedirs(local_out, exist_ok=True)

    script = 'map_shapefile_points.R'

    # Mount volumes and set command
    docker_command = [
        "sudo", "docker", "run", "--rm", "--name", container_name,
        "-v", f"{local_in}:{container_in}",
        "-v", f"{local_out}:{container_out}",
        "-e", f"R_SCRIPT={script}",  # Set the R_SCRIPT environment variable
        image_name,
        "--",  # Indicates the end of Docker's internal arguments and the start of the user's arguments
        in_shp_url, 
        in_dpoints_url,  
        in_long_col_name,  
        in_lat_col_name,
        in_value_name,
        in_region_col_name,
        f"{container_out}/{outputFilename}"  # Output filename
    ]
    
    # Run container
    try:
        result = subprocess.run(docker_command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout = result.stdout.decode()
        stderr = result.stderr.decode()
        return result.returncode, stdout, stderr

    except subprocess.CalledProcessError as e:
        return e.returncode, e.stdout.decode(), e.stderr.decode()