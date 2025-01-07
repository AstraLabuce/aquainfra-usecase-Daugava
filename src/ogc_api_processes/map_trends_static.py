import logging
import subprocess
import json
import os
import requests
from urllib.parse import urlparse
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''
Output file name: map_trends_static-xyz.png

curl --location 'http://localhost:5000/processes/map-trends-static/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "regions": "https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip",
        "input_data": "https://aqua.igb-berlin.de/download/testinputs/trend_analysis_results.csv",
        "colname_id_trend": "polygon_id",
        "colname_region_id": "HELCOM_ID",
        "colname_group": "period",
        "colname_p_value": "P_Value",
        "p_value_threshold": "0.05"
    } 
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class MapTrendsStaticProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.my_job_id = 'nothing-yet'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def execute(self, data, outputs=None):
        # Get config
        config_file_path = os.environ.get('DAUGAVA_CONFIG_FILE', "./config.json")
        with open(config_file_path, 'r') as configFile:
            configJSON = json.load(configFile)

        download_dir = configJSON["download_dir"]
        own_url = configJSON["own_url"]

        # User inputs
        in_shp_url = data.get('regions') # 'https://maps.helcom.fi/arcgis/rest/directories/arcgisoutput/MADS/tools_GPServer/_ags_HELCOM_subbasin_with_coastal_WFD_waterbodies_or_wa.zip')
        in_trend_results_url = data.get('input_data')
        in_id_trend_col = data.get('colname_id_trend') # default was: polygon_id, id
        in_id_shp_col = data.get('colname_region_id') # default was: HELCOM_ID, id
        in_group = data.get('colname_group') # default was: season, group
        in_p_value_threshold = data.get('p_value_threshold') # 0.05
        in_p_value_col = data.get('colname_p_value') # p_Value

        # Check user inputs
        if in_shp_url is None:
            raise ProcessorExecuteError('Missing parameter "regions". Please provide a URL to your input data.')
        if in_trend_results_url is None:
            raise ProcessorExecuteError('Missing parameter "input_data". Please provide a column name.')
        if in_id_trend_col is None:
            raise ProcessorExecuteError('Missing parameter "colname_id_trend". Please provide a column name.')
        if in_id_shp_col is None:
            raise ProcessorExecuteError('Missing parameter "colname_region_id". Please provide a column name.')
        if in_group is None:
            raise ProcessorExecuteError('Missing parameter "colname_group". Please provide a column name.')
        if in_p_value_threshold is None:
            raise ProcessorExecuteError('Missing parameter "p_value_threshold". Please provide a value.')
        if in_p_value_col is None:
            raise ProcessorExecuteError('Missing parameter "colname_p_value". Please provide a column name.')

        # Where to store output data
        downloadfilename = 'map_trends_static-%s.png' % self.my_job_id
        #downloadfilepath = download_dir.rstrip('/')+os.sep+downloadfilename

        returncode, stdout, stderr = run_docker_container(
            in_shp_url, 
            in_trend_results_url, 
            in_id_trend_col, 
            in_id_shp_col,
            in_group,
            in_p_value_threshold,
            in_p_value_col,
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
            downloadlink = own_url.rstrip('/')+os.sep+"out"+os.sep+downloadfilename

            # Return link to file:
            response_object = {
                "outputs": {
                    "trend_map": {
                        "title": self.metadata['outputs']['trend_map']['title'],
                        "description": self.metadata['outputs']['trend_map']['description'],
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object

    def __repr__(self):
        return f'<MapTrendsStaticProcessor> {self.name}'


def run_docker_container(
        in_shp_url, 
        in_trend_results_url, 
        in_id_trend_col, 
        in_id_shp_col,
        in_group,
        in_p_value_threshold,
        in_p_value_col,
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

    script = 'map_trends_static.R'

    # Mount volumes and set command
    docker_command = [
        "sudo", "docker", "run", "--rm", "--name", container_name,
        "-v", f"{local_in}:{container_in}",
        "-v", f"{local_out}:{container_out}",
        "-e", f"R_SCRIPT={script}",  # Set the R_SCRIPT environment variable
        image_name,
        "--",  # Indicates the end of Docker's internal arguments and the start of the user's arguments
        in_shp_url, 
        in_trend_results_url, 
        in_id_trend_col, 
        in_id_shp_col,
        in_group,
        in_p_value_col,
        in_p_value_threshold,
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