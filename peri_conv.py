import logging
import subprocess
import json
import os
import requests
from urllib.parse import urlparse
from pygeoapi.process.base import BaseProcessor, ProcessorExecuteError

'''
curl --location 'http://localhost:5000/processes/peri-conv/execution' \
--header 'Content-Type: application/json' \
--data '{ 
    "inputs": {
        "input_data": "data_out_point_att_polygon.csv",
        "column": "visit_date",
        "dates": "Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30",
        "periods": "winter,spring,summer,autumn",
        "someBoolean": "True"
    } 
}'
'''

LOGGER = logging.getLogger(__name__)

script_title_and_path = __file__
metadata_title_and_path = script_title_and_path.replace('.py', '.json')
PROCESS_METADATA = json.load(open(metadata_title_and_path))

class PeriConvProcessor(BaseProcessor):

    def __init__(self, processor_def):
        super().__init__(processor_def, PROCESS_METADATA)
        self.supports_outputs = True
        self.my_job_id = 'nnothing-yet'

    def set_job_id(self, job_id: str):
        self.my_job_id = job_id

    def execute(self, data, outputs=None):
        with open("./pygeoapi/process/config.json") as configFile:
            configJSON = json.load(configFile)

        DOWNLOAD_DIR = configJSON["DOWNLOAD_DIR"]
        OWN_URL = configJSON["OWN_URL"]
        R_SCRIPT_DIR = configJSON["R_SCRIPT_DIR"]

        input_data = data.get('input_data', 'data_out_point_att_polygon.csv')
        column = data.get('column', 'visit date')
        dates = data.get('dates', 'Dec-01:Mar-01,Mar-02:May-30,Jun-01:Aug-30,Sep-01:Nov-30')
        periods = data.get('periods', 'winter,spring,summer,autumn')
        someBoolean = data.get('someBoolean', 'True')

        # Where to store output data
        downloadfilename = 'peri_conv_%s.csv' % self.my_job_id
        downloadfilepath = DOWNLOAD_DIR.rstrip('/')+os.sep+downloadfilename

        R_SCRIPT_NAME = configJSON["step_2"]
        r_args = [DOWNLOAD_DIR.rstrip('/')+os.sep+input_data, column, dates, periods, someBoolean, downloadfilepath]

        LOGGER.error('RUN R SCRIPT AND STORE TO %s!!!' % downloadfilepath)
        LOGGER.error('R ARGS %s' % r_args)
        exit_code, err_msg = call_r_script('1', LOGGER, R_SCRIPT_NAME, R_SCRIPT_DIR, r_args)
        LOGGER.error('RUN R SCRIPT DONE: CODE %s, MSG %s' % (exit_code, err_msg))

        if not exit_code == 0:
            LOGGER.error(err_msg)
            raise ProcessorExecuteError(user_msg="R script failed with exit code %s" % exit_code)

        else:
            LOGGER.error('CODE 0 SUCCESS!')

            # Create download link:
            downloadlink = OWN_URL.rstrip('/')+os.sep+downloadfilename
            # TODO: Again, carefully consider permissions of that directory!

            # Return link to file:
            response_object = {
                "outputs": {
                    "first_result": {
                        "title": "Astras and Natalijas First Result",
                        "description": "must ask astra what this is",
                        "href": downloadlink
                    }
                }
            }

            return 'application/json', response_object

    def __repr__(self):
        return f'<PeriConvProcessor> {self.name}'


def call_r_script(num, LOGGER, r_file_name, path_rscripts, r_args):

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
        err_and_out = 'R stdout and stderr:\n___PROCESS OUTPUT {n}___\n___stdout___\n{stdout}\n___stderr___\n{stderr}   (END PROCESS OUTPUT {n})\n___________'.format(
            stdout= stdouttext, stderr=stderrtext, n=num)
        LOGGER.error(err_and_out)
    else:
        err_and_out = 'R stdour:\n___PROCESS OUTPUT {n}___\n___stdout___\n{stdout}\n___stderr___\n___(Nothing written to stderr)___\n   (END PROCESS OUTPUT {n})\n___________'.format(
            stdout = stdouttext, n = num)
        LOGGER.info(err_and_out)
    return p.returncode, err_and_out
