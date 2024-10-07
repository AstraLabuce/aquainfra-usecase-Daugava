import logging
import subprocess
import json
import os
import requests
from urllib.parse import urlparse
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''
curl --location 'http://localhost:5000/processes/ts-selection-interpolation/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "https://testserver.de/mean_by_group.csv",
        "colnames_relevant": "group_labels,HELCOM_ID",
        "missing_threshold_percentage": "40",
        "colname_year": "Year_adj_generated",
        "colname_value": "Secchi_m_mean_annual",
        "min_data_point": "10"
    } 
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class TsSelectionInterpolationProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.my_job_id = 'nnothing-yet'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def __repr__(self):
        return f'<TsSelectionInterpolationProcessor> {self.name}'

    def execute(self, data, outputs=None):

        # Get config
        config_file_path = os.environ.get('DAUGAVA_CONFIG_FILE', "./config.json")
        with open(config_file_path) as configFile:
            configJSON = json.load(configFile)

        download_dir = configJSON["download_dir"]
        own_url = configJSON["own_url"]
        r_script_dir = configJSON["r_script_dir"]

        # Get user inputs
        in_data_url = data.get('input_data', 'https://.../mean_by_group.csv')
        in_rel_cols = data.get('colnames_relevant', '(no-default)')
        in_missing_threshold_percentage = data.get('missing_threshold_percentage', '30')
        in_year_colname = data.get('colname_year', 'Year')
        in_value_colname = data.get('colname_value', 'value')
        in_min_data_point = data.get('min_data_point', '10')

        # Where to store output data
        downloadfilename = 'interpolated_time_series-%s.csv' % self.my_job_id # or selected_interpolated.csv ?
        downloadfilepath = download_dir.rstrip('/')+os.sep+downloadfilename

        # Run the R script:
        r_file_name = 'ts_selection_interpolation_wrapper.R'
        r_args = [in_data_url, in_rel_cols, in_missing_threshold_percentage, in_year_colname, in_value_colname, in_min_data_point, downloadfilepath]
        LOGGER.info('Run R script and store result to %s!' % downloadfilepath)
        LOGGER.debug('R args: %s' % r_args)
        returncode, stdout, stderr = call_r_script(LOGGER, r_file_name, r_script_dir, r_args)
        LOGGER.info('Running R script done: Exit code %s' % returncode)

        if not returncode == 0:
            err_msg = 'R script "%s" failed.' % r_file_name
            for line in stderr.split('\n'):
                if line.startswith('Error'):
                    err_msg = 'R script "%s" failed: %s' % (r_file_name, line)
            raise ProcessorExecuteError(user_msg = err_msg)

        else:
            # Create download link:
            downloadlink = own_url.rstrip('/')+os.sep+downloadfilename

            # Return link to file:
            response_object = {
                "outputs": {
                    "interpolated_time_series": {
                        "title": self.metadata['outputs']['interpolated_time_series']['title'],
                        "description": self.metadata['outputs']['interpolated_time_series']['description'],
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object


def call_r_script(LOGGER, r_file_name, path_rscripts, r_args):
    # TODO: Move function to some module, same in all processes

    LOGGER.debug('Now calling bash which calls R: %s' % r_file_name)
    r_file = path_rscripts.rstrip('/')+os.sep+r_file_name
    cmd = ["/usr/bin/Rscript", "--vanilla", r_file] + r_args
    LOGGER.info(cmd)
    LOGGER.debug('Running command... (Output will be shown once finished)')
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stdin=subprocess.PIPE, stderr=subprocess.PIPE)
    stdoutdata, stderrdata = p.communicate()
    LOGGER.debug("Done running command! Exit code from bash: %s" % p.returncode)

    ### Print stdout and stderr
    stdouttext = stdoutdata.decode()
    stderrtext = stderrdata.decode()
    if len(stderrdata) > 0:
        err_and_out = 'R stdout and stderr:\n___PROCESS OUTPUT {name} ___\n___stdout___\n{stdout}\n___stderr___\n{stderr}\n___END PROCESS OUTPUT {name} ___\n______________________'.format(
            name=r_file_name, stdout=stdouttext, stderr=stderrtext)
        LOGGER.error(err_and_out)
    else:
        err_and_out = 'R stdour:\n___PROCESS OUTPUT {name} ___\n___stdout___\n{stdout}\n___stderr___\n___(Nothing written to stderr)___\n___END PROCESS OUTPUT {name} ___\n______________________'.format(
            name=r_file_name, stdout=stdouttext)
        LOGGER.info(err_and_out)
    return p.returncode, stdouttext, stderrtext
